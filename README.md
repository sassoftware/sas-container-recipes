<div align="center">  
<h1>SAS® Viya® Container Recipes</h1>
<img src="docs/sas-container-icon.jpg" alt="SAS Containers Icon" height="200">
<p>Framework to build SAS Viya Docker images and create deployments using Kubernetes.</p>

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
</div>

<br><br>
Container deployments are more lightweight and don't have as much
overhead as traditional virtual machines. By running a SAS engine inside a 
container, you can provision resources more efficiently to address a wide variety
of SAS workloads. Select a base SAS recipe and create custom containers 
with specific products or configurations – e.g, access to data sources, in-database
code and scoring accelerators, or specific analytic capabilities.
For more information see [SAS for Containers](http://support.sas.com/rnd/containers/).

<br><br>

## Getting Started
1. Locate your SAS Viya for Linux Software Order Email (SOE) and retrieve the `SAS_Viya_deployment_data.zip` file from it or [**start a free trial**](https://www.sas.com/en_us/trials.html) of SAS Viya. Not sure if your organization purchased SAS Software? [Contact Us](https://www.sas.com/en_us/software/how-to-buy.html) or get [SAS License Assistance](https://support.sas.com/en/technical-support/license-assistance.html).
    
2. Download the latest <a href="https://github.com/sassoftware/sas-container-recipes/releases" alt="SAS Container Recipes Releases">
        <img src="https://img.shields.io/github/release/sassoftware/sas-container-recipes.svg?&colorA=0b5788&colorB=0b5788&style=for-the-badge&" alt="Latest Release"/></a> 
or `git clone git@github.com:sassoftware/sas-container-recipes.git`

3. Choose your flavor and follow the recipe to build, test, and deploy your container(s).

    a. If you are looking for an environment tailored towards individual data scientists and developers, you will be interested in SAS Programming running on a [Single Container](https://github.com/sassoftware/sas-container-recipes#single-container-quickstart).

    b. If you would like an environment suitable for collaborative data science work, then you may be interested in a SAS programming-only environment or a SAS Viya full deployment on [Multiple Containers](https://github.com/sassoftware/sas-container-recipes#multiple-containers).

4. Check out post-deployment details relevant to your deployment.

    [SAS Viya 3.4 for Containers Deployment Guide](https://go.documentation.sas.com/?docsetId=dplyml0phy0dkr&docsetTarget=titlepage.htm&docsetVersion=3.4&locale=en) for `viya-programming` documentation.

    [SAS Viya 3.4 for Linux Deployment Guide](https://go.documentation.sas.com/?docsetId=dplyml0phy0lax&docsetTarget=titlepage.htm&docsetVersion=3.4&locale=en) for `viya-visuals` documentation.
  
    [SAS Administrators Support](https://support.sas.com/en/sas-administrators.html) for System Admins.
    
    [GitHub Project Issues Page](https://github.com/sassoftware/sas-container-recipes/issues) for questions and project improvements.
    
    [GitHub Project Wiki Page](https://github.com/sassoftware/sas-container-recipes/wiki) for high level details and FAQs.

    [Official Kubernetes Documentation](https://kubernetes.io/docs/home/) for general Kubernetes help.

    [Official Docker Documentation](https://docs.docker.com/) for general Docker help.



<br>

---

<br>


# For a Single User - SAS® Viya® Programming running on a Single Container
Use these instructions to create a SAS Viya Programming single container for 
an independent data scientist or developer to execute SAS code. All code and 
data should be stored in a persistent location outside the container.
This environment includes SAS Studio, SAS Workspace Server, and a CAS server, 
which provides in-memory analytics for Symmetric Multi Processing (SMP).


**A [supported version](https://success.docker.com/article/maintenance-lifecycle) of [Docker-ce (community edition)](https://docs.docker.com/install/linux/docker-ce/centos/) is required.**


### Build the Container
Run the following to create a user 'sasdemo' with the password 'sasdemo' for product evaluation.
A [non-root user](https://docs.docker.com/install/linux/linux-postinstall/#manage-docker-as-a-non-root-user) 
is recommended for all build commands.
```
  ./build.sh --zip ~/my/path/to/SAS_Viya_deploy_data.zip --addons "addons/auth-demo"
```

You can use addons found in [`addons/` directory](https://github.com/sassoftware/sas-container-recipes/tree/master/addons) 
to enhance the base SAS Viya image with SAS/ACCESS, LDAP configuration, and more.
                         

### Run the Container

After the container is built then instructions for how to run the image will be printed out.
```

  docker run --detach --rm --hostname sas-viya-programming \
    --env CASENV_CAS_VIRTUAL_HOST=<my_host_address> \
    --env CASENV_CAS_VIRTUAL_PORT=8081 \
    --publish-all \
    --publish 8081:80 \
    --name sas-viya-programming \
    sas-viya-programming:<VERSION-TAG>

    
```
Use the `docker images` command to see what images were built and what the most recent tag is (example: tag `19.0.1-20190109112555-48f98d8`).
Once the docker run command is completed, use docker ps to list the running container.


Finally go to the address `http://<myhostname>:8081` and start using SAS Studio!


<br>

---

<br>

# For one or more users - SAS® Viya® Programming or SAS® Viya® Full environment running on multiple containers
Use these instructions to build multiple Docker images to run **SAS Viya Programming**  or  **SAS Viya Full** environments for one or more users. Leverage Kubernetes to create the deployments which can use SMP or MPP CAS, which provide in-memory analytics.
<br><br>
A programming-only deployment supports data scientists and programmers who use 
SAS Studio or direct programming interfaces such as Python or REST APIs. 
Understand that this type of deployment does not include SAS Drive, 
SAS Environment Manager, and the complete suite of services that are 
included with a full deployment. Therefore, make sure that you are providing 
your users with the features that they require.



### Prerequisites
- A [supported version](https://success.docker.com/article/maintenance-lifecycle) of [Docker-ce](https://docs.docker.com/install/linux/docker-ce/centos/) such as v18+ (community edition) on Linux
- Python2 or Python3 and python-pip
- **Access to a Docker registry:** The build process will push built Docker images automatically to the Docker registry. Before running `build.sh` do a `docker login docker.registry.company.com` and make sure that the `$HOME/.docker/config.json` is filled in correctly.
- Access to a Kubernetes environment and [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed: required for the deployment step but not required for the build step.
- **Strongly recommended:** A local mirror of the SAS software. [Here's why](https://github.com/sassoftware/sas-container-recipes/wiki/The-Basics#why-do-i-need-a-local-mirror-repository). 

### Required `build.sh` Arguments
```    

        SAS Viya Programming example:
            ./build.sh --type multiple --zip /path/to/SAS_Viya_deployment_data.zip --addons "addons/auth-demo"

        SAS Viya Full example: 
            ./build.sh --type full --docker-registry-namespace myuniquename --docker-registry-url myregistry.myhost.com --zip /my/path/to/SAS_Viya_deployment_data.zip
        

  -y|--type [ multiple | full ] 
                          The type of deployment.
                            multiple: SAS Viya Programming Multi-Container deployment with Kubernetes
                            full: SAS Visuals based deployment with Kubernetes.
                            single: One container for SAS Programming. See the "Single Container" guide section.

  -n|--docker-registry-namespace <value>
                          The namespace in the Docker registry where Docker images 
                          will be pushed to. Use a unique name to prevent collisions.
                            example: myuniquename

  -u|--docker-registry-url <value>
                          URL of the Docker registry where Docker images will be pushed to.
                          This is required for Kubernetes 
                            example: 10.12.13.14:5000 or myregistry.myhost.com

  -v|--virtual-host 
                          The Kubernetes Ingress path that defines the location of the HTTP endpoint.
                          For more details on Ingress see the official Kubernetes documentation at
                          https://kubernetes.io/docs/concepts/services-networking/ingress/
                          
                            example: user-myproject.mylocal.com

  -z|--zip <value>
                          Path to the SAS_Viya_deployment_data.zip file from your Software Order Email (SOE).
                            example: /my/path/to/SAS_Viya_deployment_data.zip
                            
                            SAS License Assistance: https://support.sas.com/en/technical-support/license-assistance.html
                            SAS Software Purchase: https://www.sas.com/en_us/software/how-to-buy.html
                            SAS Software Trial: https://www.sas.com/en_us/trials.html
                        
                            
   ** [ EITHER --zip OR --playbook-dir ]  **

  -l|--playbook-dir <value>
                          Path to the sas_viya_playbook directory. A playbook is used for existing BAREOS deployments
                          whereas new deployments utilize the above '--zip' argument. If this is passed in along with
                          the zip file then this playbook location will take precendence.
    
                               
```

### Optional `build.sh` Arguments
```

  -a|--addons \"<value> [<value>]\"
                          A space separated list of layers to add on to the main SAS image.
                          See the 'addons' directory for more details on adding access engines and other tools.

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
* For a SAS Viya Programming deployment, the Kubernetes manifests are located at `viya-programming/viya-multi-container/working/manifests/kubernetes`
* For a SAS Viya Full deployment, the Kubernetes manifests are located at `viya-visuals/working/manifests/kubernetes/`

Choose between Symmetric Multi Processing (SMP) or Massively Parallel Processing (MPP) and run a 
`kubectl create --file` or `kubectl replace --file` on the manifests inside the kubernetes directory.

Then add hosts to your Kubernetes Ingress for `sas-viya-httpproxy` and other services using `kubectl edit ingress`.
```

    - Kubernetes Ingress Example -

  apiVersion: extensions/v1beta1
  kind: Ingress
  metadata:
    namespace: <myuniquename>
    name: example ingress
  spec:
    rules:
    - host: sas-viya-http.<mycompany>.com
      http:
        paths:
        - backend:
            serviceName: sas-viya-httpproxy
            servicePort: 80
          
    - host: sas-viya-cas.<mycompany>.com
      http:
        paths:
        - backend:
            serviceName: sas-viya-sas-casserver-primary
            servicePort: 5570


```
For more details on Ingress Controllers see [the official Kubernetes documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/).

Finally, go to the host address that's defined in your Kubernetes Ingress to view your SAS product(s). 
If there is no response from the host, then check the status of the containers by running `kubectl get pods`.
There should be one or more `sas-viya-<service>` pods, depending on your software order. 
You may also need to correct the host name on your Ingress Controller and check your Kubernetes configurations.

<img src="docs/sas-logon-screen.png" alt="SAS Logon Screen" style="width: 100%; height: 100%; object-fit: contain;">


<br>

---

<br>


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
