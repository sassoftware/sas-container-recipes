# SAS Container Recipes
Framework to deploy SAS Viya environments using containers. Learn more at https://github.com/sassoftware/sas-container-recipes/wiki

## Prerequisites
1. A SAS Viya 3.4 on Linux order with the SAS_Viya_deployment_data.zip from the Software Order Email (SOE) are required.
2. Clone this repository and use [`build.sh`](#use-buildsh-to-build-the-images) in this project to create a container images.

**Choose between a [Single Container](https://github.com/sassoftware/sas-container-recipes#single-container) or [Multiple Containers](https://github.com/sassoftware/sas-container-recipes#multiple-containers) deployment type below.**


---
---


# Single Container
The SAS Viya programming run-time in a single container on the Docker platform. Includes SAS Studio, SAS Workspace Server, and the CAS server, which provides in-memory analytics. The CAS server allows for symmetric multi-processing (SMP) by users. Ideal for data scientists and programmers who want on-demand access and for ephemeral computing, where users should save code and store data in a permanent location outside the container. Run the container in interactive mode so that users can access the SAS Viya programming run-time or run the container in batch mode to execute SAS code on a scheduled basis.

**A [supported version](https://success.docker.com/article/maintenance-lifecycle) of Docker and git are required.**

### Required `build.sh` Arguments
```

    example: ./build.sh -y single -z ~/my/path/to/SAS_Viya_deployment_data.zip

  -y|--type single        The type of deployment
                               Options: [ single | multiple | full ]
                               Default: single

  -z|--zip <value>        Path to the SAS_Viya_deployment_data.zip file
                              example: /path/to/SAS_Viya_deployment_data.zip


```

### Optional `build.sh` Arguments:

```

  -a|--addons "<value> [<value>]"  
                          A space separated list of layers to add on to the main SAS image
                          The `/addons` directory contains recipes and resources that enhance
                          the base SAS Viya software, such as configuration of SAS/ACCESS 
                          software and integration with LDAP.
    
                          
```

### After running `build.sh`

To see the images after the build completes successfully, use the `docker images` command. Here is an example of the output:

```


  REPOSITORY                TAG                               IMAGE ID            CREATED             SIZE
  sas-viya-programming      18.10.0-20181018113621-577b88f    965b522a213d        21 hours ago        8.52GB
  svc-auth-demo             latest                            965b522a213d        21 hours ago        8.52GB
  viya-single-container     latest                            2351f556f15a        2 days ago          8.52GB
  centos                    latest                            5182e96772bf        6 weeks ago         200MB


```

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


---
---


# Multi-Container
Build multiple Docker images of a SAS Viya programming-only environment or other SAS Viya Visuals environments. Leverage Kubernetes to create the deployments, create SMP or MPP CAS, and run these environments in interactive mode.

### Prerequisites
- Python2 or Python3 and python-pip 
- **Access to a Docker registry**: The build process will push built Docker images automatically to the Docker registry. Before running `build.sh` do a `docker login docker.registry.company.com` and make sure that the `$HOME/.docker/config.json` is filled in correctly.
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed and access to a Kubernetes environment: The instructions here assume that you will be configuring an Ingress Controller to point to the `sas-viya-httpproxy` service. 
- A local mirror of the SAS software is **strongly recommended**. [Here's why](https://github.com/sassoftware/sas-container-recipes/wiki/The-Basics#why-do-i-need-a-local-mirror-repository). 

### Required `build.sh` Arguments
```    

        example: build.sh --type single --zip /path/to/SAS_Viya_deployment_data.zip -m http://host.mycompany.com/sas_repo -addons "addons/auth-demo"

  -y|--type [ multiple | full ] 
                          The type of deployment

  -n|--docker-registry-namespace <value>
                          The namespace in the Docker registry where Docker
                           images will be pushed to. Used to prevent collisions.
                               example: mynamespace

  -u|--docker-registry-url <value>
                          URL of the Docker registry where Docker images will be pushed to.
                               example: 10.12.13.14:5000 or my-registry.docker.com, do not add 'http://' 

  -z|--zip <value>
                          Path to the SAS_Viya_deployment_data.zip file
                               example: /path/to/SAS_Viya_deployment_data.zip
      [EITHER/OR]          

  -l|--playbook-dir <value>
                          Path to the sas_viya_playbook directory. If this is passed in along with the 
                               SAS_Viya_deployment_data.zip then this will take precedence.

  -v|--virtual-host 
                          The Kubernetes ingress path that defines the location of the HTTP endpoint.
                               example: user-myproject.mylocal.com
                               
```

### Optional `build.sh` Arguments
```

  -i|--baseimage <value>
                          The Docker image from which the SAS images will build on top of
                               Default: centos

  -t|--basetag <value>
                          The Docker tag for the base image that is being used
                               Default: latest

  -m|--mirror-url <value>
                          The location of the mirror URL.
                               See https://support.sas.com/en/documentation/install-center/viya/deployment-tools/34/mirror-manager.html
                               for more information on setting up a mirror.

  -p|--platform <value>
                          The type of operating system we are installing on top of
                               Options: [ redhat | suse ]
                               Default: redhat

  -d|--skip-docker-url-validation
                          Skips validating the Docker registry URL

  -k|--skip-mirror-url-validation
                          Skips validating the mirror URL

  -e|--environment-setup
                          Setup python virtual environment

  -s|--sas-docker-tag
                          The tag to apply to the images before pushing to the Docker registry

  -h|--help               Prints out this message
  
  
```


**Notes:** 
- The sizes of the viya-single-container image and the svc-auth-demo image vary depending on your order.
- In the example output, the identical size for two images can be misleading. There is an image that is 8.52 GB, which includes the three images. The svc-auth-demo image is a small image layer stacked on the viya-single-container image, which is a large image layer stacked on the centos image.
- If an [addon](addons/README.md) does not include a Dockerfile, an image is not created.  

## Other Documentation
Check out our [Wiki](https://github.com/sassoftware/sas-container-recipes/wiki) for specific details.
Have a quick question? Open a ticket in the "issues" tab to get a response from the maintainers and other community members. If you're unsure about something just submit an issue anyways. We're glad to help!
If you have a specific license question head over to the [support portal](https://support.sas.com/en/support-home.html).

## Contributing
Have something cool to share? SAS gladly accepts pull requests on GitHub! We appreciate your best efforts and value the transparent collaboration that GitHub has.

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
