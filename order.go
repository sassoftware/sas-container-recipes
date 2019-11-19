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
	"encoding/base64"

	"github.com/docker/docker/api/types"
	"github.com/docker/docker/api/types/filters"
	"github.com/docker/docker/client"

	"archive/zip"
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"gopkg.in/yaml.v2"
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

// RecipeVersion format <year>.<month>.<numbered release>
const RecipeVersion = "19.06.3"

// SasViyaVersion is used to wget the corresponding sas-orchestration tool version
// example: 34 = version 3.4
const SasViyaVersion = "34"

// ConfigPath is the path to the configuration file that's used to load custom container attributes
// NOTE: this path changes to config-<deployment-type>.yml
var ConfigPath = "config-full.yml"

// SoftwareOrder is the structure to hold the order information.
type SoftwareOrder struct {

	// Build arguments and flags (see order.LoadCommands for details)
	BaseImage              string   `yaml:"Base Image              "`
	MirrorURL              string   `yaml:"Mirror URL              "`
	VirtualHost            string   `yaml:"Virtual Host            "`
	DockerNamespace        string   `yaml:"Docker Namespace        "`
	DockerRegistry         string   `yaml:"Docker Registry         "`
	DeploymentType         string   `yaml:"Deployment Type         "`
	Platform               string   `yaml:"Platform                "`
	ProjectName            string   `yaml:"Project Name            "`
	TagOverride            string   `yaml:"Tag Override            "`
	AddOns                 []string `yaml:"AddOns                  "`
	DebugContainers        []string `yaml:"Debug Containers        "`
	WorkerCount            int      `yaml:"Worker Count            "`
	Verbose                bool     `yaml:"Verbose                 "`
	SkipMirrorValidation   bool     `yaml:"Skip Mirror Validation  "`
	SkipDockerValidation   bool     `yaml:"Skip Docker Validation  "`
	GenerateManifestsOnly  bool     `yaml:"Generate Manifests Only "`
	SkipDockerRegistryPush bool     `yaml:"Skip Docker Registry    "`

	// Build attributes
	Log          *os.File              `yaml:"-"`                        // File handle for log path
	BuildContext context.Context       `yaml:"-"`                        // Background context
	BuildOnly    []string              `yaml:"Build Only              "` // Only build these specific containers if they're in the list of entitled containers. The 'multiple' deployment type utilizes this to build only 3 images.
	Containers   map[string]*Container `yaml:"-"`                        // Individual containers build list
	Config       map[string]ConfigMap  `yaml:"-"`                        // Static values and defaults are loaded from the configmap yaml
	ConfigPath   string                `yaml:"-"`                        // config-<deployment-type>.yml file for custom or static values
	LogPath      string                `yaml:"-"`                        // Path to the build directory with the log file name
	PlaybookPath string                `yaml:"-"`                        // Build path + "sas_viya_playbook"
	KVStore      string                `yaml:"-"`                        // Combines all vars.yaml content
	RegistryAuth string                `yaml:"-"`                        // Used to push and pull from/to a regitry
	BuildPath    string                `yaml:"-"`                        // Kubernetes manifests are generated and placed into this location
	CertBaseURL  string                `yaml:"-"`                        // The URL that the build containers will use to fetch their CA and entitlement certs
	BuilderIP    string                `yaml:"-"`                        // IP of where images are being built to be used for generic hostname lookup for builder
	BuilderPort  string                `yaml:"-"`                        // Port for serving certificate requests for builds
	TimestampTag string                `yaml:"Timestamp Tag           "` // Allows for datetime on each temp build bfile
	InDocker     bool                  `yaml:"-"`                        // If we are running in a docker container
	ManifestDir  string                `yaml:"-"`                        // The name of the manifest directory. "manifests" is the default

	// Metrics
	StartTime      time.Time      `yaml:"-"`
	EndTime        time.Time      `yaml:"-"`
	TotalBuildSize int64          `yaml:"-"`
	DockerClient   *client.Client `yaml:"-"` // Used to pull the base image and output post-build details

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
	SOEZipPath string `yaml:"-"` // Used to load licenses
	OrderOOM   struct {
		OomFormatVersion string `json:"oomFormatVersion"`
		MetaRepo         struct {
			URL        string   `json:"url"`
			Rpm        string   `json:"rpm"`
			Orderables []string `json:"orderables"`
		} `json:"metaRepo"`
	} `yaml:"-"`
	CA             []byte `yaml:"-"`
	Entitlement    []byte `yaml:"-"`
	License        []byte `yaml:"-"`
	MeteredLicense []byte `yaml:"-"`

	SiteDefault []byte `yaml:"-"`
}

// Registry is ror reading ~/.docker/config.json
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

// ConfigMap each container has a configmap which define Docker layers.
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

// SetupBuildDirectory creates a unique isolated directory for the Software Order
// based on the deployment and time stamp. It also configures logging.
func (order *SoftwareOrder) SetupBuildDirectory() error {
	// Create an isolated build directory with a unique timestamp
	order.BuildPath = fmt.Sprintf("builds/%s-%s/", order.DeploymentType, order.TimestampTag)
	if err := os.MkdirAll(order.BuildPath, 0744); err != nil {
		return err
	}

	// Start a new build log inside the isolated build directory
	order.LogPath = order.BuildPath + "/build.log"
	logHandle, err := os.Create(order.LogPath)
	if err != nil {
		return err
	}
	order.Log = logHandle

	// Symbolically link the most recent time stamped build directory to a shorter name
	// For example, 'full-2019-04-09-13-37-40' can be referred to as simply 'full'
	// Note: This is executing inside the build container, inside a mounted volume,
	// 		 therefore an os.Symlink() does not work correctly.
	previousLink := "builds/" + order.DeploymentType
	if _, err := os.Lstat(previousLink); err == nil {
		if err := os.Remove(previousLink); err != nil {
			return err
		}
	}
	symlinkCommand := fmt.Sprintf("cd builds && ln -s %s-%s %s && cd ..",
		order.DeploymentType, order.TimestampTag, order.DeploymentType)
	cmd := exec.Command("sh", "-c", symlinkCommand)
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	err = cmd.Start()
	if err != nil {
		result, _ := ioutil.ReadAll(stderr)
		return errors.New(string(result) + "\n" + err.Error())
	}
	err = cmd.Wait()
	if err != nil {
		result, _ := ioutil.ReadAll(stderr)
		return errors.New(string(result) + "\n" + err.Error())
	}
	// A single image only uses the vars_usermods.yml. That can be used to change the
	// running of the playbook that is used in creating the image. For "full" or
	// "multiple" deployments, only the manifests_usermods.yml is used. It is used
	// when generating manifests and not in the building of the images.
	if order.DeploymentType != "single" {
		if err = order.LoadUsermods("manifests_usermods.yml"); err != nil {
			return err
		}
	} else {
		if err = order.LoadUsermods("vars_usermods.yml"); err != nil {
			return err
		}
	}
	return nil
}

// NewSoftwareOrder once the SOE zip file path has been provided then load all the Software Order's details
// Note: All sub-processes of this function are essential to the build process.
//       If any of these steps return an error then the entire process will be exited.
func NewSoftwareOrder() (*SoftwareOrder, error) {
	order := &SoftwareOrder{}
	order.StartTime = time.Now()
	order.TimestampTag = string(order.StartTime.Format("2006-01-02-15-04-05"))
	if len(order.TagOverride) > 0 {
		order.TimestampTag = order.TagOverride
	}
	if err := order.LoadCommands(); err != nil {
		return order, err
	}

	if err := order.DefineManifestDir(); err != nil {
		return order, err
	}

	// Do not load any more Software Order values, just allow order.GenerateManifests() to be called
	if order.GenerateManifestsOnly {
		return order, nil
	}

	order.WriteLog(true, order.BuildArgumentsSummary())

	// Configure a new isolated build space
	if err := order.SetupBuildDirectory(); err != nil {
		return order, err
	}

	// Determine if the binary is being run inside the sas-container-recipes-builder
	order.InDocker = true
	if _, err := os.Stat("/.dockerenv"); err != nil {
		order.InDocker = false
	}

	// Point to custom configuration yaml files
	order.ConfigPath = "config-full.yml"
	if order.DeploymentType == "multiple" {
		order.ConfigPath = "config-multiple.yml"
	}

	// Start a worker pool and wait for all workers to finish
	workerCount := 0 // Number of goroutines started
	done := make(chan int)
	fail := make(chan string)
	progress := make(chan string)

	// In a single deployment, we do not need to generate the playbook as the playbook
	// is generated by the running of the Dockerfile. The sitedefault.yml also is not
	// used as that is for Consul which is only in a full deployment.
	if order.DeploymentType == "full" {
		workerCount++
		go order.LoadSiteDefault(progress, fail, done)
	}

	if order.DeploymentType != "single" {
		workerCount++
		go order.LoadPlaybook(progress, fail, done)
	}

	// When doing a single-container, the LoadLicense is still needed.
	// Removing it will cause a build failure around a missing host.
	workerCount++
	go order.LoadLicense(progress, fail, done)

	workerCount++
	go order.LoadDocker(progress, fail, done)

	if !order.SkipDockerRegistryPush {
		workerCount++
		go order.LoadRegistryAuth(fail, done)
	} else {
		log.Println("Skipping loading Docker registry authentication ...")
	}

	if !order.SkipDockerValidation {
		workerCount++
		go order.TestRegistry(progress, fail, done)
	} else {
		log.Println("Skipping validating Docker registry ...")
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

// BuildArgumentsSummary gets a human readable version of the command arguments
// that were supplied to the SoftwareOrder object. This is useful for debugging.
func (order *SoftwareOrder) BuildArgumentsSummary() string {
	objectAttributes, _ := yaml.Marshal(order)
	output := "\n" + strings.Repeat("=", 50) + "\n"
	output += "\t\tBuild Variables\n"
	output += strings.Repeat("=", 50) + "\n"
	output += string(objectAttributes)
	output += strings.Repeat("=", 50) + "\n"
	return output
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

	builderIP, err := getIPAddr()
	if err != nil {
		panic("Could not determine hostname or host IP: " + err.Error())
	}
	order.BuilderIP = builderIP

	listener, err := net.Listen("tcp", ":"+order.BuilderPort)
	if err != nil {
		panic(err)
	}

	// Serve only two endpoints to receive the entitlement and CA
	order.WriteLog(true, fmt.Sprintf("Serving license and entitlement on sas-container-recipes-builder:%s (%s)", order.BuilderPort, order.BuilderIP))
	order.CertBaseURL = fmt.Sprintf("http://sas-container-recipes-builder:%s", order.BuilderPort)

	http.HandleFunc("/entitlement/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, string(order.Entitlement))
	})
	http.HandleFunc("/cacert/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, string(order.CA))
	})
	http.Serve(listener, nil)
}

// WriteLog is multiplexer for writing logs.
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

// GetIntermediateStatus returns the output of how many and which containers have been built
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

// DefineManifestDir looks at the manifests_usermods.yml to see what the manifest dir is.
// If nothing is defined, then "manifests" is used
func (order *SoftwareOrder) DefineManifestDir() error {
	manifestdirGrepCommand := fmt.Sprintf("grep '^SAS_MANIFEST_DIR' %smanifests_usermods.yml | awk -F ': ' '{ print $2 }'", order.BuildPath)
	grepResult, err := exec.Command("sh", "-c", manifestdirGrepCommand).Output()
	if err != nil {
		return err
	}
	order.ManifestDir = strings.TrimSuffix(string(grepResult), "\n")
	if len(order.ManifestDir) == 0 {
		order.ManifestDir = "manifests"
	}
	return nil
}

// LoadCommands receives flags and arguments, parse them, and load them into the order
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
	mirrorURL := flag.String("mirror-url", "https://ses.sas.download/ses/", "")
	verbose := flag.Bool("verbose", false, "")
	buildOnly := flag.String("build-only", "", "")
	tagOverride := flag.String("tag", RecipeVersion+"-"+order.TimestampTag, "")
	projectName := flag.String("project-name", "sas-viya", "")
	deploymentType := flag.String("type", "single", "")
	version := flag.Bool("version", false, "")
	skipDockerValidation := flag.Bool("skip-docker-url-validation", false, "")
	generateManifestsOnly := flag.Bool("generate-manifests-only", false, "")
	builderPort := flag.String("builder-port", "1976", "")
	skipDockerRegistryPush := flag.Bool("skip-docker-registry-push", false, "")

	// By default detect the cpu core count and utilize all of them
	defaultWorkerCount := runtime.NumCPU()
	workerCount := flag.Int("workers", defaultWorkerCount, "")

	// Allow for quick exit if only viewing the --version or --help
	flag.Usage = func() {
		usageDocPath := "docs/usage.txt"
		usage, err := ioutil.ReadFile(usageDocPath)
		if err != nil {
			fmt.Println("Unable to find usage file " + usageDocPath)
		} else {
			fmt.Println(string(usage))
		}
		os.Exit(0)
	}
	flag.Parse()
	if *version == true {
		fmt.Println("SAS Container Recipes v" + RecipeVersion)
		os.Exit(0)
	}
	if len(os.Args) == 1 {
		flag.Usage()
	}

	order.Verbose = *verbose
	order.SkipDockerValidation = *skipDockerValidation
	order.GenerateManifestsOnly = *generateManifestsOnly
	order.VirtualHost = *virtualHost
	order.DockerRegistry = *dockerRegistry
	order.BuilderPort = *builderPort
	order.SkipDockerRegistryPush = *skipDockerRegistryPush

	// Disallow all other flags except --type with --generate-manifests-only
	// Note: --tag is always passed from build.sh, so will have to ignore that
	if *generateManifestsOnly {
		if flag.NFlag() > 3 {
			err := errors.New("Only '--type(-y)' can be used with '--generate-manifests-only'.")
			return err
		}
		if *deploymentType == "single" {
			err := errors.New("Use of '--type(-y) <multiple|full>' is required with '--generate-manifests-only'.")
			return err
		}
	}

	// Make sure one cannot specify more workers than # cores available
	order.WorkerCount = *workerCount
	if *workerCount == 0 || *workerCount > defaultWorkerCount {
		err := errors.New("invalid '--worker' count, must be less than or equal to the number of CPU cores that are free and permissible in your cgroup configuration")
		return err
	}

	// This is a safeguard for when a user does not use quotes around a multi value argument
	otherArgs := flag.Args()
	if len(otherArgs) > 0 {
		progressString := "WARNING: one or more arguments were not parsed. Quotes are required for multi-value arguments."
		order.WriteLog(true, progressString)
	}

	// Always require a deployment type
	if *deploymentType != "multiple" && *deploymentType != "full" && *deploymentType != "single" {
		err := errors.New("a valid '--type' is required: choose between single, multiple, or full")
		return err
	}
	order.DeploymentType = strings.ToLower(*deploymentType)

	// Always require a license except to re-generate manifests
	if *license == "" && !order.GenerateManifestsOnly {
		err := errors.New("a software order email (SOE) '--license' file is required")
		return err
	}
	order.SOEZipPath = *license
	if !strings.HasSuffix(order.SOEZipPath, ".zip") && !order.GenerateManifestsOnly {
		return errors.New("the Software Order Email (SOE) argument '--zip' must be a file with the '.zip' extension")
	}

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
	}

	// Detect the platform based on the image
	order.BaseImage = *baseImage
	if strings.Contains(order.BaseImage, "suse") {
		order.Platform = "suse"
	} else {
		// By default use rpm + yum
		order.Platform = "redhat"
	}

	// A mirror is optional, except in the case of using an opensuse base image for single container
	order.MirrorURL = *mirrorURL
	if len(order.MirrorURL) == 0 && order.DeploymentType == "single" && order.Platform == "suse" {
		return errors.New("a --mirror-url argument is required for a base suse single container")
	}
	if strings.Contains(order.MirrorURL, "http://") {
		fmt.Println(fmt.Sprintf(
			"WARNING: the --mirror-url argument '%s' does not have TLS.", order.MirrorURL))
	}

	// Optional: override the standard tag format
	order.TagOverride = *tagOverride
	if len(order.TagOverride) > 0 && !regexNoSpecialCharacters.Match([]byte(order.TagOverride)) {
		return errors.New("The --tag argument contains invalid characters. It must contain contain only A-Z, a-z, 0-9, _, ., or -")
	}

	// Optional: override the "sas-viya-" prefix in image names and in the deployment
	order.ProjectName = *projectName
	if len(order.ProjectName) > 0 && !regexNoSpecialCharacters.Match([]byte(order.ProjectName)) {
		return errors.New("The --project-name argument contains invalid characters. It must contain contain only A-Z, a-z, 0-9, _, ., or -")
	}

	// Require a docker namespace for multi and full if the manifests are not being re-generated
	if *dockerNamespace == "" && (order.DeploymentType == "multiple" || order.DeploymentType == "full") && !order.GenerateManifestsOnly {
		return errors.New("a '--docker-namespace' argument is required")
	}
	order.DockerNamespace = *dockerNamespace
	if !regexNoSpecialCharacters.Match([]byte(order.DockerNamespace)) && !order.GenerateManifestsOnly {
		return errors.New("The --docker-namespace argument contains invalid characters. It must contain contain only A-Z, a-z, 0-9, _, ., or -")
	}

	// Require a docker registry for multi and full
	if *dockerRegistry == "" && !order.GenerateManifestsOnly &&
		(order.DeploymentType == "multiple" || order.DeploymentType == "full") {
		return errors.New("a '--docker-registry-url' argument is required")
	}

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
	}
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

		if !container.SoftwareOrder.SkipDockerRegistryPush {
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
		} else {
			progress <- "Skipping pushing " + container.GetWholeImageName() + " to Docker registry"
		}

		done <- container.Name
	}
}

// The single container deployment type has a unique
// Grab the Dockerfile stub from the utils directory and append any addons
// then do a docker build with the base image and platform build arguments
// TODO: using license in RUN layers and mounting as volume?
func getProgrammingOnlySingleContainer(order *SoftwareOrder) error {
	// In the case of the sinlge container, we will define the memory for the
	// order.Containers object. For non-single builds, this is done in the
	// getContainers method. That method is not called in a single image build
	// so we need to do the following.
	order.Containers = make(map[string]*Container)
	container := Container{
		Name:          "single-programming-only",
		SoftwareOrder: order,
		BaseImage:     order.BaseImage,
	}

	dockerConnection, err := client.NewClientWithOpts(client.WithVersion(DockerAPIVersion))
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
	err = container.AddFileToContext(resourceDirectory+"/entrypoint", "entrypoint", []byte{})
	if err != nil {
		return err
	}
	err = container.AddFileToContext(resourceDirectory+"/replace_httpd_default_cert.sh", "replace_httpd_default_cert.sh", []byte{})
	if err != nil {
		return err
	}
	err = container.AddFileToContext(resourceDirectory+"/sas-orchestration", "sas-orchestration", []byte{})
	if err != nil {
		return err
	}

	err = container.AddFileToContext(order.BuildPath+"/vars_usermods.yml", "vars_usermods.yml", []byte{})
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
	dockerfile, err := appendAddonLines(container.GetName(), string(dockerfileStub), container.SoftwareOrder.DeploymentType, container.SoftwareOrder.AddOns)
	if err != nil {
		return err
	}
	err = container.AddFileToContext("", "Dockerfile", []byte(dockerfile))
	if err != nil {
		return err
	}

	// Make the software order only build the image that was created in this function
	for _, item := range order.Containers {
		item.Status = DoNotBuild
	}
	container.Status = Loaded
	order.Containers[container.Name] = &container
	return nil
}

// Build starts each container build concurrently and report the results
func (order *SoftwareOrder) Build() error {
	// Handle single container build and output of docker run instructions
	if order.DeploymentType == "single" {
		err := getProgrammingOnlySingleContainer(order)
		if err != nil {
			return err
		}
	}
	numberOfBuilds := 0
	for _, container := range order.Containers {
		if container.Status == Loaded {
			numberOfBuilds++
		}
	}
	fmt.Println("")
	if numberOfBuilds == 0 {
		return errors.New("The number of builds are set to zero. " +
			"An error in pre-build tasks may have occurred or the " +
			"Software Order entitlement does not match the deployment type.")
	} else if numberOfBuilds == 1 {
		// Use the singular "process" instead of "processes"
		order.WriteLog(true, "Starting "+strconv.Itoa(numberOfBuilds)+" build process ... (this may take several minutes)")
	} else {
		// Use the plural "processes" instead of "process"
		order.WriteLog(true, "Starting "+strconv.Itoa(numberOfBuilds)+" build processes ... (this may take several minutes)")
	}
	order.WriteLog(true, "[TIP] System resource utilization can be seen by using the `docker stats` command.")

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
			return errors.New(failure)
		case progress := <-progress:
			order.WriteLog(true, progress)
		}
	}
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

// LoadLicense once the path to the Software Order Email (SOE) zip file has been provided then unzip it
// and load the content into the SoftwareOrder struct for use in the build process.
func (order *SoftwareOrder) LoadLicense(progress chan string, fail chan string, done chan int) {
	progress <- "Reading Software Order Email Zip ..."

	if _, err := os.Stat(order.SOEZipPath); os.IsNotExist(err) {
		fail <- err.Error()
		return
	}

	zipped, err := zip.OpenReader(order.SOEZipPath)
	if err != nil {
		fail <- "Could not read the file specified by the `--zip` argument. This must be a valid Software Order Email (SOE) zip file.\n" + err.Error()
		return
	}
	defer zipped.Close()

	// Iterate through the files in the archive and print content for each
	for _, zippedFile := range zipped.File {

		// Read the string content and see what file it is, then load it into the order
		readCloser, err := zippedFile.Open()
		if err != nil {
			fail <- err.Error()
			return
		}
		buffer := new(bytes.Buffer)
		_, err = io.Copy(buffer, readCloser)
		if err != nil {
			fail <- err.Error()
			return
		}
		fileBytes, err := ioutil.ReadAll(buffer)
		if err != nil {
			fail <- err.Error()
			return
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
				return
			}
		}
	}

	// Make sure all required files were loaded into the order
	if len(order.License) == 0 || len(order.MeteredLicense) == 0 || len(order.CA) == 0 || len(order.Entitlement) == 0 {
		fail <- "Unable to parse all content from SOE zip"
		return
	}

	go order.Serve()

	progress <- "Finished reading Software Order Email"
	done <- 1
}

// LoadDocker ensures the Docker client is accessible and pull the specified base image from Docker Hub
func (order *SoftwareOrder) LoadDocker(progress chan string, fail chan string, done chan int) {

	// Make sure Docker is able to connect
	progress <- "Connecting to the Docker daemon  ..."
	dockerConnection, err := client.NewClientWithOpts(client.WithVersion("1.37"))
	if err != nil {
		fail <- "Unable to connect to Docker daemon. Ensure Docker is installed and the service is started."
		return
	}
	order.DockerClient = dockerConnection
	progress <- "Finished connecting to Docker daemon"

	// Pull the base image depending on what the argument was
	progress <- "Pulling base container image '" + order.BaseImage + "'" + " ..."
	order.BuildContext = context.Background()
	_, err = order.DockerClient.ImagePull(order.BuildContext, order.BaseImage, types.ImagePullOptions{})
	if err != nil {
		fail <- err.Error()
		return
	}

	progress <- "Finished pulling base container image '" + order.BaseImage + "'"
	done <- 1
}

// LoadSiteDefault will load the user provided sitedefault.yml file if available.
func (order *SoftwareOrder) LoadSiteDefault(progress chan string, fail chan string, done chan int) {
	progress <- "Reading sitedefault.yml ..."

	// If the user provided a sitedefault.yml file copy it over or copy the default version
	if _, err := os.Stat("sitedefault.yml"); !os.IsNotExist(err) {
		order.SiteDefault, err = ioutil.ReadFile("sitedefault.yml")
		if err != nil {
			fail <- "Unable to open sitedefault.yml:" + err.Error()
			return
		}
		progress <- "Finished loading sitedefault.yml"
	} else {
		progress <- "Skipping loading sitedefault.yml"
	}
	done <- 1
}

// TestRegistry runs a simple curl on the registry to see if it's accessible.
// This is a preliminary check so an error is less likely to occur after the build, once the built images are being pushed
func (order *SoftwareOrder) TestRegistry(progress chan string, fail chan string, done chan int) {
	if order.DeploymentType == "single" {
		// Single container deployment does not use a registry so skip this
		done <- 1
		return
	}
	if strings.Contains(order.DockerRegistry, "http://") {
		fail <- "The --docker-registry-url must have TLS enabled. Provide the url with 'https' instead of 'http' in the command argument."
		return
	}
	url := order.DockerRegistry
	if !strings.Contains(order.DockerRegistry, "https://") {
		url = "https://" + order.DockerRegistry
	}
	progress <- "Checking the Docker registry URL for validity ... curl " + url
	response, err := http.Get(url)
	if err != nil {
		fail <- err.Error()
		return
	}
	defer response.Body.Close()
	if response.StatusCode != 200 {
		fail <- "The URL cannot contain 'http' or 'https'. Also the registry also be configured for https. " +
			"Invalid Docker registry URL  " + err.Error()
		return
	}
	progress <- "Finished checking the Docker registry URL for validity: http status code " + strconv.Itoa(response.StatusCode)

	done <- 1
}

// LoadRegistryAuth loads the registry auth from $USERHOME/.docker/config.json
func (order *SoftwareOrder) LoadRegistryAuth(fail chan string, done chan int) {
	// Skip this if no registry and namespace was specified
	if len(order.DockerRegistry) == 0 || len(order.DockerNamespace) == 0 {
		done <- 1
		return
	}

	userObject, err := user.Current()
	if err != nil {
		fail <- "Cannot get user home directory path for docker config. " + err.Error()
		return
	}
	dockerConfigPath := fmt.Sprintf("%s/.docker/config.json", userObject.HomeDir)
	order.WriteLog(true, "Reading config from "+dockerConfigPath)
	configError := "Cannot read Docker configuration or file read permission is not permitted for the ~/.docker/config.json file. Run a `docker login <registry>`.\n"
	configStat, err := os.Stat(dockerConfigPath)
	if err != nil {
		fail <- err.Error()
		return
	}
	if configStat.IsDir() {
		fail <- configError
		return
	}
	configContent, err := ioutil.ReadFile(dockerConfigPath)
	if err != nil {
		fail <- configError
		return
	}
	config := string(configContent)
	if !strings.Contains(config, order.DockerRegistry) {
		fail <- "Cannot find the --docker-registry-url in the Docker config. Run `docker login <registry>` before building."
		return
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
	authInfoBytes, _ := base64.StdEncoding.DecodeString(config)
	authInfo := strings.Split(string(authInfoBytes), ":")
	auth := struct {
		Username string
		Password string
	}{
		Username: authInfo[0],
		Password: authInfo[1],
	}

	authBytes, _ := json.Marshal(auth)

	order.RegistryAuth = base64.StdEncoding.EncodeToString(authBytes)

	done <- 1
}

// LoadPlaybook uses the orchestration tool to generate an Ansible playbook from the Software Order Email Zip
func (order *SoftwareOrder) LoadPlaybook(progress chan string, fail chan string, done chan int) {

	// Check to see if the tool exists
	progress <- "Fetching orchestration tool ..."
	err := getOrchestrationTool()
	if err != nil {
		fail <- "Failed to install sas-orchestration tool. " + err.Error()
		return
	}
	progress <- "Finished fetching orchestration tool"

	// Run the orchestration tool to make the playbook
	progress <- "Generating playbook for order ..."
	commandBuilder := []string{"util/sas-orchestration build"}
	commandBuilder = append(commandBuilder, "--platform redhat")
	commandBuilder = append(commandBuilder, "--input "+order.SOEZipPath)
	commandBuilder = append(commandBuilder, "--output "+order.BuildPath+"sas_viya_playbook.tgz")
	commandBuilder = append(commandBuilder, "--repository-warehouse "+order.MirrorURL)
	if order.DeploymentType == "multiple" {
		commandBuilder = append(commandBuilder, "--deployment-type programming")
	}
	playbookCommand := strings.Join(commandBuilder, " ")
	order.WriteLog(false, playbookCommand)

	// The following is to fully provide the output of anything that goes wrong
	// when generating the playbook.
	cmd := exec.Command("sh", "-c", playbookCommand)
	cmdReader, err := cmd.StdoutPipe()
	if err != nil {
		fail <- "[ERROR] Could not create StdoutPipe for Cmd. " + err.Error() + "\n" + playbookCommand
		return
	}

	// This code will output the stdout of the playbook generation process
	// This was the only way I could get the information as to why the playbook
	// was failing to generate. It could be there is a better way to capture
	// the information, but I was not having success. It might have been do
	// to a Go casting issue.
	scanner := bufio.NewScanner(cmdReader)
	go func() {
		for scanner.Scan() {
			result := scanner.Text()
			progress <- fmt.Sprintf("Generate playbook output | %s", result)
			if strings.Contains(result, "Connection refused") || strings.Contains(result, "No route to host") {
				progress <- fmt.Sprintf("Error: unable to generate the playbook. The mirror URL provided by '--mirror-url %s' did not point to a host with an accessible mirrormgr repository. The IP address, hostname, or port might be incorrect.\n", order.MirrorURL)
			}
		}
	}()

	stderr, err := cmd.StderrPipe()
	if err != nil {
		return
	}

	err = cmd.Start()
	if err != nil {
		result, _ := ioutil.ReadAll(stderr)
		fail <- "[ERROR]: Unable to generate the playbook via cmd.Start. " + string(result) + "\n" + err.Error() + "\n" + playbookCommand
		return
	}

	err = cmd.Wait()
	if err != nil {
		result, _ := ioutil.ReadAll(stderr)
		fail <- fmt.Sprintf("Error: unable to generate the playbook during cmd.Wait. %s\n%s\n%s",
			string(result), err.Error(), playbookCommand)
		return
	}

	// Detect if Ansible is installed inside the build container.
	// This is required for the Generate Manifests function in multiple and
	// full deployment types, not in the single container.
	if order.DeploymentType != "single" {
		testAnsibleInstall := "ansible --version"
		_, err = exec.Command("sh", "-c", testAnsibleInstall).Output()
		if err != nil {
			fail <- "[ERROR]: The package `ansible` must be installed inside the build container in order to generate Kubernetes manifests."
			return
		}
	}

	// TODO replace with "golang.org/x/build/internal/untar"
	progress <- "Extracting generated playbook content ..."
	untarPlaybookCommand := fmt.Sprintf("tar --extract --file %ssas_viya_playbook.tgz -C %s", order.BuildPath, order.BuildPath)
	_, err = exec.Command("sh", "-c", untarPlaybookCommand).Output()
	if err != nil {
		fail <- "Unable to untar playbook. " + err.Error()
		return
	}
	order.PlaybookPath = order.BuildPath + "sas_viya_playbook"
	err = os.Remove(order.BuildPath + "sas_viya_playbook.tgz")
	if err != nil {
		fail <- "Unable to untar playbook. " + err.Error()
		return
	}
	progress <- "Finished extracting and generating playbook for order"

	// Work-around for the 19w34 update to sas-orchestration which changes
	// dashes in some container names to underscores.
	// Convert the inventory ini so that any underscores are converted to back into dashes.
	underbarConversionCommand := fmt.Sprintf("for sashost in $(grep '^sas_.*$' %[1]v/inventory.ini); do echo $sashost; dashstring=$(echo $sashost | sed 's/_/-/g'); echo $dashstring; sed -i \"s/${sashost}/${dashstring}/g\" %[1]v/inventory.ini; cp %[1]v/group_vars/${sashost} %[1]v/group_vars/${dashstring}; done; cp %[1]v/group_vars/sas_all %[1]v/group_vars/sas-all; sed -i 's/sas_all/sas-all/g' %[1]v/inventory.ini;",
		order.PlaybookPath)
	order.WriteLog(false, false, underbarConversionCommand)
	result, err := exec.Command("sh", "-c", underbarConversionCommand).Output()
	if err != nil {
		fail <- fmt.Sprintf("Unable to change inventory group_vars files. \n\n%s\n\n Returned error: %s\n%s",
			underbarConversionCommand, result, err.Error())
		return
	}

	// Get a list of the containers to be built
	progress <- "Fetching the list of containers in the order ..."
	order.Containers, err = getContainers(order)
	if err != nil {
		fail <- err.Error()
		return
	}
	progress <- "Finished fetching the container list"

	// Handle --build-only options without modifying the order's container attributes
	if len(order.BuildOnly) > 0 {

		// If the image is not in the --build-only list then set its status to Do Not Build
		imageNameMatches := []string{} // Image names that are provided in the --build-only argument and exist in the software order
		imageNameOptions := []string{} // Image names that are in the software order
		for index, container := range order.Containers {
			matchFound := false
			imageNameOptions = append(imageNameOptions, container.Name)
			for _, targetName := range order.BuildOnly {
				if container.Name == targetName {
					// Container's name is in the --build-only list
					matchFound = true
					imageNameMatches = append(imageNameMatches, container.Name)
				}
			}
			if !matchFound {
				order.Containers[index].Status = DoNotBuild
			}
		}

		// Make sure there is at least 1 image that's going to be built
		if len(order.BuildOnly) != len(imageNameMatches) {
			order.WriteLog(true, fmt.Sprintf("\nSelected Image Builds: %s\nAvailable Image Builds: %s\n", order.BuildOnly, imageNameOptions))
			fail <- "One or more of the chosen --build-only containers do not exist. "
			return
		}
	}

	done <- 1
}

// Prepare concurrently loads all container's configurations if the container is staged to be built
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
			workerCount++
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
			doneCount++
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

// GenerateManifests runs the generate_manifests playbook to output Kubernetes configs
func (order *SoftwareOrder) GenerateManifests() error {
	order.WriteLog(true, "Creating deployment manifests ...")

	if order.GenerateManifestsOnly {
		// If we are only generating manifests then use the previous run.
		// Also make sure the previous deployment directory exists.
		// One must build containers before attempting to re-generate the manifests.
		order.BuildPath = fmt.Sprintf("builds/%s/", order.DeploymentType)
		if _, err := os.Stat(order.BuildPath); os.IsNotExist(err) {
			return errors.New("the --generate-manifests-only flag can only be used to re-generate deployment files following a complete build. No previous build files exist")
		}

		// Rename the previous manifests, usermods, and build log with a timestamp
		// manifests/ --> manifests-<datetime>/
		if _, err := os.Stat(order.BuildPath + order.ManifestDir); !os.IsNotExist(err) {
			if err := os.Rename(order.BuildPath+order.ManifestDir,
				order.BuildPath+order.ManifestDir+"-"+order.TimestampTag); err != nil {
				return err
			}
		}

		// A single image only uses the vars_usermods.yml. That can be used to change the
		// running of the playbook that is used in creating the image. For "full" or
		// "multiple" deployments, only the manifests_usermods.yml is used. It is used
		// when generating manifests and not in the building of the images.
		if order.DeploymentType != "single" {
			if err := order.LoadUsermods("manifests_usermods.yml"); err != nil {
				return err
			}
		} else {
			if err := order.LoadUsermods("vars_usermods.yml"); err != nil {
				return err
			}
		}
		// build.log --> build-<datetime>.log
		order.LogPath = order.BuildPath + "build.log"
		buildLogPrevious := fmt.Sprintf("%sbuild-%s.log",
			order.BuildPath, order.TimestampTag)
		if err := os.Rename(order.LogPath, buildLogPrevious); err != nil {
			return err
		}
		logHandle, err := os.Create(order.LogPath)
		if err != nil {
			return err
		}
		order.Log = logHandle
	} else {
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
docker_tag: %s
SECURE_CONSUL: false
DISABLE_CONSUL_HTTP_PORT: false
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

		// Copy over the playbook files that contain configurations
		copyVarsCommand := fmt.Sprintf("cp %ssas_viya_playbook/vars.yml %svars.yml", order.BuildPath, order.BuildPath)
		_, err = exec.Command("sh", "-c", copyVarsCommand).Output()
		if err != nil {
			return err
		}
		copyAllCommand := fmt.Sprintf("cp %ssas_viya_playbook/group_vars/all %sall.yml", order.BuildPath, order.BuildPath)
		_, err = exec.Command("sh", "-c", copyAllCommand).Output()
		if err != nil {
			return err
		}
		copySoeDefaultsCommand := fmt.Sprintf("cp %ssas_viya_playbook/internal/soe_defaults.yml %ssoe_defaults.yml", order.BuildPath, order.BuildPath)
		_, err = exec.Command("sh", "-c", copySoeDefaultsCommand).Output()
		if err != nil {
			return err
		}

		// TODO: clean this up
		playbook := `
# Manifests can be re-generated without re-building:
# 1. Edit values in the 'manifests_usermods.yml' file.
# 2. Run build.sh passing in the '--generate-manifests-only --sas-docker-tag %s'
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
  - all.yml
  - soe_defaults.yml
  - vars.yml
  - vars_deployment.yml
  - manifests_usermods.yml
  - manifest-vars.yml

  roles:
  - ../../util/static-roles-%s/manifests
...
`
		err = ioutil.WriteFile(order.BuildPath+"generate_manifests.yml",
			[]byte(fmt.Sprintf(playbook, order.TagOverride, order.DeploymentType)), 0755)
		if err != nil {
			return err
		}
	}

	// Run the playbook locally to generate the Kubernetes manifests
	manifestsCommand := fmt.Sprintf("ansible-playbook --connection=local --inventory 127.0.0.1, %sgenerate_manifests.yml -vv", order.BuildPath)
	result, err := exec.Command("sh", "-c", manifestsCommand).Output()
	if err != nil {
		result := string(result) + "\n" + manifestsCommand + "\n"
		result += string(result) + "\n" + err.Error() + "\n"
		result += "Generate Manifests playbook failed.\n"
		result += fmt.Sprintf("To debug use `cd %s ; ansible-playbook -vv generate_manifests.yml`\n", order.BuildPath)
		return errors.New(result)
	}

	order.WriteLog(true, "Finished creating deployment manifests\n")

	return nil
}

// LoadUsermods retrieves the user provided vars_usermods.yml file
// from the project directory then copies it into the build
// directory, or if the file was not provided then the
// default usermods file is copied.
// This function can be used concurrently or non concurrently.
func (order *SoftwareOrder) LoadUsermods(usermodsFileName string) error {
	// manifests_usermods.yml --> manifests_usermods.yml-<datetime>.yml
	usermodsPathPrevious := fmt.Sprintf("builds/%s/%s-%s.yml", order.DeploymentType, usermodsFileName, order.TimestampTag)
	if _, err := os.Stat("builds/" + order.DeploymentType + "/" + usermodsFileName); !os.IsNotExist(err) {
		if err := os.Rename("builds/"+order.DeploymentType+"/"+usermodsFileName, usermodsPathPrevious); err != nil {
			return err
		}
	}

	usermodsFilePath := "util/" + usermodsFileName
	if _, err := os.Stat(usermodsFileName); !os.IsNotExist(err) {
		usermodsFilePath = usermodsFileName
		order.Log.Write([]byte(fmt.Sprintf("Loaded the custom %s file.", usermodsFileName)))
		log.Println("Loaded the custom " + usermodsFileName + " file.")
	}
	input, err := ioutil.ReadFile(usermodsFilePath)
	if err != nil {
		return err
	}

	err = ioutil.WriteFile(fmt.Sprintf("builds/%s/%s", order.DeploymentType, usermodsFileName), input, 0644)
	if err != nil {
		return err
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
	fileURL := fmt.Sprintf("https://support.sas.com/installation/viya/%s/sas-orchestration-cli/lax/sas-orchestration-linux.tgz", SasViyaVersion)
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

// Finish removes all temporary build files: sas_viya_playbook and all Docker contexts (tar files) in the /tmp directory
func (order *SoftwareOrder) Finish() {
	order.EndTime = time.Now()
	// TODO
	//for _, container := range order.Containers {
	//	if container.Status != DoNotBuild {
	//		container.Finish()
	//	}
	//}
}

// Helper function to convert an image size to a human readable value
func bytesToGB(bytes int64) string {
	return fmt.Sprintf("%.2f GB", float64(bytes)/float64(1000000000))
}

// ShowSummary displays metrics and next steps for deployment
func (order *SoftwareOrder) ShowSummary() error {
	if order.DeploymentType == "single" {

		nextStepInstructions := "\n" + fmt.Sprintf(`Run the following to start the container:

mkdir -p run
cp samples/viya-single-container/example_launchsas.sh run/launchsas.sh
cd run
sed -i 's|@REPLACE_ME_WITH_TAG@|%s|' launchsas.sh
./launchsas.sh

Note: If you used the auth-sssd addon or customised the user in the auth-demo addon,
      make sure to update the CASENV_ADMIN_USER in run/launchsas.sh to contain a valid username.
`, order.TagOverride)
		order.WriteLog(true, nextStepInstructions)

		order.EndTime = time.Now()
		fmt.Println(fmt.Sprintf("\nTotal Elapsed Time: %s\n", order.EndTime.Sub(order.StartTime).Round(time.Second)))
		return nil
	}

	if !order.GenerateManifestsOnly {
		// Special case where the single deployment does not use the order.Containers list
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
	}

	lineSeparator := strings.Repeat("-", 79)
	fmt.Println(lineSeparator)
	order.WriteLog(false, lineSeparator)

	// TODO: Make the list of directories reflective of the manifests generated.
	//       In a TLS build there will be an account type. Also, the "manifests"
	//       directory and Kubernetes namespaces are changeable. Should probably
	//       have a way to discover this information so it is reflects in the data
	//       given to the user.
	symlinkBuildPath := fmt.Sprintf("builds/%s/%s", order.DeploymentType, order.ManifestDir)
	namespaceGrepCommand := fmt.Sprintf("grep '^SAS_K8S_NAMESPACE' %smanifests_usermods.yml | awk -F ': ' '{ print $2 }'", order.BuildPath)
	grepResult, err := exec.Command("sh", "-c", namespaceGrepCommand).Output()
	if err != nil {
		return err
	}
	kubeNamespace := strings.TrimSuffix(string(grepResult), "\n")
	if len(kubeNamespace) == 0 {
		kubeNamespace = "sas-viya"
	}

	manifestLocation := fmt.Sprintf(`
Kubernetes manifests have been created: %s
That directory is mapped to:            %s
`,
		order.BuildPath+order.ManifestDir+"/",
		symlinkBuildPath)
	if order.GenerateManifestsOnly {
		manifestLocation = fmt.Sprintf(`
Kubernetes manifests have been created: %s
`,
			order.BuildPath+order.ManifestDir+"/")
	}

	manifestInstructions := fmt.Sprintf(`
To deploy a new environment run the below commands

Create the Kubernetes namespace:

kubectl apply -f %s/kubernetes/namespace/%s.yml

Then create the following Kubernetes objects:

kubectl -n %s apply -f %s/kubernetes/ingress/%s.yml && \
kubectl -n %s apply -f %s/kubernetes/configmaps && \
kubectl -n %s apply -f %s/kubernetes/secrets && \
kubectl -n %s apply -f %s/kubernetes/services && \
kubectl -n %s apply -f %s/kubernetes/deployments
`,
		symlinkBuildPath, kubeNamespace,
		kubeNamespace, symlinkBuildPath, kubeNamespace,
		kubeNamespace, symlinkBuildPath,
		kubeNamespace, symlinkBuildPath,
		kubeNamespace, symlinkBuildPath,
		kubeNamespace, symlinkBuildPath)

	fmt.Println(manifestLocation)
	fmt.Println(manifestInstructions)
	order.WriteLog(false, manifestLocation)
	order.WriteLog(false, manifestInstructions)

	if order.SkipDockerRegistryPush {
		dockerPushInstructions := fmt.Sprintf(`
Since you decided to skip pushing the images as part of the build process,
you will need to 'docker push' the following images before you can run the
above Kubernetes manifests.
`)
		dockerPushFileInstructions := fmt.Sprintf(`
The images that need to be pushed are referenced in

%s/dockerPush
`,
			symlinkBuildPath)
		dockerPushFileSummary := fmt.Sprintf(`# File generated by order.go on %s
#
# The following images were not pushed to the Docker registry
# per the '--skip-docker-registry-push' option used when running
# build.sh. You can execute the below commands to push the specific
# images. Note that the images must still reside on the current host.

`,
			order.TimestampTag)

		fmt.Println(dockerPushInstructions)
		order.WriteLog(false, dockerPushInstructions)
		dockerPushFile, err := os.Create(symlinkBuildPath + "/dockerPush")
		if err != nil {
			return err
		}

		defer dockerPushFile.Close()
		_, err = dockerPushFile.WriteString(dockerPushFileSummary)
		if err != nil {
			return err
		}
		for _, container := range order.Containers {
			dockerPushString := fmt.Sprintf("docker push %s/%s/%s-%s:%s", order.DockerRegistry, order.DockerNamespace, order.ProjectName, container.Name, order.TagOverride)
			fmt.Println(dockerPushString)
			order.WriteLog(false, dockerPushString)
			_, err = dockerPushFile.WriteString(dockerPushString + "\n")
			if err != nil {
				return err
			}
		}
		_, err = dockerPushFile.WriteString("\n")
		if err != nil {
			return err
		}
		dockerPushFile.Sync()
		fmt.Println(dockerPushFileInstructions)
		order.WriteLog(false, dockerPushFileInstructions)
	}

	fmt.Println(lineSeparator)
	order.WriteLog(false, lineSeparator)

	return nil
}
