# SAS for Containers: Recipes
This repository contains a collection of recipes and other resources for building containers that include the SAS Viya software and other tools.

- [/all-in-one](all-in-one/README.md) creates a SAS Viya programming-only analytic container from one Dockerfile for convenience and simplicity. This recipe, which was presented at SAS Global Forum 2018, includes SAS Studio, R Studio, and Jupyter Lab.
- [/viya-programming](viya-programming/README.md) is a folder that includes a recipe and resources for creating SAS Viya 3.4 programming-only Docker images.
- [/addons](addons/README.md) contains recipes and resources that enhance the base SAS Viya software, such as configuration of SAS/ACCESS software and integration with LDAP.
- A [build script](#use-buildsh-to-build-the-images) that you can use to create a container image that includes the SAS Viya software and addon layers.

## Prerequisites
### SAS Software

- SAS Viya 3.4 software: a SAS Viya 3.4 on Linux order and the SAS_Viya_deployment_data.zip from the Software Order Email (SOE) are required.
- Creating a local mirror of the SAS software is strongly recommended. [Here's why](../wikis/Tips#create-a-local-mirror-repository). 

### Other Software

- A [supported version](https://success.docker.com/article/maintenance-lifecycle) of Docker is required.
- Git is required.

The following is required when building multiple containers:

- Access to a Docker registry
- Python2 or Python3
- pip
- virtualenv
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- Access to a Kubernetes environment

### Clone the Repository

Here is an example of the `git clone` command for a Linux host that has Git and Docker installed. 
The command assumes that you will clone the repository in the $HOME directory.

```
cd $HOME
git clone https://github.com/sassoftware/sas-container-recipes.git
```

**Note:** On Windows, you can clone the repository by using PowerShell. Also, you can clone the repository on a Mac.

## SAS Viya Programming - Single Container

### At a Glance

* The SAS Viya programming run-time in a single container on the Docker platform.
* Includes SAS Studio, SAS Workspace Server, and the CAS server, which provides in-memory analytics. The CAS server allows for symmetric multi-processing (SMP) by users.
* Ideal for data scientists and programmers who want on-demand access.
* Ideal for ephemeral computing. By that, users should save code and store data in a permanent location outside the container.
* Run the container in interactive mode so that users can access the SAS Viya programming run-time.
* Run the container in batch mode to execute SAS code on a scheduled basis.

### Use build.sh to Build the Images

A script named `build.sh` is at the repository root level. After the sassoftware/sas-container-recipes project is cloned, run `build.sh` to build a set of Docker images for SAS Viya 3.4.

The following example assumes that you are in the 
/$HOME/sas-container-recipes directory, a mirror repository is set up at `http://host.company.com/sas_repo`, and an addon layer, [auth-demo](addons/auth-demo/README.md), is included in the build.

```
build.sh \
--type single \
--zip /path/to/SAS_Viya_deployment_data.zip \
--mirror-url http://host.company.com/sas_repo \
--addons "addons/auth-demo"
```

### List Images

To see the images after the build completes, use the `docker images` command. Here is an example of the output:

```
REPOSITORY                TAG                               IMAGE ID            CREATED             SIZE
sas-viya-programming      18.10.0-20181018113621-577b88f    965b522a213d        21 hours ago        8.52GB
svc-auth-demo             latest                            965b522a213d        21 hours ago        8.52GB
viya-single-container     latest                            2351f556f15a        2 days ago          8.52GB
centos                    latest                            5182e96772bf        6 weeks ago         200MB
```

**Notes:** 

- The sizes of the viya-single-container image and the svc-auth-demo image vary depending on your order.
- In the example output, the identical size for two images can be misleading. There is an image that is 8.52 GB, which includes the three images. The svc-auth-demo image is a small image layer stacked on the viya-single-container image, which is a large image layer stacked on the centos image.
- If an [addon](addons/README.md) does not include a Dockerfile, an image is not created.  

### Start the Container

After the build is complete, use the `docker run` command to start the container.

```
docker run \
    --detach \
    --rm \
    --env CASENV_CAS_VIRTUAL_HOST=<host-name-where-docker-is-running> \
    --env CASENV_CAS_VIRTUAL_PORT=8081 \
    --publish-all \
    --publish 8081:80 \
    --name sas-viya-programming \
    --hostname sas-viya-programming \
    sas-viya-programming:18.10.0-20181018113621-577b88f
```

To check the status of the containers, run `docker ps`.

```
docker ps --filter name=sas-viya-programming --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}} \t{{.Ports}}"
CONTAINER ID        NAMES                   IMAGE                   STATUS              PORTS
4b426ce49b6b        sas-viya-programming    sas-viya-programming    Up 2 minutes        0.0.0.0:8081->80/tcp, 0.0.0.0:33221->443/tcp, 0.0.0.0:33220->5570/tcp    
```

After the container has started, log on to SAS Studio with the user name `sasdemo` and the password `sasdemo` at:
 
 http://_host-name-where-docker-is-running_:8081

 **Note:** The user name `sasdemo` and the password `sasdemo` are the credentials for the demo user that is set up by the auth-demo addon. 

## SAS Viya Programming - Multiple Containers

### At a Glance

* The SAS Viya programming run-time deployed to multiple Docker containers with Kubernetes.
* A typical deployment includes a container for the SAS Viya programming run-time, a container for the CAS server, and a container for an HTTP proxy server.
* Ideal for the [users described above](#at-a-glance), but who want to step up the analytics and data processing to CAS massively parallel processing (MPP).
* Leverage Kubernetes to create the deployments, create the CAS server (SMP or MPP), and to run the containers in interactive mode so that users can access the SAS Viya programming run-time.

### Docker Registry

The build process will push built Docker images automatically to the Docker registry. Before running `build.sh` do a `docker login docker.registry.company.com` and make sure that the `$HOME/.docker/config.json` is filled in correctly.

### Kubernetes Ingress Configuration

The instructions here assume that you will configure an Ingress Controller to point to the `sas-via-httpproxy` service. 

Here is an example of the Ingress configuration that needs to be loaded into Kubernetes. This is defining the Ingress path, not the Ingress Controller. Create a file called sas-viya.ing and add the following to it:

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: sas-viya-ing
  namespace: @FIXME@
spec:
  rules:
  - host: sas-viya-http.company.com
    http:
      paths:
      - backend:
          serviceName: sas-viya-httpproxy
          servicePort: 80
  - host: sas-viya-cas.company.com
    http:
      paths:
      - backend:
          serviceName: sas-viya-sas-casserver-primary
          servicePort: 5570
```

Load the configuration:

```
kubectl create -f sas-viya.ing
```

### Use build.sh to Build the Images

A script named `build.sh` is at the repository root level. After the sassoftware/sas-container-recipes project is cloned, run `build.sh` to build a set of Docker images for SAS Viya 3.4.

The following example assumes that you are in the 
/$HOME/sas-container-recipes directory, a mirror repository is set up at `http://host.company.com/sas_repo`, and an addon layer, [auth-demo](addons/auth-demo/README.md), is included in the build.

```
build.sh \
--type multiple \
--zip /path/to/SAS_Viya_deployment_data.zip \
--mirror-url http://host.company.com/sas_repo \
--docker-url docker.registry.company.com \
--docker-namespace sas \
--virtual-host sas-viya-http.company.com \
--addons "addons/auth-demo"
```

### Start the Containers

A set of Kubernetes manifests are located at `$PWD/viya-programming/viya-multi-container/working/manifests/kubernetes`. Run them in the following order:

```
kubectl create -f viya-programming/viya-multi-container/working/manifests/kubernetes/configmaps
kubectl create -f viya-programming/viya-multi-container/working/manifests/kubernetes/secrets
kubectl create -f viya-programming/viya-multi-container/working/manifests/kubernetes/deployments
```

To check the status of the containers, run `kubectl get pods`.

```
kubectl get pods
NAME                                            READY   STATUS    RESTARTS   AGE
sas-viya-httpproxy-0                            1/1     Running   0          21h
sas-viya-programming-0                          1/1     Running   0          21h
sas-viya-sas-casserver-primary-0                1/1     Running   0          21h
```

After the container has started, log on to SAS Studio with the user name `sasdemo` and the password `sasdemo` at:
 
 http://_sas-viya-http.company_.com

**Note:** The user name `sasdemo` and the password `sasdemo` are the credentials for the demo user that is set up by the auth-demo addon. 

## Copyright

Copyright 2018 SAS Institute Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

&nbsp;&nbsp;&nbsp;&nbsp;https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
