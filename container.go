// container.go
// Defines each host as a container with a set of Ansible roles
// with a RUN layer for each role. A configuration is loaded by a
// config.yml file and contains the relevant Docker volumes, ports,
// environment variables, and entrypoint. Resource requirements are
// also part of the confiuration and is used by Kubernetes.
//
// Copyright 2018 SAS Institute Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

package main

import (
	"archive/tar"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/client"
	"gopkg.in/yaml.v2"
)

// State of the Container
type State int

// Note: this omits 0 and 1 to prevent evaluation to True or False
const (
	Unknown    State = 2  // Default unset status, no configurations have been loaded
	DoNotBuild State = 3  // Special type, assigned by omission in the --build-only argument
	Failed     State = 4  // Dockerfile or pre-requisite step has returned an error
	Loading    State = 5  // The configuration is being loaded, Docker context and Dockerfile are being created
	Loaded     State = 6  // All pre-requisite build steps have been completed
	Building   State = 7  // Dockerfile is being built by the Docker client using the context payload
	Built      State = 8  // Docker client has built and tagged the last layer
	Pushing    State = 9  // Image is in the process of being pushed to the provided registry
	Pushed     State = 10 // Image has finished pushing to the provided registry
)

// DockerAPIVersion is the minimum version of the API we support
const DockerAPIVersion = "1.37"

// Container defines the attributes for a single host
type Container struct {
	// Reference to the parent SOE
	SoftwareOrder *SoftwareOrder

	// Basic default attributes set on creation
	Status    State  // See `type State` above
	Name      string // Hostname without a project name prefix - such as httpproxy, sas-casserver-primary, consul
	Tag       string // Use container.GetTag or container.GetWholeImageName instead
	BaseImage string // Set by the order's --base-image argument
	IsStatic  bool   // Set by the CreateDockerContext function. Determined by the existence of the util/static-roles-<deployment>/<container-name> directory

	// Builder attributes
	BuildArgs         map[string]*string // Arguments that are passed into the Docker builder https://docs.docker.com/engine/reference/commandline/build/
	BuildPath         string             // Path to the inner container build directory: builds/<deployment-type>-<date>-<time>/<project_name>-<container_name>/
	ContextWriter     *tar.Writer        // Writes to a tar file that's passed to the Docker daemon as the build context
	Dockerfile        string             // Generated from the container's included roles
	DockerContext     *os.File           // Payload sent to the Docker builder, includes all files and the Dockerfile for the build
	DockerContextPath string             // Location of the tar file, which is passed to the Docker client
	DockerClient      *client.Client     // Individual connection to the Docker daemon, which allows for concurrency
	Log               *os.File           // Open file buffer that's written to
	LogPath           string             // Path to the log file so the buffer will know where to write
	Config            ContainerConfig    // Set by the config.yml and loaded by the order

	// Used for metrics, though this does not account for layer cache
	BuildStart time.Time // Set when the build command is sent to the Docker client
	BuildEnd   time.Time // Set when the build command receives a success signal from the Docker client
	PushStart  time.Time // Set when the push command is sent to the Docker client
	PushEnd    time.Time // Set when the push command receives a success signal from the Docker client
	ImageSize  int64     // Set after the build process by the Docker client ImageList command
}

// ContainerConfig each container has a configmap which define Docker layers.
// A static configmap.yml file is parsed and all containers
// that do not have static values are set to the defaults
// (see container.GetConfig).
type ContainerConfig struct {
	// Standard Dockerfile layer attributes
	User        string   `yaml:"user"` // The runuser for the entrypoint. By default a container will run as the sas user
	Ports       []string `yaml:"ports"`
	Environment []string `yaml:"environment"`
	Secrets     []string `yaml:"secrets"`
	Roles       []string `yaml:"roles"`
	Volumes     []string `yaml:"volumes"`

	// Used in the Kubernetes manifest generation
	Resources struct {
		Limits   []string `yaml:"limits"`
		Requests []string `yaml:"requests"`
	} `yaml:"resources"`
}

// effectedImage holdes the docker file that will need to be applied to the container
type effectedImage struct {
	Dockerfiles []string
}

// Provide a human readable output of a container's configurations
func (config *ContainerConfig) String() string {
	return fmt.Sprintf("\n\n[CONFIGURATION]\n[User] %s\n[Ports] %s\n[Environment] %s\n[Roles] %s\n[Volumes] %s\n[Resources Limits] %s\n[Resources Requests] %s\n\n",
		config.User+", ",
		strings.Join(config.Ports, ", "),
		strings.Join(config.Environment, ", "),
		strings.Join(config.Roles, ", "),
		strings.Join(config.Volumes, ", "),
		strings.Join(config.Resources.Limits, ", "),
		strings.Join(config.Resources.Requests, ", "),
	)
}

// DockerResponse is used by the docker image build process to decode the string channel
type DockerResponse struct {
	Stream string      `json:"stream"`      // Shows up in an Image Build response
	Status string      `json:"status"`      // Shows up in an Image Push response
	Error  interface{} `json:"errorDetail"` // Only shows if there's an error image build response
}

// WriteLog writes any number of object info to the container's log file
func (container *Container) WriteLog(contentBlocks ...interface{}) {
	// Write the filename and line number
	_, fullFilePath, fileCallerLineNumber, _ := runtime.Caller(1)
	filePathSections := strings.Split(fullFilePath, "/")
	fileCallerName := filePathSections[len(filePathSections)-1]
	container.Log.Write([]byte(fmt.Sprintf("[%s:%d] ",
		fileCallerName, fileCallerLineNumber)))

	// Write each interface
	for _, block := range contentBlocks {
		container.Log.Write([]byte(fmt.Sprintf("%v\n", block)))
	}

	container.Log.Write([]byte("\n"))
}

// GetName gets the <project_name>-<name>
func (container *Container) GetName() string {
	return container.SoftwareOrder.ProjectName + "-" + strings.ToLower(container.Name)
}

// GetTag gets the <recipe_version>-<date>-<time> format
func (container *Container) GetTag() string {
	// Use the "--tag" argument if provided
	if len(container.SoftwareOrder.TagOverride) > 0 {
		return container.SoftwareOrder.TagOverride
	}

	return fmt.Sprintf("%s-%s",
		strings.TrimSpace(RecipeVersion),
		container.SoftwareOrder.TimestampTag)
}

// GetWholeImageName gets a <registry>/<namespace>/<project_name>-<container_name>
// format if it has a Docker namespace and Docker registry.
// Otherwise return the <container_name>:<tag> format.
func (container *Container) GetWholeImageName() string {
	if len(container.SoftwareOrder.DockerNamespace) == 0 ||
		len(container.SoftwareOrder.DockerRegistry) == 0 {
		return container.GetName() + ":" + container.GetTag()
	}
	return container.SoftwareOrder.DockerRegistry +
		"/" + container.SoftwareOrder.DockerNamespace +
		"/" + container.GetName() + ":" + container.GetTag()
}

// GetConfig loads the configmap of all static container attributes
func (container *Container) GetConfig() error {
	result := make(map[string]ContainerConfig)

	// Read the file and parse the results
	file, err := ioutil.ReadFile(container.SoftwareOrder.ConfigPath)
	if err != nil {
		return errors.New("Unable to read file config.yml, " + err.Error())
	}
	err = yaml.Unmarshal([]byte(file), &result)
	if err != nil {
		return errors.New("Unable to unmarshal file config.yml, " + err.Error())
	}

	// If an empty license secret is specified then load the license into the string
	targetConfig := result[container.Name]
	for index, secret := range targetConfig.Secrets {
		// Add the base64 encoded license
		if strings.Contains(strings.ToLower(secret), "setinit_text_enc=") {
			encodedLicense := string(base64.StdEncoding.EncodeToString(
				container.SoftwareOrder.License))
			targetConfig.Secrets[index] = "SETINIT_TEXT_ENC=" + encodedLicense
		}
		// Add the decoded license
		if strings.Contains(strings.ToLower(secret), "setinit_text=") {
			targetConfig.Secrets[index] = "SETINIT_TEXT=" + string(container.SoftwareOrder.License)
		}
	}

	for index, environment := range targetConfig.Environment {
		// Add the base64 encoded license
		if strings.Contains(strings.ToLower(environment), "sas_license=") {
			targetConfig.Environment[index] = "SAS_LICENSE=" + string(container.SoftwareOrder.MeteredLicense)
		}
		if strings.Contains(strings.ToLower(environment), "sas_client_cert=") {
			encodedEntitlement := string(base64.StdEncoding.EncodeToString(
				container.SoftwareOrder.Entitlement))
			targetConfig.Environment[index] = "SAS_CLIENT_CERT=" + encodedEntitlement
		}
		if strings.Contains(strings.ToLower(environment), "sas_ca_cert=") {
			encodedCA := string(base64.StdEncoding.EncodeToString(
				container.SoftwareOrder.CA))
			targetConfig.Environment[index] = "SAS_CA_CERT=" + encodedCA
		}
		if strings.Contains(strings.ToLower(environment), "consul_key_value_data_enc=") {
			encodedSitedefault := string(base64.StdEncoding.EncodeToString(container.SoftwareOrder.SiteDefault))
			targetConfig.Environment[index] = "CONSUL_KEY_VALUE_DATA_ENC=" + encodedSitedefault
		}
	}

	// --- ADD DEFAULT VALUES  ---
	// The "config-<deploy-type>.yml" files in the root of this project lets you define
	// custom values. If a container does not have an entry in the config yaml then
	// some defaults are added in this section.

	// Default volumes
	targetConfig.Volumes = append(targetConfig.Volumes, "log=/opt/sas/viya/config/var/log")

	// Default roles: only applicable in the full deployment
	if len(targetConfig.Roles) == 0 {
		// If the container has no custom configuration then it's a dynamically created container.
		container.IsStatic = false
		targetConfig.Roles = []string{
			"ansible", "tini", "sas-prerequisites", "sas-install-base-packages", "sas-java",
		}
		targetConfig.Roles = append(targetConfig.Roles, container.Name)
		targetConfig.Roles = append(targetConfig.Roles, "cloud-config")
		container.WriteLog("Added default roles")
	}

	// Default resource limits
	if len(targetConfig.Resources.Limits) == 0 {
		targetConfig.Resources.Limits = append(targetConfig.Resources.Limits, "memory=10Gi")
	}

	// Default resource requests
	if len(targetConfig.Resources.Requests) == 0 {
		targetConfig.Resources.Requests = append(targetConfig.Resources.Requests, "memory=2Gi")
	}

	// Default runuser
	// If no "user" attribute is specified in the config file then the
	// container will run as the sas user by default.
	if len(targetConfig.User) == 0 {
		targetConfig.User = "sas"
	}

	container.Config = targetConfig
	container.WriteLog("Container config:", container.Config)
	return nil
}

// File is used by the Container struct to create a filesystem tree
type File struct {
	Name    string
	Content []byte
}

// Prebuild performs all pre-build steps after the playbook has been parsed
func (container *Container) Prebuild(progress chan string) error {
	// Open an individual Docker client connection
	dockerConnection, err := client.NewClientWithOpts(client.WithVersion(DockerAPIVersion))
	if err != nil {
		debugMessage := "Unable to connect to Docker daemon. Ensure Docker is installed and the service is started. "
		return errors.New(debugMessage + err.Error())
	}
	container.DockerClient = dockerConnection

	// After all the files have been collected then tar them up to create a Docker context payload.
	// The build context must be a tar file since this isolates the build process.
	err = container.CreateDockerContext()
	if err != nil {
		return err
	}

	container.Status = Loaded
	return nil
}

// GetBuildArgs loads the Software Order's details to create build arguments
// Note: The Docker api requires BuildArgs to be a string pointer instead of just a string
func (container *Container) GetBuildArgs() {
	buildArgs := make(map[string]*string)
	buildArgs["BASE"] = &container.SoftwareOrder.BaseImage
	buildArgs["PLATFORM"] = &container.SoftwareOrder.Platform
	buildArgs["PLAYBOOK_SRV"] = &container.SoftwareOrder.CertBaseURL
	buildArgs["SAS_RPM_REPO_URL"] = &container.SoftwareOrder.MirrorURL

	container.WriteLog(container.BuildArgs)
	container.BuildArgs = buildArgs
}

// Build interfaces with the Docker client to run an image build
func (container *Container) Build(progress chan string) error {
	// Open the context payload created in pre-build so it can be passed to the Docker client
	dockerBuildContext, err := os.Open(container.DockerContextPath)
	if err != nil {
		return err
	}

	// Set the payload to send to the Docker client
	container.GetBuildArgs()
	extraHosts := make([]string, 0)
	extraHosts = append(extraHosts, "sas-container-recipes-builder:"+container.SoftwareOrder.BuilderIP)
	buildOptions := types.ImageBuildOptions{
		Context:     dockerBuildContext,
		Tags:        []string{container.GetWholeImageName()},
		Dockerfile:  "Dockerfile",
		BuildArgs:   container.BuildArgs,
		Remove:      true,
		ForceRemove: true,
		ExtraHosts:  extraHosts,
	}

	// Build the image and get the response
	container.WriteLog("----- Starting Docker Build -----")
	progress <- "Starting Docker build: " + container.GetWholeImageName() + " ... "
	buildResponseStream, err := container.DockerClient.ImageBuild(
		container.SoftwareOrder.BuildContext,
		dockerBuildContext,
		buildOptions)
	if err != nil {
		return err
	}
	return readDockerStream(buildResponseStream.Body,
		container, container.SoftwareOrder.Verbose, progress)
}

// Push the image to the docker registry that's defined in the software order's attributes
func (container *Container) Push(progress chan string) error {
	if container.Status != Built {
		return nil
	}

	// A Docker namespace and registry url is optional in the single container deployment type
	if container.SoftwareOrder.DeploymentType == "single" &&
		(len(container.SoftwareOrder.DockerNamespace) == 0 ||
			len(container.SoftwareOrder.DockerRegistry) == 0) {
		return nil
	}

	container.Status = Pushing
	container.WriteLog("----- Starting Docker Push -----")
	progress <- "Pushing to Docker registry: " + container.GetWholeImageName() + " ... "
	pushResponseStream, err := container.DockerClient.ImagePush(container.SoftwareOrder.BuildContext,
		container.GetWholeImageName(), types.ImagePushOptions{RegistryAuth: container.SoftwareOrder.RegistryAuth})
	if err != nil {
		return err
	}
	return readDockerStream(pushResponseStream, container,
		container.SoftwareOrder.Verbose, progress)
}

// readDockerStream is a helper function for container.Build and container.Push
// Read the response stream from a Docker client API call
func readDockerStream(responseStream io.ReadCloser,
	container *Container, verbose bool, progress chan string) error {

	// Stream the response into a json decoder and return it to the progress channel
	defer responseStream.Close()
	d := json.NewDecoder(responseStream)
	var response *DockerResponse
	responses := []DockerResponse{}
	for {
		if err := d.Decode(&response); err != nil {
			if err == io.EOF {
				break
			}
		}

		// The raw response is noisy with lots of spaces, so trim the spacing
		// and print it to standard output
		response.Stream = strings.TrimSpace(string(response.Stream))
		responses = append(responses, *response)
		container.WriteLog(response)
		if verbose && len(response.Stream) > 0 {
			if progress != nil {
				progress <- container.Name + ":\n" + response.Stream
			} else {
				// Work-around to allow single container to build without a progress stream
				log.Println(response.Stream)
			}
		}
		if response.Error != nil {
			// If anything goes wrong then dump the error and provide debugging options
			errSummary := fmt.Sprintf("[ERROR] %s: %v \n\nDebugging: %s\n",
				container.Name, response.Error, container.LogPath)
			return errors.New(errSummary)
		}
	}
	return nil
}

const dockerfileFromBase = `# Generated Dockerfile for %s
FROM %s
ARG PLATFORM
ARG PLAYBOOK_SRV
ENV PLATFORM=$PLATFORM ANSIBLE_CONFIG=/ansible/ansible.cfg ANSIBLE_CONTAINER=true
RUN mkdir --parents /opt/sas/viya/home/{lib/envesntl,bin}
RUN if [ "$PLATFORM" = "redhat" ]; then \
        yum install --assumeyes ansible; \
		rm -rf /root/.cache /var/cache/yum; \
		echo -e "minrate=1" >> /etc/yum.conf; \
		echo -e "timeout=300" >> /etc/yum.conf; \
    elif [ "$PLATFORM" = "suse" ]; then \
        zypper install --no-confirm ansible curl && rm -rf /var/cache/zypp; \
	else \
		echo -e "Platform $PLATFORM not supported"; \
		exit 1; \
    fi
ADD *.yml *.cfg /ansible/
ADD roles /ansible/roles
`

const dockerfileSetupEntrypoint = `# Start a top level process that starts all services as a non-root user
USER %s:%s
ENTRYPOINT ["/usr/bin/tini", "--", "/opt/sas/viya/home/bin/%s-entrypoint.sh"]
`

// Each Ansible role is a RUN layer
const dockerfileRunLayer = `# %s role
RUN ansible-playbook -vv /ansible/playbook.yml --extra-vars layer=%s --extra-vars PLAYBOOK_SRV=${PLAYBOOK_SRV} --extra-vars container_name=%s
`

const dockerfileAddDynamicRole = `# Add the %s specific role
ADD dynamicRoles /ansible/dynamicRoles
`

// Add Docker labels to help with finding images
const dockerfileLabels = `# Define labels
LABEL sas.recipe="true" \
      sas.recipe.version="%s" \
      sas.recipe.image="%s" \
      sas.layer.%s="true"
`

// CreateDockerfile creates a Dockerfile by reading the container's configuration
func (container *Container) CreateDockerfile() (string, error) {
	// Grab the config and start formatting the Dockerfile
	dockerfile := fmt.Sprintf(dockerfileFromBase, container.SoftwareOrder.ProjectName+"-"+container.Name, container.BaseImage) + "\n"

	// For each role add to the result. Also add the container.Name role (self).
	dockerfile += "\n# Generated image includes the following Ansible roles, with the "
	for _, role := range container.Config.Roles {
		if strings.EqualFold(container.Name, role) {
			dockerfile += fmt.Sprintf(dockerfileAddDynamicRole, role) + "\n"
		}
		dockerfile += fmt.Sprintf(dockerfileRunLayer, role, role, container.Name) + "\n"
	}

	// Add the provided volumes
	if len(container.Config.Volumes) > 0 {
		dockerfile += "# Volume mount points\n"
		mountPoints := []string{}
		for _, volume := range container.Config.Volumes {
			// The config file has the format "name=/some/volume/path",
			// where the section before the equal sign is only used by the
			// manifest generation playbook. The section after the equal sign
			// is used in the Dockerfile. For example, "data=/cas/data" has
			// the name "data" and the mount path "/cas/data".
			sections := strings.Split(volume, "=")
			if !strings.Contains(volume, "=") && len(sections) != 2 {
				errorOutput := fmt.Sprintf("Could not parse NAME=VALUE format from volume. %s, %s",
					container.Name, volume)
				return dockerfile, errors.New(errorOutput)
			}
			mountPoints = append(mountPoints, sections[1])
		}
		dockerfile += "VOLUME " + strings.Join(mountPoints, " ")
	}

	// Expose the ports that were specified in the config
	if len(container.Config.Ports) > 0 {
		dockerfile += "\n# Ports\n"
	}
	for _, volume := range container.Config.Ports {
		dockerfile += fmt.Sprintf("EXPOSE %s\n", volume)
	}

	// Handle AddOns Dockerfile lines
	dockerfile, err := appendAddonLines(container.Name, dockerfile, container.SoftwareOrder.DeploymentType, container.SoftwareOrder.AddOns)
	if err != nil {
		return dockerfile, err
	}

	dockerfile += "\n" + fmt.Sprintf(dockerfileSetupEntrypoint, container.Config.User, container.Config.User, container.Name)
	dockerfile += "\n" + fmt.Sprintf(dockerfileLabels, RecipeVersion, container.Name, container.Name)
	return dockerfile, nil
}

// readAddonConf reads the yaml file and return the data.
func readAddonConf(fileName string) (map[string]effectedImage, error) {

	imageData := make(map[string]effectedImage)

	yamlFile, err := ioutil.ReadFile(fileName)
	if err != nil {
		return imageData, err
	}
	err = yaml.Unmarshal(yamlFile, &imageData)
	if err != nil {
		return imageData, err
	}

	return imageData, nil
}

// appendAddonLines adds any corresponding addon lines to a Dockerfile
// Helper function utilized by all the deployment types
func appendAddonLines(name string, dockerfile string, deploymentType string, addons []string) (string, error) {

	// This function now reads an addon_config.yml file in the addon directory to determine
	// which containers are affected by the Dockerfiles.
	if len(addons) > 0 {

		// If we add an addon to a container then set to True and we add sas.recipe.addons=true to the image
		labelRecipeAddons := false
		for _, addon := range addons {
			images, err := readAddonConf(addon + "addon_config.yml")
			if err != nil {
				return "", err
			}

			// If we don't find the image name listed we skip.
			targetImage, targetFound := images[name]
			if !targetFound {
				continue
			}

			labelRecipeAddons = true

			// Read the addon's Dockerfile and only grab the RUN, ADD, COPY, USER, lines
			dockerfile += "\n# AddOn(s)"
			dockerfile += "\n# " + addon + "\n"

			// addonPath is a split out of the addon var, which includes the path to the addons.
			addonName := filepath.Base(addon)

			dockerfile += "LABEL sas.recipe.addons." + addonName + "=\"true\"\n"

			// This will need to loop through list.
			for _, addonDockerfile := range targetImage.Dockerfiles {
				bytes, _ := ioutil.ReadFile(addon + addonDockerfile)
				lines := strings.Split(string(bytes), "\n")
				endsWithSlashRe := regexp.MustCompile("\\\\s*")
				for index, line := range lines {
					line = strings.TrimSpace(line)
					if len(line) == 0 {
						continue
					}

					if strings.HasPrefix(line, "RUN ") ||
						strings.HasPrefix(line, "ADD ") ||
						strings.HasPrefix(line, "ARG") ||
						strings.HasPrefix(line, "WORKDIR") ||
						strings.HasPrefix(line, "USER") ||
						strings.HasPrefix(line, "COPY ") {

						if strings.Compare(addonName, "ide-jupyter-python3") == 0 && strings.Compare(deploymentType, "single") != 0 && strings.Contains(line, "BASEIMAGE") {
							dockerfile += "ARG BASEIMAGE=non-single-container\n"
						} else if strings.Compare(addonName, "ide-jupyter-python3") == 0 && strings.Compare(deploymentType, "single") == 0 && strings.Contains(line, "BASEIMAGE") {
							dockerfile += line + "\n"
						} else {
							dockerfile += line + "\n"
						}

						// If there's a "\" then it's a multi-line command
						if strings.Contains(line, "\\") {
							for _, nextLine := range lines[index+1:] {
								dockerfile += nextLine + "\n"
								if !endsWithSlashRe.MatchString(nextLine) {
									break
								}
							}
						}
					}
				}
			}
		}
		if labelRecipeAddons == true {
			dockerfile += "LABEL sas.recipe.addons=\"true\""
		}
	}

	return dockerfile, nil
}

// CreateBuildDirectory creates a sub-directory within the builds directory, set the log path, and the Docker context path
func (container *Container) CreateBuildDirectory() error {
	// Create the tar file on the build machine
	container.BuildPath = container.SoftwareOrder.BuildPath + container.GetName()
	err := os.MkdirAll(container.BuildPath, 0744)
	if err != nil {
		return err
	}

	// Setup logging
	container.LogPath = container.BuildPath + "/log.txt"
	logFile, err := os.Create(container.LogPath)
	if err != nil {
		return err
	}
	container.Log = logFile

	// Setup the docker context writer
	buildContextTarName := "build_context.tar"
	container.DockerContextPath = container.BuildPath + "/" + buildContextTarName
	finalTarFile, err := os.Create(container.DockerContextPath)
	if err != nil {
		return err
	}
	container.ContextWriter = tar.NewWriter(finalTarFile)
	container.DockerContext = finalTarFile
	return nil
}

// CreateDockerContext goes through each item in the container's docker context and write the file's content to the tar file.
// Follow the Container directory structure (files/*, tasks/*, templates/*, vars/*)
func (container *Container) CreateDockerContext() error {
	err := container.CreateBuildDirectory()
	if err != nil {
		return err
	}

	// Load the config.yml
	err = container.GetConfig()
	if err != nil {
		return err
	}

	// Create the self playbook in the root directory
	err = container.AddFileToContext("util/playbook.yml", "playbook.yml", []byte{})
	if err != nil {
		return err
	}

	// Add the vars files from the playbook and place them in the root
	container.AddFileToContext(container.SoftwareOrder.PlaybookPath+"/vars.yml", "vars.yml", []byte{})
	container.AddFileToContext(container.SoftwareOrder.PlaybookPath+"/group_vars/all", "all.yml", []byte{})
	container.AddFileToContext(container.SoftwareOrder.PlaybookPath+"/internal/soe_defaults.yml", "soe_defaults.yml", []byte{})

	// Add each role dependency
	// Grab the role's defaults from the playbook in the directory named sas_viya_playbook/roles/<host>-0x64_redhat_linux_6-yum
	container.AddFileToContext(
		container.SoftwareOrder.PlaybookPath+"/internal/soe_defaults.yml",
		"roles/sas-install/vars/soe_defaults.yml", []byte{})

	// Going to copy all the static-roles over. While this will bloat the context, it will make
	// the beginning layers the same for all images and allow for cache re-use and improve build time.
	staticRolePath := fmt.Sprintf("util/static-roles-%s/", container.SoftwareOrder.DeploymentType)
	files, err := ioutil.ReadDir(staticRolePath)
	if err != nil {
		return err
	}
	for _, file := range files {
		dep := file.Name()
		internalRolePath := fmt.Sprintf("util/static-roles-%s/%s/", container.SoftwareOrder.DeploymentType, dep)

		// The role exists in the static-roles directory, so copy the entire directory tree
		err = container.AddDirectoryToContext(internalRolePath, "roles/"+dep+"/", dep)
		if err != nil {
			return err
		}

		// Some static roles use a default entrypoint.
		// Check if there is already an entrypoint in the static role's directory, if not then add the default entrypoint.
		if _, err := os.Stat(internalRolePath + "templates/entrypoint"); os.IsNotExist(err) {
			err := container.AddFileToContext("util/entrypoint", "roles/"+dep+"/templates/entrypoint", []byte{})
			if err != nil {
				return err
			}
		}

		// Add the corresponding group_vars file if it exists in the playbook
		container.AddFileToContext(container.SoftwareOrder.PlaybookPath+"/group_vars/"+dep, "roles/"+dep+"/vars/"+dep, []byte{})
	}

	// Now put the role that is specific to the service in the /ansible/dynamicRoles directory.
	// The ansible.cfg file has this location added to the role_path so that it can be found.
	// This helps with image caching and improving build performance.
	for _, dep := range container.Config.Roles {
		internalRolePath := fmt.Sprintf("util/static-roles-%s/%s/", container.SoftwareOrder.DeploymentType, dep)
		if strings.EqualFold(container.Name, dep) {
			// If the static-role exists then copy that directory structure
			if _, err := os.Stat(internalRolePath); !os.IsNotExist(err) {
				// The role exists in the static-roles directory, so copy the entire directory tree
				err = container.AddDirectoryToContext(internalRolePath, "dynamicRoles/"+dep+"/", dep)
				if err != nil {
					return err
				}

				// Some static roles use a default entrypoint.
				// Check if there is already an entrypoint in the static role's directory, if not then add the default entrypoint.
				if _, err := os.Stat(internalRolePath + "templates/entrypoint"); os.IsNotExist(err) {
					err := container.AddFileToContext("util/entrypoint", "dynamicRoles/"+dep+"/templates/entrypoint", []byte{})
					if err != nil {
						return err
					}
				}

				// Add the corresponding group_vars file if it exists in the playbook
				container.AddFileToContext(container.SoftwareOrder.PlaybookPath+"/group_vars/"+dep, "roles/"+dep+"/vars/"+dep, []byte{})
			} else {
				//
				// The role does not exist in the static-roles directory, therefore
				// the entrypoint, templates, and vars cannot be added to the container for that role.
				//
				// Instead of using static files, get a set of defaults: util/task.yml, util/entrypoint.yml, playbook/group_vars/<name>.yml

				// Add the default entrypoint
				err := container.AddFileToContext("util/entrypoint", "dynamicRoles/"+dep+"/templates/entrypoint", []byte{})
				if err != nil {
					return err
				}

				// Find the group_vars file that corresponds to the container
				// and add the list of packages to install into the sas-install role
				varsFileName := ""
				walkPath := container.SoftwareOrder.BuildPath + "sas_viya_playbook/group_vars/"
				_ = filepath.Walk(walkPath, func(path string, info os.FileInfo, err error) error {
					// Vars file may exist at group_vars/viprESM but container name is "vipresm"
					if strings.ToLower(info.Name()) == container.Name {
						varsFileName = info.Name()
					}
					return nil
				})
				if len(varsFileName) == 0 {
					return errors.New("Unable to create dynamic role for " + container.Name)
				}
				err = container.AddFileToContext(walkPath+varsFileName, "dynamicRoles/"+dep+"/vars/"+dep, []byte{})
				if err != nil {
					return err
				}

				// Add the default task file
				if dep != "ansible" {
					err = container.AddFileToContext("util/task.yml", "dynamicRoles/"+dep+"/tasks/main.yml", []byte{})
				}
				if err != nil {
					return err
				}
			}
		}

		// Add some extra variables to every role
		otherVars := "ANSIBLE_CONTAINER: true\n"
		otherVars += fmt.Sprintf("PROJECT_NAME: \"%s\"\n", container.SoftwareOrder.ProjectName)
		container.AddFileToContext("extravars.yml", "extravars.yml", []byte(otherVars))
	}

	// Handle the addons -- Each addon has a config file that specifies which container it affects.
	for _, addon := range container.SoftwareOrder.AddOns {
		images, err := readAddonConf(addon + "addon_config.yml")
		if err != nil {
			return err
		}

		// If we don't find the image name listed we skip.
		_, targetFound := images[container.Name]
		if !targetFound {
			continue
		}

		// Add the files to the top level of the docker context
		err = container.AddDirectoryToContext(addon, "", "")
		if err != nil {
			return err
		}

		container.WriteLog("includes addons", addon)
	}

	// Create the Dockerfile and add it to the root of the context
	container.AddFileToContext("util/ansible.cfg", "ansible.cfg", []byte{})

	container.Dockerfile, err = container.CreateDockerfile()
	if err != nil {
		return err
	}
	container.AddFileToContext("", "Dockerfile", []byte(container.Dockerfile))

	// TODO: workaround for spawner-config requesting items from the casserver-config role
	//       since the programming image does not need to run ALL the casserver-config tasks
	//       Later we should de-couple spawner-config from casserver-config
	container.AddDirectoryToContext("util/static-roles-"+container.SoftwareOrder.DeploymentType+"/casserver-config/", "roles/casserver-config/", "casserver-config")
	container.AddDirectoryToContext("util/static-roles-"+container.SoftwareOrder.DeploymentType+"/cloud-config/", "roles/cloud-config/", "cloud-config")

	// Always include the sas-install role since its used by other roles
	container.AddDirectoryToContext("util/static-roles-"+container.SoftwareOrder.DeploymentType+"/sas-install/", "roles/sas-install/", "sas-install")

	// Close tar file
	container.ContextWriter.Close()

	return nil
}

// AddFileToContext writes to the container's tar file, provided EITHER externalPath or fileBytes
//
// externalPath: the absolute path on the build machine
// contextPath:  absolute path to where the file should go inside the Docker context (internal path)
//
// NOTE: If the path contains a directory at the end then you must append a "/"
func (container *Container) AddFileToContext(externalPath string, contextPath string, fileBytes []byte) error {
	// If a path on the build machine is provided then read the file
	bytes := fileBytes
	if len(bytes) == 0 {
		readBytes, err := ioutil.ReadFile(externalPath)
		if err != nil {
			return err
		}
		bytes = readBytes
	}

	// Tell the tar writer what the next block of data is
	header := &tar.Header{
		// The name of the file is the FULL path
		Name:    contextPath,
		Size:    int64(len(bytes)),
		Mode:    0777,
		ModTime: time.Now(),
	}

	if container.ContextWriter == nil {
		return errors.New("could not create docker context. Archive context writer is nil")
	}
	container.ContextWriter.WriteHeader(header)

	// Write the bytes to the tar file
	// Skip writing the file's bytes if there's no content to write (like with a directory)
	if len(bytes) == 0 {
		return nil
	}
	_, err := container.ContextWriter.Write(bytes)
	if err != nil {
		log.Println("Excluding file from context", externalPath, contextPath, err)
		container.WriteLog("Excluding files from context", externalPath, contextPath, err)
	}
	return nil
}

// AddDirectoryToContext adds all item in a directory, and its child items, to the Docker context.
//
// externalPath is the path on the build machine
// contextPath is where the file should go inside the Docker context
func (container *Container) AddDirectoryToContext(externalPath string, contextPath string, roleName string) error {
	var paths []string

	err := filepath.Walk(externalPath, func(path string, info os.FileInfo, err error) error {
		if info != nil {
			if !info.IsDir() {
				if strings.Contains(path, "Dockerfile") || strings.Contains(path, "addon_config.yml") {
					log.Println("Skipping adding file to "+container.Name+" Docker context: ", path)
					return nil
				}
				paths = append(paths, path)
			}
		}
		return nil
	})
	if err != nil {
		return err
	}

	// Utilize container.AddFileToContext to add each individual file
	for _, path := range paths {
		innerDirectory := ""
		// if we are adding an addon then we just want the filename
		// Need to copy sub-directories and preserve the directory structure
		if strings.Contains(path, "addons") {
			dirParts := strings.Split(path, "/")
			innerDirectory = strings.Replace(path, dirParts[0]+"/"+dirParts[1]+"/", "", -1)
		} else {
			// Never keep these upper level directories
			// Always keep intermediate directories. For example,
			//          Given external=templates/static-roles-<deployment>/sas-java, context=roles/sas-java/
			//          roles/sas-java/main.yml should be roles/sas-java/tasks/main.yml (keep /tasks/)
			innerDirectory = strings.Replace(path, "util/static-roles-"+container.SoftwareOrder.DeploymentType+"/"+roleName+"/", "", -1)
			innerDirectory = strings.Replace(innerDirectory, "/internal/", "", -1)
			innerDirectory = strings.Replace(innerDirectory, "sas_viya_playbook", "", -1)
		}

		err := container.AddFileToContext(path, contextPath+innerDirectory, []byte{})
		if err != nil {
			return err
		}
	}
	return nil
}

// Finish shuts down open file handles and client connections
func (container *Container) Finish() error {
	err := container.DockerClient.Close()
	if err != nil {
		container.WriteLog("failed to close docker client", err)
		return err
	}

	err = container.Log.Close()
	if err != nil {
		container.WriteLog("failed to close log handle", err)
		return err
	}

	container.ContextWriter.Close()
	return nil
}
