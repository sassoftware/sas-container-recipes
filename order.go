// order.go
// For loading a Software Order Email and parsing the order's content
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
	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"

	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"io/ioutil"
	"log"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"regexp"
	"runtime"
	"strconv"
	"strings"
	"time"
)

// Format <year>.<month>.<numbered release>
const RECIPE_VERSION = "19.04.0"

// Used to wget the corresponding sas-orchestration tool version
// example: 34 = version 3.4
const SAS_VIYA_VERSION = "34"

// Path to the configuration file that's used to load custom container attributes
// NOTE: this path changes to config-<deployment-type>.yml
var CONFIG_PATH = "config-full.yml"

type SoftwareOrder struct {

	// Build arguments and flags (see order.LoadCommands for details)
	LicensePath          string
	BaseImage            string
	MirrorURL            string
	VirtualHost          string
	DockerNamespace      string
	DockerRegistry       string
	DeploymentType       string
	PlaybookPath         string
	Platform             string
	ProjectName          string
	TagOverride          string
	AddOns               []string
	DebugContainers      []string
	WorkerCount          int
	Verbose              bool
	SkipMirrorValidation bool
	SkipDockerValidation bool

	// Build attributes
	TimestampTag string                // Allows for datetime on each temp build bfile
	Containers   map[string]*Container // Individual containers build list
	BuildOnly    []string              // Only build these specific containers from the whole list
	Config       map[string]ConfigMap  // Static values and defaults are loaded from the configmap yaml
	ConfigPath   string                // config-<deployment-type>.yml file for custom or static values
	Log          *os.File              // File handle for log path
	LogPath      string                // Path to the build directory with the log file name
	KVStore      string                // Combines all vars.yaml content
	BuildContext context.Context       // Background context
	RegistryAuth string                // Used to push and pull from/to a regitry
	BuildPath    string                // Kubernetes manifests are generated and placed into this location
	CertBaseURL  string                // The URL that the build containers will use to fetch their CA and entitlement certs

	// Metrics
	StartTime      time.Time
	EndTime        time.Time
	TotalBuildSize int64
	DockerClient   *client.Client // Used to pull the base image and output post-build details

	// License attributes from the Software Order Email (SOE)
	// SAS_Viya_deployment_data.zip
	// ├── ca-certificates
	// │   └── SAS_CA_Certificate.pem
	// ├── entitlement-certificates
	// │   ├── entitlement_certificate.pem
	// │   └── entitlement_certificate.pfx
	// ├── license
	// │   └── SASViyaV0300_XXXXXX_Linux_x86-64.txt
	// │   └── SASViyaV0300_XXXXXX_XXXXXXXX_Linux_x86-64.jwt
	// └── order.oom
	SOEZipPath string // Used to load licenses
	OrderOOM   struct {
		OomFormatVersion string `json:"oomFormatVersion"`
		MetaRepo         struct {
			URL        string   `json:"url"`
			Rpm        string   `json:"rpm"`
			Orderables []string `json:"orderables"`
		} `json:"metaRepo"`
	}
	CA             []byte
	Entitlement    []byte
	License        []byte
	MeteredLicense []byte
}

// For reading ~/.docker/config.json
// example:
//{
//    "auths": {
//        "docker.mycompany.com": {
//            "auth": "Zaoiqw0==" <-- this is a base64 string
//        }
//    },
//}
type Registry struct {
	Auths map[string]struct {
		Username string `json:"username"` // Optional
		Password string `json:"password"` // Optional
		Auth     string `json:"auth"`     // Required
	} `json:"auths"`
}

// Each container has a configmap which define Docker layers.
// A static configmap.yml file is parsed and all containers
// that do not have static values are set to the defaults
type ConfigMap struct {
	Ports       []string `yaml:"ports"`       // Default: empty
	Environment []string `yaml:"environment"` // Default: empty
	Secrets     []string `yaml:"secrets"`     // Default: empty
	Roles       []string `yaml:"roles"`       // Additional ansible roles to run
	Volumes     []string `yaml:"volumes"`     // Default: log:/opt/sas/viya/config/var/log
	Resources   struct {
		Limits   []string `yaml:"limits"`
		Requests []string `yaml:"requests"`
	} `yaml:"resources"`
}

// Once the SOE zip file path has been provided then load all the Software Order's details
// Note: All sub-processes of this function are essential to the build process.
//       If any of these steps return an error then the entire process will be exited.
func NewSoftwareOrder() (*SoftwareOrder, error) {
	order := &SoftwareOrder{}
	order.StartTime = time.Now()
	order.TimestampTag = string(order.StartTime.Format("2006-01-02-15-04-05"))

	if err := order.LoadCommands(); err != nil {
		return order, err
	}

	// Point to custom configuration yaml files
	order.ConfigPath = "config-full.yml"
	if order.DeploymentType == "multiple" {
		order.ConfigPath = "config-multiple.yml"
	}

	order.BuildPath = fmt.Sprintf("builds/%s-%s/", order.DeploymentType, order.TimestampTag)
	if err := os.MkdirAll(order.BuildPath+"manifests", 0744); err != nil {
		return order, err
	}
	symlinkCommand := fmt.Sprintf("cd builds && rm -rf %s && ln -s %s-%s %s", order.DeploymentType, order.DeploymentType, order.TimestampTag, order.DeploymentType)
	cmd := exec.Command("sh", "-c", symlinkCommand)
	stderr, err := cmd.StderrPipe()
	if err := cmd.Start(); err != nil {
		log.Fatal(err)
	}

	slurp, _ := ioutil.ReadAll(stderr)
	fmt.Printf("%s\n", slurp)

	if err := cmd.Wait(); err != nil {
		return order, err
	}
	//order.WriteLog(true, symlinkCommand)
	//_, err := exec.Command("sh", "-c", symlinkCommand).Output()
	//order.WriteLog(true, out)
	if err != nil {
		return order, err
	}
	order.LogPath = order.BuildPath + "/build.log"
	logHandle, err := os.Create(order.LogPath)
	if err != nil {
		return order, err
	}
	order.Log = logHandle

	// Start a worker pool and wait for all workers to finish
	workerCount := 0 // Number of goroutines started
	done := make(chan int)
	fail := make(chan string)
	progress := make(chan string)

	workerCount++
	go order.LoadPlaybook(progress, fail, done)

	workerCount++
	go order.LoadLicense(progress, fail, done)

	workerCount++
	go order.LoadDocker(progress, fail, done)

	workerCount++
	go order.LoadRegistryAuth(fail, done)

	if !order.SkipDockerValidation {
		workerCount++
		go order.TestRegistry(progress, fail, done)
	}

	if !order.SkipMirrorValidation {
		workerCount++
		go order.TestMirror(progress, fail, done)
	}

	doneCount := 0
	for {
		select {
		case <-done:
			doneCount++
			if doneCount == workerCount {
				// After the configs have been loaded then pre-build the containers and generate the manifests
				err := order.Prepare()
				if err != nil {
					return order, err
				}
				return order, nil
			}
		case failure := <-fail:
			return order, errors.New(failure)
		case progress := <-progress:
			order.WriteLog(true, progress)
		}
	}
}

// Look through the network interfaces and find the machine's non-loopback IP
func getIPAddr() (string, error) {
	addrs, err := net.InterfaceAddrs()
	if err != nil {
		return "", err
	}

	for _, a := range addrs {
		if ipnet, ok := a.(*net.IPNet); ok && !ipnet.IP.IsLoopback() {
			if ipnet.IP.To4() != nil {
				return ipnet.IP.String(), nil
			}
		}
	}
	return "", errors.New("No IP found for serving playbook")
}

// Serve up the entitlement and CA cert on a random port from the host so
// the contents of these files don't exist in any docker layer or history.
func (order *SoftwareOrder) Serve() {
	listener, err := net.Listen("tcp", ":0")
	if err != nil {
		panic(err)
	}
	hostAndPort := listener.Addr().String()
	parts := strings.Split(hostAndPort, ":")
	port, err := strconv.Atoi(parts[len(parts)-1])
	if err != nil {
		panic(err)
	}
	hostIP, err := getIPAddr()
	if err != nil {
		panic(err)
	}

	// Serve only two endpoints to receive the entitlement and CA
	order.WriteLog(true, fmt.Sprintf("Serving license and entitlement on %s:%d", hostIP, port))
	order.CertBaseURL = fmt.Sprintf("http://%s:%d", hostIP, port)
	http.HandleFunc("/entitlement/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, string(order.Entitlement))
	})
	http.HandleFunc("/cacert/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, string(order.CA))
	})
	http.Serve(listener, nil)
}

// Multiplexer for writing logs.
// Write any number of object info to the build log file and/or to standard output
func (order *SoftwareOrder) WriteLog(writeToStdout bool, contentBlocks ...interface{}) {
	// Write each block to standard output
	if writeToStdout {
		for _, block := range contentBlocks {
			log.Println(block)
		}
	}

	// Write the filename and line number
	_, fullFilePath, fileCallerLineNumber, _ := runtime.Caller(1)
	filePathSections := strings.Split(fullFilePath, "/")
	fileCallerName := filePathSections[len(filePathSections)-1]
	order.Log.Write([]byte(fmt.Sprintf("[%s:%d] ",
		fileCallerName, fileCallerLineNumber)))

	// Write each interface
	for _, block := range contentBlocks {
		order.Log.Write([]byte(fmt.Sprintf("%v\n", block)))
	}
	order.Log.Write([]byte("\n"))
}

// Return the output of how many and which containers have been built
// out of the total number of builds.
// This is displayed after a container finishes its build process.
func (order *SoftwareOrder) GetIntermediateStatus(progress chan string) {
	finishedContainers := []string{}
	remainingContainers := []string{}
	for _, container := range order.Containers {
		if container.Status == Pushed {
			finishedContainers = append(finishedContainers, container.Name)
		} else if container.Status != DoNotBuild {
			remainingContainers = append(remainingContainers, container.Name)
		}
	}

	if len(remainingContainers) == 0 {
		// Don't show anything once all have completed since the final build summary displays
		return
	}

	progress <- fmt.Sprintf("Built & Pushed [ %d / %d ].\nComplete: %s\nRemaining: %s\n",
		len(finishedContainers), len(finishedContainers)+len(remainingContainers),
		strings.Join(finishedContainers, ", "), strings.Join(remainingContainers, ", "))
}

// Recieve flags and arguments, parse them, and load them into the order
func (order *SoftwareOrder) LoadCommands() error {
	// Standard format that arguments must comply with
	regexNoSpecialCharacters := regexp.MustCompile("^[_A-z0-9]*([_A-z0-9\\-\\.]*)$")

	// Required arguments
	license := flag.String("zip", "", "")
	dockerNamespace := flag.String("docker-namespace", "", "")
	dockerRegistry := flag.String("docker-registry-url", "", "")

	// Optional arguments
	virtualHost := flag.String("virtual-host", "myvirtualhost.mycompany.com", "")
	addons := flag.String("addons", "", "")
	baseImage := flag.String("base-image", "centos:7", "")
	mirrorURL := flag.String("mirror-url", "", "")
	verbose := flag.Bool("verbose", false, "")
	buildOnly := flag.String("build-only", "", "")
	tagOverride := flag.String("tag", RECIPE_VERSION+"-"+order.TimestampTag, "")
	projectName := flag.String("project-name", "sas-viya", "")
	deploymentType := flag.String("type", "single", "")
	version := flag.Bool("version", false, "")
	skipMirrorValidation := flag.Bool("skip-mirror-url-validation", false, "")
	skipDockerValidation := flag.Bool("skip-docker-url-validation", false, "")

	// By default detect the cpu core count and utilize all of them
	defaultWorkerCount := runtime.NumCPU()
	workerCount := flag.Int("workers", defaultWorkerCount, "")
	order.WorkerCount = *workerCount
	if *workerCount == 0 || *workerCount > defaultWorkerCount {
		err := errors.New("Invalid '--worker' count, must be less than or equal to the number of CPU cores that are free and permissible in your cgroup configuration.")
		return err
	}

	// Allow for quick exit if only viewing the --version or --help
	flag.Usage = func() {
		fmt.Println(usage)
		os.Exit(0)
	}
	flag.Parse()
	if *version == true {
		fmt.Println("SAS Container Recipes v" + RECIPE_VERSION)
		os.Exit(0)
	}

	order.Verbose = *verbose
	order.SkipMirrorValidation = *skipMirrorValidation
	order.SkipDockerValidation = *skipDockerValidation

	// This is a safeguard for when a user does not use quotes around a multi value argument
	otherArgs := flag.Args()
	if len(otherArgs) > 0 {
		progressString := "WARNING: one or more arguments were not parsed. Quotes are required for multi-value arguments."
		order.WriteLog(true, progressString)
	}

	// Always require a license
	if *license == "" {
		err := errors.New("A software order email (SOE) '--license' file is required.")
		return err
	}
	order.SOEZipPath = *license

	// Always require a deployment type
	if *deploymentType != "multiple" && *deploymentType != "full" && *deploymentType != "single" {
		err := errors.New("A valid '--type' is required: choose between single, multiple, or full.")
		return err
	}
	order.DeploymentType = strings.ToLower(*deploymentType)

	// Optional: Parse the list of addons
	*addons = strings.TrimSpace(*addons)
	if *addons == "" {
		order.AddOns = []string{}
	} else {
		// Accept a list of addon names delimited by a space or a comma
		spaces, _ := regexp.Compile("[ ,]+") // math spaces or commas
		addonString := spaces.ReplaceAllString(strings.TrimSpace(*addons), " ")

		addonList := strings.Split(addonString, " ")
		for _, addon := range addonList {

			addonPath := addon

			// if addon does not exist at specified path, check addons/ADDON.
			// If addons/ADDON does not exist, return an error
			if _, err := os.Stat(addonPath); err != nil {
				// Try with 'addons/'
				addonPath = "addons/" + addonPath
				if _, err = os.Stat(addonPath); err != nil {
					return fmt.Errorf("Addon %s could not be found", addon)
				}
			}
			if !strings.HasSuffix(addonPath, "/") {
				addonPath = addonPath + "/"
			}
			order.AddOns = append(order.AddOns, addonPath)
		}

		order.WriteLog(true, "Building with addons", order.AddOns)
	}

	// Detect the platform based on the image
	order.BaseImage = *baseImage
	if strings.Contains(order.BaseImage, "opensuse") {
		order.Platform = "suse"
	} else {
		// By default use rpm + yum
		order.Platform = "redhat"
	}

	// A mirror is optional, except in the case of using an opensuse base image
	order.MirrorURL = *mirrorURL
	if len(order.MirrorURL) == 0 && order.DeploymentType == "single" && order.Platform == "suse" {
		return errors.New("A --mirror-url argument is required for a base suse single container.")
	}

	// Optional: override the standard tag format
	order.TagOverride = *tagOverride
	if len(order.TagOverride) > 0 && !regexNoSpecialCharacters.Match([]byte(order.TagOverride)) {
		return errors.New("The --tag argument contains invalid characters. It must contain contain only A-Z, a-z, 0-9, _, ., or -")
	}

	// Optional: override the "sas-viya-" prefix in image names and in the deployment
	order.ProjectName = *projectName
	if len(order.ProjectName) > 0 && !regexNoSpecialCharacters.Match([]byte(order.TagOverride)) {
		return errors.New("The --project-name argument contains invalid characters. It must contain contain only A-Z, a-z, 0-9, _, ., or -")
	}

	// The next arguments do not apply to the single deployment type
	if order.DeploymentType == "single" {
		return nil
	}

	// Require a docker namespace for multi and full
	if *dockerNamespace == "" {
		err := errors.New("A '--docker-namespace' argument is required.")
		return err
	}
	order.DockerNamespace = *dockerNamespace
	if !regexNoSpecialCharacters.Match([]byte(order.DockerNamespace)) {
		return errors.New("The --docker-namespace argument contains invalid characters. It must contain contain only A-Z, a-z, 0-9, _, ., or -")
	}

	// Require a docker registry for multi and full
	if *dockerRegistry == "" {
		err := errors.New("A '--docker-registry-url' argument is required.")
		return err
	}
	order.DockerRegistry = *dockerRegistry

	// The deployment type utilizes the order.BuildOnly list
	// Note: the 'full' deployment type builds everything, omitting the --build-only argument
	if order.DeploymentType == "multiple" {
		order.BuildOnly = []string{"programming", "httpproxy", "sas-casserver-primary"}
	}
	if order.DeploymentType == "full" {
		order.WriteLog(true, `
  _______  ______  _____ ____  ___ __  __ _____ _   _ _____  _    _     
 | ____\ \/ /  _ \| ____|  _ \|_ _|  \/  | ____| \ | |_   _|/ \  | |    
 |  _|  \  /| |_) |  _| | |_) || || |\/| |  _| |  \| | | | / _ \ | |    
 | |___ /  \|  __/| |___|  _ < | || |  | | |___| |\  | | |/ ___ \| |___ 
 |_____/_/\_\_|   |_____|_| \_\___|_|  |_|_____|_| \_| |_/_/   \_\_____|
            `)
	}

	// Parse the list of buildOnly arguments
	*buildOnly = strings.TrimSpace(*buildOnly)
	if *buildOnly != "" {
		// Accept a list of container names delimited by a space or a comma
		spaceDelimList := strings.Split(*buildOnly, " ")
		commaDelimList := strings.Split(*buildOnly, ",")
		order.BuildOnly = spaceDelimList
		if len(spaceDelimList) < len(commaDelimList) {
			order.BuildOnly = commaDelimList
		}
		order.WriteLog(true, "Building only:", order.BuildOnly)
	}

	order.VirtualHost = *virtualHost

	return nil
}

func buildWorker(id int, containers <-chan *Container, done chan<- string, progress chan string, fail chan string) {
	for container := range containers {
		if container.Status != Loaded {
			continue
		}

		// Build
		container.BuildStart = time.Now()
		err := container.Build(progress)
		if err != nil {
			container.Status = Failed
			fail <- container.Name + ":" + container.Tag + " container build " + err.Error()
			return
		}
		container.BuildEnd = time.Now()
		if container.Status != Failed {
			container.Status = Built
		}

		// Get each image's size
		filterArgs := filters.NewArgs()
		filterArgs.Add("reference", container.GetWholeImageName())
		imageInfo, err := container.SoftwareOrder.DockerClient.ImageList(container.SoftwareOrder.BuildContext,
			types.ImageListOptions{Filters: filterArgs})
		if err != nil {
			container.SoftwareOrder.WriteLog(true, "Unable to connect to Docker client for image build sizes")
		}
		imageSize := imageInfo[0].Size
		container.SoftwareOrder.TotalBuildSize += imageSize
		container.ImageSize = imageSize

		// Push
		container.PushStart = time.Now()
		err = container.Push(progress)
		if err != nil {
			container.Status = Failed
			fail <- container.GetWholeImageName() + " container push " + err.Error()
			done <- container.Name
			return
		}
		container.PushEnd = time.Now()

		// Signal the end of the build and push processes
		container.Status = Pushed
		progress <- container.GetWholeImageName() + ": finished pushing image to Docker registry"
		container.SoftwareOrder.GetIntermediateStatus(progress)
		done <- container.Name
	}
}

// The single container deployment type has a unique
// Grab the Dockerfile stub from the utils directory and append any addons
// then do a docker build with the base image and platform build arguments
// TODO: using license in RUN layers and mounting as volume?
func buildProgrammingOnlySingleContainer(order *SoftwareOrder) error {
	container := Container{
		Name:          "single-programming-only",
		SoftwareOrder: order,
		BaseImage:     order.BaseImage,
	}

	dockerConnection, err := client.NewClientWithOpts(client.WithVersion(DOCKER_API_VERSION))
	if err != nil {
		debugMessage := "Unable to connect to Docker daemon. Ensure Docker is installed and the service is started. "
		return errors.New(debugMessage + err.Error())
	}
	container.DockerClient = dockerConnection

	// Create the build context and add relevant files to the context
	resourceDirectory := "util/programming-only-single"
	err = container.CreateBuildDirectory()
	if err != nil {
		return err
	}
	container.DockerContextPath = container.SoftwareOrder.BuildPath + "sas-viya-single-programming-only/build_context.tar"
	err = container.AddFileToContext(resourceDirectory+"/vars_usermods.yml", "vars_usermods.yml", []byte{})
	if err != nil {
		return err
	}
	err = container.AddFileToContext(resourceDirectory+"/entrypoint", "entrypoint", []byte{})
	if err != nil {
		return err
	}
	err = container.AddFileToContext(resourceDirectory+"/replace_httpd_default_cert.sh", "replace_httpd_default_cert.sh", []byte{})
	if err != nil {
		return err
	}

	// TODO: the SOE should not be added to the container. Need to update the Dockerfile to utilize a license volume mount.
	err = container.AddFileToContext(container.SoftwareOrder.SOEZipPath, "SAS_Viya_deployment_data.zip", []byte{})
	if err != nil {
		return err
	}

	// Add files from the addons directory to the build context
	for _, addon := range order.AddOns {
		err := container.AddDirectoryToContext(addon, "", "")
		if err != nil {
			return errors.New("Unable to place addon files into Docker context. " + err.Error())
		}
	}

	// Add the Dockerfile to the build context
	dockerfileStub, err := ioutil.ReadFile(resourceDirectory + "/Dockerfile")
	if err != nil {
		return err
	}
	dockerfile, err := appendAddonLines(container.Name, string(dockerfileStub), container.SoftwareOrder.AddOns)
	if err != nil {
		return err
	}
	err = container.AddFileToContext("", "Dockerfile", []byte(dockerfile))
	if err != nil {
		return err
	}

	// Set the payload to send to the Docker client
	dockerBuildContext, err := os.Open(container.DockerContextPath)
	if err != nil {
		return err
	}
	container.GetBuildArgs()
	buildOptions := types.ImageBuildOptions{
		Context:    dockerBuildContext,
		Tags:       []string{container.GetName()},
		Dockerfile: "Dockerfile",
		BuildArgs:  container.BuildArgs,
	}
	buildResponseStream, err := container.DockerClient.ImageBuild(
		container.SoftwareOrder.BuildContext,
		dockerBuildContext,
		buildOptions)
	if err != nil {
		return err
	}
	return readDockerStream(buildResponseStream.Body, &container, true, nil)
}

// Start each container build concurrently and report the results
func (order *SoftwareOrder) Build() error {

	// Handle single container build and output of docker run instructions
	if order.DeploymentType == "single" {
		err := buildProgrammingOnlySingleContainer(order)
		if err != nil {
			return err
		}

		// TODO: this does not use the Fully Qualified Domain Name
		hostname, err := os.Hostname()
		if err != nil {
			return err
		}
		fmt.Println("\n" + fmt.Sprintf(`Run the following to start the container:

    docker run --detach --rm --env CASENV_CAS_VIRTUAL_HOST=%s \
    --env CASENV_CAS_VIRTUAL_PORT=8081 --publish-all --publish 8081:80 \
    --name sas-viya-single-programming-only --hostname %s \
    sas-viya-single-programming-only:latest
`, hostname, hostname))

		return nil
	}

	// Handle all other deployment types
	numberOfBuilds := 0
	for _, container := range order.Containers {
		if container.Status == Loaded {
			numberOfBuilds++
		}
	}
	fmt.Println("")
	if numberOfBuilds == 0 {
		return errors.New("The number of builds are set to zero. " +
			"An error in pre-build tasks may have occured or the " +
			"Software Order entitlement does not match the deployment type.")
	} else if numberOfBuilds == 1 {
		// Use the singular "process" instead of "processes"
		order.WriteLog(true, "Starting "+strconv.Itoa(numberOfBuilds)+" build process ... (this may take several minutes)")
	} else {
		// Use the plural "processes" instead of "process"
		order.WriteLog(true, "Starting "+strconv.Itoa(numberOfBuilds)+" build processes ... (this may take several minutes)")
	}
	if !order.Verbose {
		order.WriteLog(true, "[TIP] The '--verbose' flag can be used to view the Docker build layers as they are being created.")
	}
	order.WriteLog(true, "[TIP] System resource utilization can be seen by using the `docker stats` command.")
	fmt.Println("")

	// Concurrently start each build process
	jobs := make(chan *Container, 100)
	fail := make(chan string)
	done := make(chan string)
	progress := make(chan string)
	for w := 1; w <= order.WorkerCount; w++ {
		go buildWorker(w, jobs, done, progress, fail)
	}
	for _, container := range order.Containers {
		jobs <- container
	}
	close(jobs)
	doneCount := 0
	for {
		select {
		case <-done:
			doneCount++
			if doneCount == numberOfBuilds {
				order.Finish()
				return nil
			}
		case failure := <-fail:
			order.WriteLog(true, failure)
			return errors.New(failure)
		case progress := <-progress:
			order.WriteLog(true, progress)
		}
	}
	return nil
}

// Get the names of each individual host to be created
//
// Read the sas_viya_playbook directory for the "group_vars" where each
// file individually defines a host. There is one container per host.
func getContainers(order *SoftwareOrder) (map[string]*Container, error) {
	containers := make(map[string]*Container)

	// These values are not added to the final hostGroup list result
	var ignoredContainers = [...]string{
		"all", "sas-all", "CommandLine",
		"sas-casserver-secondary", "sas-casserver-worker",
	}

	// The names inside the playbook's inventory file are mapped to hosts
	inventoryBytes, err := ioutil.ReadFile(order.BuildPath + "sas_viya_playbook/" + "inventory.ini")
	if err != nil {
		return containers, err
	}
	inventory := string(inventoryBytes)
	startLine := 0
	startOfSection := "[sas-all:children]"
	lines := strings.Split(inventory, "\n")
	for index, line := range lines {
		if line == startOfSection {
			startLine = index
		}
	}
	if startLine == 0 {
		return containers, errors.New("Cannot find inventory.ini section with all container names")
	}
	for i := startLine + 1; i < len(lines); i++ {
		skip := false
		name := lines[i]
		for _, ignored := range ignoredContainers {
			if name == ignored {
				skip = true
			}
		}
		if skip || len(strings.TrimSpace(name)) == 0 {
			continue
		}

		container := Container{
			Name:          strings.ToLower(name),
			SoftwareOrder: order,
			Status:        Unknown,
			BaseImage:     order.BaseImage,
		}
		container.Tag = container.GetTag()
		containers[container.Name] = &container
	}

	return containers, nil
}

// Once the path to the Software Order Email (SOE) zip file has been provided then unzip it
// and load the content into the SoftwareOrder struct for use in the build process.
func (order *SoftwareOrder) LoadLicense(progress chan string, fail chan string, done chan int) {
	progress <- "Reading Software Order Email Zip ..."

	if _, err := os.Stat(order.SOEZipPath); os.IsNotExist(err) {
		fail <- err.Error()
	}

	zipped, err := zip.OpenReader(order.SOEZipPath)
	if err != nil {
		fail <- err.Error()
	}
	defer zipped.Close()

	// Iterate through the files in the archive and print content for each
	for _, zippedFile := range zipped.File {

		// Read the string content and see what file it is, then load it into the order
		readCloser, err := zippedFile.Open()
		if err != nil {
			fail <- err.Error()
		}
		buffer := new(bytes.Buffer)
		_, err = io.Copy(buffer, readCloser)
		if err != nil {
			fail <- err.Error()
		}
		fileBytes, err := ioutil.ReadAll(buffer)
		if err != nil {
			fail <- err.Error()
		}
		readCloser.Close()

		if strings.Contains(zippedFile.Name, "Linux_x86-64.txt") {
			order.License = fileBytes
		} else if strings.Contains(zippedFile.Name, "Linux_x86-64.jwt") {
			order.MeteredLicense = fileBytes
		} else if strings.Contains(zippedFile.Name, "SAS_CA_Certificate.pem") {
			order.CA = fileBytes
		} else if strings.Contains(zippedFile.Name, "entitlement_certificate.pem") {
			order.Entitlement = fileBytes
		} else if strings.Contains(zippedFile.Name, "order.oom") {
			err := json.Unmarshal(fileBytes, &order.OrderOOM)
			if err != nil {
				fail <- err.Error()
			}
		}
	}

	// Make sure all required files were loaded into the order
	if len(order.License) == 0 || len(order.MeteredLicense) == 0 || len(order.CA) == 0 || len(order.Entitlement) == 0 {
		fail <- "Unable to parse all content from SOE zip"
	}

	go order.Serve()

	progress <- "Finished reading Software Order Email"
	done <- 1
}

// Ensure the Docker client is accessible and pull the specified base image from Docker Hub
func (order *SoftwareOrder) LoadDocker(progress chan string, fail chan string, done chan int) {

	// Make sure Docker is able to connect
	progress <- "Connecting to the Docker daemon  ..."
	dockerConnection, err := client.NewClientWithOpts(client.WithVersion("1.37"))
	if err != nil {
		fail <- "Unable to connect to Docker daemon. Ensure Docker is installed and the service is started."
	}
	order.DockerClient = dockerConnection
	progress <- "Finished connecting to Docker daemon"

	// Pull the base image depending on what the argument was
	progress <- "Pulling base container image '" + order.BaseImage + "'" + " ..."
	order.BuildContext = context.Background()
	_, err = order.DockerClient.ImagePull(order.BuildContext, order.BaseImage, types.ImagePullOptions{})
	if err != nil {
		fail <- err.Error()
	}

	progress <- "Finished pulling base container image '" + order.BaseImage + "'"
	done <- 1
}

// Run a simple curl on the mirror URL to see if it's accessible.
// This is a preliminary check so an error is less likely to occur once the build starts
//
// NOTE: this does not support a local registry filesystem path
func (order *SoftwareOrder) TestMirror(progress chan string, fail chan string, done chan int) {
	if len(order.MirrorURL) > 0 {
		if strings.Contains(order.MirrorURL, "http://") {
			fail <- "The --mirror-url must have TLS enabled. Provide the url with 'https' instead of 'http' in the command argument."
		}
		url := order.MirrorURL
		if !strings.Contains(order.MirrorURL, "https://") {
			url = "https://" + order.MirrorURL
		}
		progress <- "Checking the mirror URL for validity ... curl " + url
		response, err := http.Get(url)
		if err != nil {
			fail <- err.Error()
		}
		defer response.Body.Close()
		if response.StatusCode != 200 {
			fail <- "Invalid mirror URL " + err.Error()
		}
		progress <- "Finished checking the mirror URL for validity: http status code " + strconv.Itoa(response.StatusCode)
	}
	done <- 1
}

// Run a simple curl on the registry to see if it's accessible.
// This is a preliminary check so an error is less likely to occur after the build, once the built images are being pushed
func (order *SoftwareOrder) TestRegistry(progress chan string, fail chan string, done chan int) {
	if order.DeploymentType == "single" {
		// Single container deployment does not use a registry so skip this
		done <- 1
		return
	}
	if strings.Contains(order.DockerRegistry, "http://") {
		fail <- "The --docker-registry-url must have TLS enabled. Provide the url with 'https' instead of 'http' in the command argument."
	}
	url := order.DockerRegistry
	if !strings.Contains(order.DockerRegistry, "https://") {
		url = "https://" + order.DockerRegistry
	}
	progress <- "Checking the Docker registry URL for validity ... curl " + url
	response, err := http.Get(url)
	if err != nil {
		fail <- err.Error()
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		fail <- "Invalid Docker registry URL  " + err.Error()
		fail <- "The URL cannot contain 'http' or 'https'. Also the registry also be configured for https. "
	}
	progress <- "Finished checking the Docker registry URL for validity: http status code " + strconv.Itoa(response.StatusCode)

	done <- 1
}

// Load the registry auth from $USERHOME/.docker/config.json
func (order *SoftwareOrder) LoadRegistryAuth(fail chan string, done chan int) {
	userObject, err := user.Current()
	if err != nil {
		fail <- "Cannot get user home directory path for docker config. " + err.Error()
	}
	dockerConfigPath := fmt.Sprintf("%s/.docker/config.json", userObject.HomeDir)
	order.WriteLog(true, "Reading config from "+dockerConfigPath)
	configContent, err := ioutil.ReadFile(dockerConfigPath)
	if err != nil {
		fail <- "Cannot read Docker configuration or file read permission is not permitted in " + dockerConfigPath + " run a `docker login <registry>`. " + err.Error()
	}
	config := string(configContent)
	if !strings.Contains(config, order.DockerRegistry) {
		fail <- "Cannot find the --docker-registry-url in the Docker config. Run `docker login <registry>` before building."
	}

	// Parse the docker registry URL's auth
	//"auths": {
	//	"docker.mycompany.com": {
	//		"auth": "Y29J79JPO=="
	//	},
	// TODO: clean this up... substrings are sloppy but marshalling the interface was too annoying to start with
	startSection := strings.Index(config, order.DockerRegistry)
	config = config[startSection:]
	endSection := strings.Index(config, "},")
	config = config[0:endSection]
	authSection := "\"auth\": \""
	startAuth := strings.Index(config, "\"auth\": \"")
	config = strings.TrimSpace(config[startAuth+len(authSection)-1:])
	config = strings.Replace(config, "\"", "", -1)
	config = strings.Replace(config, "\n", "", -1)
	config = strings.Replace(config, "\t", "", -1)

	order.RegistryAuth = config

	done <- 1
}

// Use the orchestration tool to generate an Ansible playbook from the Software Order Email Zip
func (order *SoftwareOrder) LoadPlaybook(progress chan string, fail chan string, done chan int) {

	// Check to see if the tool exists
	progress <- "Fetching orchestration tool ..."
	err := getOrchestrationTool()
	if err != nil {
		fail <- "Failed to install sas-orchestration tool. " + err.Error()
	}
	progress <- "Finished fetching orchestration tool"

	// Run the orchestration tool to make the playbook
	// TODO: error handling, passing info back from the build command
	progress <- "Generating playbook for order ..."
	generatePlaybookCommand := fmt.Sprintf("util/sas-orchestration build --input %s --output %ssas_viya_playbook.tgz", order.SOEZipPath, order.BuildPath)
	_, err = exec.Command("sh", "-c", generatePlaybookCommand).Output()
	if err != nil {
		fail <- "[ERROR]: Unable to generate the playbook. java-1.8.0-openjdk or another Java Runtime Environment (1.8.x) must be installed. " +
			err.Error() + "\n" + generatePlaybookCommand
	}

	// Detect if Ansible is installed.
	// This is required for the Generate Manifests function in multiple and full deployment types, not in the single container.
	if order.DeploymentType != "single" {
		testAnsibleInstall := "ansible --version"
		_, err = exec.Command("sh", "-c", testAnsibleInstall).Output()
		if err != nil {
			fail <- "[ERROR]: The package `ansible` must be installed in order to generate Kubernetes manifests."
		}
	}

	// TODO replace with "golang.org/x/build/internal/untar"
	progress <- "Extracting generated playbook content ..."
	untarPlaybookCommand := fmt.Sprintf("tar --extract --file %ssas_viya_playbook.tgz -C %s", order.BuildPath, order.BuildPath)
	_, err = exec.Command("sh", "-c", untarPlaybookCommand).Output()
	if err != nil {
		fail <- "Unable to untar playbook. " + err.Error()
	}
	order.PlaybookPath = order.BuildPath + "sas_viya_playbook"
	err = os.Remove(order.BuildPath + "sas_viya_playbook.tgz")
	if err != nil {
		fail <- "Unable to untar playbook. " + err.Error()
	}
	progress <- "Finished extracting and generating playbook for order"

	// Get a list of the containers to be built
	progress <- "Fetching the list of containers in the order ..."
	order.Containers, err = getContainers(order)
	if err != nil {
		fail <- err.Error()
	}
	progress <- "Finished fetching the container list"

	// Handle --build-only without modifying the order's container attributes
	numberOfBuilds := len(order.Containers)
	if len(order.BuildOnly) > 0 {

		// If the image is not in the --build-only list then set its status to Do Not Build
		totalMatchesFound := 0
		for index, container := range order.Containers {
			matchFound := false
			for _, target := range order.BuildOnly {
				// Container's name is in the --build-only list
				if strings.ToLower(strings.TrimSpace(target)) == strings.ToLower(strings.TrimSpace(container.Name)) {
					totalMatchesFound += 1
					matchFound = true
				}
			}
			if !matchFound {
				order.Containers[index].Status = DoNotBuild
			}
		}

		// Make sure there is at least 1 image going to be built
		numberOfBuilds = totalMatchesFound
		if len(order.BuildOnly) != numberOfBuilds {
			// TODO: show which containers do not apply to the software order
			fail <- "One or more of the chosen --build-only containers do not exist"
		}
	}

	done <- 1
}

// Concurrently load all container's configurations if the container is staged to be built
func (order *SoftwareOrder) Prepare() error {
	// Ignore this in the single container
	if order.DeploymentType == "single" {
		return nil
	}

	// Call a prebuild on each container
	fail := make(chan string)
	done := make(chan string)
	progress := make(chan string)
	workerCount := 0
	for _, container := range order.Containers {
		if container.Status != DoNotBuild {
			workerCount += 1
			go func(container *Container, progress chan string, fail chan string) {
				container.Status = Loading
				err := container.Prebuild(progress)
				if err != nil {
					container.Status = Failed
					fail <- container.Name + " prebuild " + err.Error()
				}
				done <- container.Name
			}(container, progress, fail)
		}
	}

	// Wait for the worker pool to finish
	doneCount := 0
	for {
		select {
		case <-done:
			doneCount += 1
			if doneCount == workerCount {
				// Generate the Kubernetes manifests since we have all the details to do so before the build
				// Note: This is a time saver, though the manifests are not valid if the images
				//       fail to build or fail to push to the registry.
				err := order.GenerateManifests()
				if err != nil {
					return err
				}
				return nil
			}
		case failure := <-fail:
			order.WriteLog(true, failure)
		case progress := <-progress:
			order.WriteLog(true, progress)
		}
	}
}

// Run the generate_manifests playbook to output Kubernetes configs
func (order *SoftwareOrder) GenerateManifests() error {

	// Write a vars file to disk so it can be used by the playbook
	containerVarSections := []string{}
	for _, container := range order.Containers {
		if container.Status == DoNotBuild {
			continue
		}

		// Ports section
		ports := "    ports:\n"
		for _, item := range container.Config.Ports {
			ports += "    - " + item + "\n"
		}

		// Environment section
		environment := "    environment:"
		if len(container.Config.Environment) > 0 {
			environment += "\n"
			for _, item := range container.Config.Environment {
				environment += "    - " + item + "\n"
			}
		} else {
			environment += " []\n"
		}

		// Secrets section
		secrets := "    secrets:"
		if len(container.Config.Secrets) > 0 {
			secrets += "\n"
			for _, item := range container.Config.Secrets {
				if strings.HasPrefix(strings.ToLower(secrets), "setinit_text_enc") {
					secrets += "    - " + item + string(order.License) + "\n"
				} else {
					secrets += "    - " + item + "\n"
				}
			}
		} else {
			secrets += " []\n"
		}

		// Volumes section
		volumes := "    volumes:"
		if len(container.Config.Volumes) > 0 {
			volumes += "\n"
			for _, item := range container.Config.Volumes {
				volumes += "    - " + item + "\n"
			}
		} else {
			volumes += " []\n"
		}

		// Resources section
		resources := ""
		if len(container.Config.Resources.Limits) > 0 && len(container.Config.Resources.Requests) > 0 {
			resources += "    resources:"
			if len(container.Config.Resources.Limits) > 0 {
				resources += "\n      limits:"
				for _, item := range container.Config.Resources.Limits {
					resources += "\n      - " + item
				}
			}
			if len(container.Config.Resources.Requests) > 0 {
				resources += "\n      requests:"
				for _, item := range container.Config.Resources.Requests {
					resources += "\n      - " + item
				}
			}
		}

		// Final formatting for container's section
		containerSection := "  " + container.Name + ":\n"
		containerSection += ports
		containerSection += environment
		containerSection += secrets
		containerSection += volumes
		containerSection += resources
		containerVarSections = append(containerVarSections, containerSection)
	}

	// Put together the final vars file
	// TODO: clean this up
	vars := fmt.Sprintf(`
PROJECT_NAME: %s
SECURE_CONSUL: false
TLS_ENABLED: false
SAS_K8S_NAMESPACE: sas-viya
SAS_K8S_INGRESS_DOMAIN: company.com
docker_tag: %s
SAS_MANIFEST_DIR: manifests/
DEPLOYMENT_LABEL: sas-viya
DISABLE_CONSUL_HTTP_PORT: false
orchestration_root: /ansible/roles/
METAREPO_CERT_DIR: /ansible
SAS_CONFIG_ROOT: /opt/sas/viya/home/
`,
		order.ProjectName, order.TagOverride)

	// Write a temp file
	varsDeploymentFilePath := order.BuildPath + "vars_deployment.yml"
	err := ioutil.WriteFile(varsDeploymentFilePath, []byte(vars), 0644)
	if err != nil {
		return err
	}

	serviceSettings := fmt.Sprintf(`
settings:
  base: %s
  project_name: %s
  k8s_namespace:
    name: %s
`,
		order.BaseImage,
		order.ProjectName,
		order.DockerNamespace)

	serviceSettings += "services:\n"
	for _, section := range containerVarSections {
		serviceSettings += section + "\n"
	}
	registries := fmt.Sprintf("registries: \n  docker-registry:\n    url: %s \n    namespace: %s",
		order.DockerRegistry, order.DockerNamespace)
	serviceSettings += registries

	// Write a temp file
	serviceSettingsFilePath := order.BuildPath + "manifest-vars.yml"
	err = ioutil.WriteFile(serviceSettingsFilePath, []byte(serviceSettings), 0644)
	if err != nil {
		return err
	}

	// TODO: clean this up
	playbook := `
# Manifests can be re-generated without re-building:
# 1. Edit values in the 'vars_usermods.yml' file.
# 2. Run 'ansible-playbook generate_manifests.yml'.
# 3. Navigate to '{{ SAS_MANIFEST_DIR }}/kubernetes/' to find the new deployment files.
#
# DO NOT EDIT - This playbook is generated by order.go
---
- name: Generate manifests on the build machine
  hosts: 127.0.0.1
  connection: local

  vars:
    SAS_MANIFEST_DIR: manifests
    SAS_K8S_NAMESPACE: sas-viya
    SAS_K8S_INGRESS_DOMAIN: company.com

  vars_files:
  - vars_deployment.yml
  - vars_usermods.yml
  - manifest-vars.yml

  roles:
  - ../../util/static-roles-%s/manifests
...
`
	err = ioutil.WriteFile(order.BuildPath+"generate_manifests.yml",
		[]byte(fmt.Sprintf(playbook, order.DeploymentType)), 0755)
	if err != nil {
		return err
	}

	// If the user provided a sitedefault.yml file copy it over or copy the default version
	if _, err := os.Stat("sitedefault.yml"); !os.IsNotExist(err) {
		input, err := ioutil.ReadFile("sitedefault.yml")
		if err != nil {
			return err
		}

		err = ioutil.WriteFile(order.BuildPath+"sitedefault.yml", input, 0644)
		if err != nil {
			return err
		}
	}

	varsDestPath := fmt.Sprintf("%s/vars_usermods.yml", order.BuildPath)
	// If the user provided a vars_usremods.yml file copy it over or copy the default version
	if _, err := os.Stat("vars_usermods.yml"); os.IsNotExist(err) {
		input, err := ioutil.ReadFile("util/vars_usermods.yml")
		if err != nil {
			return err
		}
		err = ioutil.WriteFile(varsDestPath, input, 0644)
		if err != nil {
			fmt.Println("Error creating", varsDestPath)
			return err
		}
	} else {
		input, err := ioutil.ReadFile("vars_usermods.yml")
		if err != nil {
			return err
		}
		err = ioutil.WriteFile(varsDestPath, input, 0644)
		if err != nil {
			fmt.Println("Error creating", varsDestPath)
			return err
		}
	}

	// Run the playbook locally to generate the Kubernetes manifests
	manifestsCommand := fmt.Sprintf("ansible-playbook --connection=local --inventory 127.0.0.1, %sgenerate_manifests.yml -vv", order.BuildPath)
	result, err := exec.Command("sh", "-c", manifestsCommand).Output()
	if err != nil {
		result := string(result) + "\n" + err.Error() + "\n"
		result += "Generate Manifests playbook failed.\n"
		result += fmt.Sprintf("To debug use `cd %s ; ansible-playbook generate_manifests.yml`\n", order.BuildPath)
		return errors.New(result)
	}
	return nil
}

// Download the orchestration tool locally if it is not in the util directory
func getOrchestrationTool() error {
	_, err := os.Stat("util/sas-orchestration")
	if !os.IsNotExist(err) {
		return nil
	}

	// HTTP GET the file
	fileURL := fmt.Sprintf("https://support.sas.com/installation/viya/%s/sas-orchestration-cli/lax/sas-orchestration-linux.tgz",
		SAS_VIYA_VERSION)
	resp, err := http.Get(fileURL)
	if err != nil {
		return errors.New("Cannot fetch sas-orchestration tool. support.sas.com must be accessible, " + err.Error())
	}
	defer resp.Body.Close()

	// Write the HTTP GET result to a file
	out, err := os.Create("util/sas-orchestration.tgz")
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, resp.Body)
	if err != nil {
		return err
	}

	// Untar the result and move it into the util directory
	untarCommand := "tar -xf util/sas-orchestration.tgz -C util/"
	_, err = exec.Command("sh", "-c", untarCommand).Output()
	if err != nil {
		return errors.New("Cannot untar sas-orchestration tool. " + err.Error())
	}

	// Clean up
	os.Remove("util/sas-orchestration.tgz")
	return nil
}

// Remove all temporary build files: sas_viya_playbook and all Docker contexts (tar files) in the /tmp directory
func (order *SoftwareOrder) Finish() {
	order.EndTime = time.Now()
	// TODO
	//for _, container := range order.Containers {
	//	container.Finish()
	//}
}

// Helper function to convert an image size to a human readable value
func bytesToGB(bytes int64) string {
	return fmt.Sprintf("%.2f GB", float64(bytes)/float64(1000000000))
}

// Calculate all metrics and display them in a table.
func (order *SoftwareOrder) ShowBuildSummary() {

	// Special case where the single deployment does not use the order.Containers list
	if order.DeploymentType == "single" {
		order.EndTime = time.Now()
		fmt.Println(fmt.Sprintf("\nTotal Elapsed Time: %s\n\n", order.EndTime.Sub(order.StartTime).Round(time.Second)))
		return
	}

	// Print each container's metrics in a table
	summaryHeader := fmt.Sprintf("\n%s  Summary  ( %s, %s ) %s", strings.Repeat("-", 23),
		order.EndTime.Sub(order.StartTime).Round(time.Second),
		bytesToGB(order.TotalBuildSize),
		strings.Repeat("-", 23))
	fmt.Println(summaryHeader)
	order.WriteLog(false, summaryHeader)
	for _, container := range order.Containers {
		if container.Status == Pushed {
			output := fmt.Sprintf("%s\n\tSize: %s\tBuild Time: %s\tPush Time: %s",
				container.GetWholeImageName(),
				bytesToGB(container.ImageSize),
				container.BuildEnd.Sub(container.BuildStart).Round(time.Second),
				container.PushEnd.Sub(container.PushStart).Round(time.Second))
			fmt.Println(output)
			order.WriteLog(false, output)
		}
	}
	lineSeparator := strings.Repeat("-", 79)
	fmt.Println(lineSeparator)
	order.WriteLog(false, lineSeparator)

	// TODO: Make the list of directories reflective of the manifests generated.
	//       In a TLS build there will be an account type. Also, the "manifests"
	//       directory and Kubernetes namespaces are changeable. Should probably
	//       have a way to discover this information so it is reflects in the data
	//       given to the user.
	symlinkBuildPath := fmt.Sprintf("builds/%s/manifests", order.DeploymentType)
	manifestInstructions := fmt.Sprintf(`
Kubernetes manifests have been created: %s

To deploy a new environment run the below commands

Create the Kuberenetes namespace:

kubectl apply -f %s/kubernetes/namespace/

Then create the following Kubernetes objects:

kubectl -n sas-viya apply -f %s/kubernetes/ingress && \
kubectl -n sas-viya apply -f %s/kubernetes/configmaps && \
kubectl -n sas-viya apply -f %s/kubernetes/secrets && \
kubectl -n sas-viya apply -f %s/kubernetes/services && \
kubectl -n sas-viya apply -f %s/kubernetes/deployments
`,
		order.BuildPath+"manifests/",
		symlinkBuildPath,
		symlinkBuildPath,
		symlinkBuildPath,
		symlinkBuildPath,
		symlinkBuildPath,
		symlinkBuildPath)

	fmt.Println(manifestInstructions)
	order.WriteLog(false, manifestInstructions)
}
