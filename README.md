<div align="center">  

    <h1>SAS® Viya® Container Recipes</h1>
    <img src="https://gitlab.sas.com/sassoftware/sas-container-recipes/raw/master/docs/icon-sas-container-chart.jpg" alt="SAS Container Recipes Banner" height="170">

    <p>
        <p>Framework to build SAS Viya environments using Docker images and deploy using Kubernetes.</p>
    
        <a href="https://www.sas.com/en_us/software/viya.html">
            <img src="https://img.shields.io/badge/SAS%20Viya-3.4-blue.svg?&colorA=0b5788&style=for-the-badge&logoWidth=30&logo=data:image/png;base64,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"
                alt="SAS Viya Version"/></a>
        <a href="https://www.docker.com/">
            <img src="https://img.shields.io/badge/Docker--ce-18+-blue.svg?&style=for-the-badge&colorA=066da5"
                alt="Docker Version"></a>
        <a href="https://kubernetes.io/">
            <img src="https://img.shields.io/badge/Kubernetes-1.0+-blue.svg?&style=for-the-badge&colorA=0b5788"
                alt="Kubernetes Version"></a>
        <a href="https://github.com/ansible/ansible-container" alt="Ansible Container">
            <img src="https://img.shields.io/badge/Ansible%20Container-0.9+-lightgrey.svg?&style=for-the-badge" 
                alt="Ansible Container Version"/></a>
    </p>
</div>

<br><br>
Container deployments are more lightweight and don't carry as much
overhead as traditional virtual machines. By running a SAS engine inside a 
container, you can provision resources more efficiently to address a wide variety
of SAS workloads. Choose a fixed container with specific SAS products for 
immediate deployment or select a base SAS recipe, and create custom containers 
with specific products or configurations – e.g, access to data sources, in-database
code and scoring accelerators, or specific analytic capabilities.
<br><br>


## Getting Started
1. Retrieve the `SAS_Viya_deployment_data.zip` file from the your SAS Viya for Linux Software Order Email (SOE). If you don't know if your organization purchased SAS Software then [contact us](https://www.sas.com/en_us/software/how-to-buy.html) or see the [SAS License Assistance](https://support.sas.com/en/technical-support/license-assistance.html) page.

    <a href="https://www.sas.com/en_us/software/how-to-buy.html" alt="SAS Software Order">
        <img src="https://img.shields.io/badge/SAS%20Viya%20License-Try%20It%20Out-lightgrey.svg?&style=for-the-badge"/></a>
        
2. Download this project or `git clone git@github.com:sassoftware/sas-container-recipes.git` to use the [`build.sh`](#use-buildsh-to-build-the-images) script.

    <a href="https://github.com/sassoftware/sas-container-recipes/releases" alt="SAS Container Recipes">
        <img src="https://img.shields.io/github/release/sassoftware/sas-container-recipes.svg?&style=for-the-badge&label=Latest Stable Release"/></a>    

3. Choose your flavor and follow the recipe to build, test, and deploy your container(s).

    a. SAS Programming - [Single Container Quickstart](https://github.com/sassoftware/sas-container-recipes#single-container-quickstart) (**Dockerfile**): tailored towards most individual data scientists and developers.

    b. SAS Programming - [Multiple Containers](https://github.com/sassoftware/sas-container-recipes#multiple-containers) (**Kubernetes**): For collaborative data science environments with SAS Studio + CAS Massively Parallel Processing (MPP).
    
    c. SAS Visuals     - [Multiple Containers](https://github.com/sassoftware/sas-container-recipes#multiple-containers) (**Kubernetes**): Visual Analytics based collaborative environment

4. Check out post-deployment details to suit your use case.

    [SAS Viya 3.4 for Linux Deployment Guide](https://go.documentation.sas.com/?docsetId=dplyml0phy0lax&docsetTarget=titlepage.htm&docsetVersion=3.4&locale=en) for validation and configurations
  
    [The GitHub Wiki](https://github.com/sassoftware/sas-container-recipes/wiki) for high level details and FAQs.
  
    [SAS Administrators Support](https://support.sas.com/en/sas-administrators.html) for System Administrators.
    
    [GitHub Issues Page](https://github.com/sassoftware/sas-container-recipes/issues) to ask questions, request features, and more.
 

<br>
---
---
<br>


# SAS® Viya® Programming Quickstart - Single Container
For most independent data scientists and developers, those want portable on-demand interactive SAS code execusion. 
All code and data should be stored in a persistent location outside the container.
This environment includes SAS Studio, SAS Workspace Server, and the CAS server to which provide in-memory analytics for Symmetric Multi Processing (SMP).


**A [supported version](https://success.docker.com/article/maintenance-lifecycle) of [Docker-ce (community edition)](https://docs.docker.com/install/linux/docker-ce/centos/) is required.**


### Build the Container
Run `./build.sh --zip ~/my/path/to/SAS_Viya_deploy_data.zip --addons "addons/auth-demo"` to create a user 'sasdemo' with the password 'sasdemo' for product evaluation. A [non-root user](https://docs.docker.com/install/linux/linux-postinstall/#manage-docker-as-a-non-root-user) is recommended for all build commands.
Addons can also be used to enhance the base SAS Viya image with SAS/ACCESS, LDAP configuration, and more in the [`addons/` directory.](https://github.com/sassoftware/sas-container-recipes/tree/master/addons)
                         

### Run the Container

```

  docker run --detach --rm --hostname sas-viya-programming \
    --env CASENV_CAS_VIRTUAL_HOST=<host-name-where-docker-is-running> \
    --env CASENV_CAS_VIRTUAL_PORT=8081 \
    --publish-all \
    --publish 8081:80 \
    --name sas-viya-programming \
    sas-viya-programming:latest

    
```
Use the `docker images` command to see what images were built then use `docker ps` to list the running containers.


Finally go to the address `http://_host-name-where-docker-is-running_:8081` and start using SAS Studio!


<br>
---
---
<br>


# Multiple SAS® Viya®  Containers
Build multiple Docker images of **SAS Viya Programming** environments **or** other **SAS Viya Visuals** environments. Leverage Kubernetes to create the deployments, create SMP or MPP CAS, and run these environments in interactive mode.

### Prerequisites
- A [supported version](https://success.docker.com/article/maintenance-lifecycle) of [Docker-ce](https://docs.docker.com/install/linux/docker-ce/centos/) such as v18+ (community edition) is required.
- Python2 or Python3 and python-pip are required to build
- **Access to a Docker registry**: The build process will push built Docker images automatically to the Docker registry. Before running `build.sh` do a `docker login docker.registry.company.com` and make sure that the `$HOME/.docker/config.json` is filled in correctly.
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed and access to a Kubernetes environment. This is required for the deployment step but it is not required for the build step.
- A local mirror of the SAS software is **strongly recommended**. [Here's why](https://github.com/sassoftware/sas-container-recipes/wiki/The-Basics#why-do-i-need-a-local-mirror-repository). 

### Required `build.sh` Arguments
```    

        SAS Viya Programming example: 
            ./build.sh --type multiple --zip /path/to/SAS_Viya_deployment_data.zip --addons "addons/auth-demo"

        SAS Viya Visuals example: 
            ./build.sh --type full --docker-registry-namespace mynamespace --docker-registry-url my-registry.docker.com --zip /my/path/to/SAS_Viya_deployment_data.zip
        

  -y|--type [ multiple | full ] 
                          The type of deployment.
                            Multiple: SAS Viya Programming Multi-Container deployment with Kubernetes
                            Full: SAS Visuals based deployment with Kubernetes.
                            Single: One container for SAS Programming. See the "Single Container" guide section.

  -n|--docker-registry-namespace <value>
                          The namespace in the Docker registry where Docker
                          images will be pushed to. Used to prevent collisions.
                            example: mynamespace

  -u|--docker-registry-url <value>
                          URL of the Docker registry where Docker images will be pushed to.
                            example: 10.12.13.14:5000 or my-registry.docker.com, do not add 'http://' 

  -z|--zip <value>
                          Path to the SAS_Viya_deployment_data.zip file from your Software Order Email (SOE).
                          If you do not know if your organization has a SAS license then contact
                          https://www.sas.com/en_us/software/how-to-buy.html
                          
                            example: /path/to/SAS_Viya_deployment_data.zip
      [EITHER/OR]          

  -l|--playbook-dir <value>
                          Path to the sas_viya_playbook directory. A playbook is used for existing BAREOS deployments
                          whereas new deployments utilize the above '--zip' argument. If this is passed in along with
                          the zip file then this playbook location will take precendence. 


  -v|--virtual-host 
                          The Kubernetes Ingress path that defines the location of the HTTP endpoint.
                          For more details on Ingress see the official Kubernetes documentation at
                          https://kubernetes.io/docs/concepts/services-networking/ingress/
                          
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
                          The location of the mirror URL.See the Mirror Manager guide at
                          https://support.sas.com/en/documentation/install-center/viya/deployment-tools/34/mirror-manager.html


  -p|--platform <value>
                          The type of distribution that this build script is being run on.
                            Options: [ redhat | suse ]
                            Default: redhat

  -d|--skip-docker-url-validation
                          Skips validating the Docker registry URL

  -k|--skip-mirror-url-validation
                          Skips validating the mirror URL from the --mirror-url flag.

  -e|--environment-setup
                          Automatically sets up a python virtual environment called 'env',
                          installs the required packages, and sources the virtual environment
                          during the build process.

  -s|--sas-docker-tag
                          The tag to apply to the images before pushing to the Docker registry.
                            default: ${recipe_project_version}-${datetime}-${last_commit_sha1}
                            example: 18.12.0-20181209115304-b197206
  
  
```

### After running `build.sh`
* For a SAS Viya Programming deployment the Kubernetes manifests are located at `viya-programming/viya-multi-container/working/manifests/kubernetes`
* For a SAS Viya Visuals deployment the Kubernetes are located at `viya-visuals/working/manifests/kubernetes/**[deployment-smp OR deployment-mpp]**`

Choose between Symmetric Multi Processing (SMP) or Massively Parallel Processing (MPP) and run a `kubectl create --file` or `kubectl replace --file` on those manifests 

Then add hosts to your Kubernetes Ingress for `sas-viya-httpproxy` and other services using `kubectl edit ingress`.
```

    - Kubernetes Ingress Example -

  spec:
    rules:
    - host: sas-viya-http.mycompany.com
      http:
        paths:
        - backend:
            serviceName: sas-viya-httpproxy
            servicePort: 80
          
    - host: sas-viya-cas.mycompany.com
      http:
        paths:
        - backend:
            serviceName: sas-viya-sas-casserver-primary
            servicePort: 5570


```
For more details on Ingress Controllers see [the official Kubernetes documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/).

Finally, go to the host address that's defined in your Kubernetes Ingress to view your SAS product(s). 
If there is no response from the host then check the status of the containers by running `kubectl get pods`. There should be one or more `sas-viya-<service>` pods, depending on your software order. You may also need to correct the host name on your Ingress Controller and check your Kubernetes configurations.


<br>
---
---
<br>


## Other Documentation
Check out our [Wiki](https://github.com/sassoftware/sas-container-recipes/wiki) for specific details.
Have a quick question? Open a ticket in the "issues" tab to get a response from the maintainers and other community members. If you're unsure about something just submit an issue anyways. We're glad to help!
If you have a specific license question head over to the [support portal](https://support.sas.com/en/support-home.html).

## Contributing
Have something cool to share? SAS gladly accepts pull requests on GitHub! For more details see [CONTRIBUTING.md](https://github.com/sassoftware/sas-container-recipes/blob/master/docs/CONTRIBUTING.md).

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

