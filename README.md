<div align="center">  
<h1>SAS<sup>®</sup> Viya<sup>®</sup> Container Recipes</h1>
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
</div>

<br>
Container deployments are more lightweight and don't have as much
overhead as traditional virtual machines. By running a SAS engine inside a 
container, you can provision resources more efficiently to address a wide variety
of SAS workloads. Select a base SAS recipe and create custom containers 
with specific products or configurations – e.g, access to data sources, in-database
code and scoring accelerators, or specific analytic capabilities.
For more information see [SAS for Containers](http://support.sas.com/rnd/containers/).

<br>

## Quick Start
Use the instructions on this page to quickly build and launch SAS Viya containers. 
For more extensive infomation about building and launching SAS Viya containers, see the [GitHub Project Wiki Page](https://github.com/sassoftware/sas-container-recipes/wiki)

1. Locate your SAS Viya for Linux Software Order Email (SOE) and retrieve the 
`SAS_Viya_deployment_data.zip` file from it. Not sure if your organization 
purchased SAS Software? [Contact Us](https://www.sas.com/en_us/software/how-to-buy.html) 
or get [SAS License Assistance](https://support.sas.com/en/technical-support/license-assistance.html). 
If you have not purchased SAS Software but would like to give it a try, 
please check out our [Free Software Trials](https://www.sas.com/en_us/trials.html).
    
2. Download the latest <a href="https://github.com/sassoftware/sas-container-recipes/releases" alt="SAS Container Recipes Releases">
        <img src="https://img.shields.io/github/release/sassoftware/sas-container-recipes.svg?&colorA=0b5788&colorB=0b5788&style=for-the-badge&" alt="Latest Release"/></a> 
or `git clone git@github.com:sassoftware/sas-container-recipes.git`

3. Choose your flavor and follow the recipe to build, test, and deploy your container(s).

    a. If you are looking for an environment tailored towards individual data scientists and developers, you will be interested in a [SAS programming-only deployment running on a single container](https://github.com/sassoftware/sas-container-recipes#for-a-single-user---sas-viya-programming-only-deployment-running-on-a-single-container).

    b. If you would like an environment suitable for collaborative data science work, then you may be interested in a SAS programming-only deployment or a SAS Viya full [deployment on multiple containers](https://github.com/sassoftware/sas-container-recipes#for-one-or-more-users---sas-viya-programming-only-or-sas-viya-full-deployment-running-on-multiple-containers).

    c. For either single or multiple containers, addons found in the [addons/ directory](https://github.com/sassoftware/sas-container-recipes/tree/master/addons) can enhance the base SAS Viya images with SAS/ACCESS, LDAP configuration, and more. For each addon, review the [Appendix](https://github.com/sassoftware/sas-container-recipes/wiki/Appendix:-Under-the-Hood#addons) for important information and any possible prerequisite requirements.

<br>

---

<br>

## For a Single User - SAS Viya Programming-Only Deployment Running on a Single Container

Use these instructions to create a SAS Viya programming-only deployment in a single container for
an independent data scientist or developer to execute SAS code. All code and
data should be stored in a persistent location outside the container.
This deployment includes SAS Studio, SAS Workspace Server, and a CAS server,
which provides in-memory analytics for symmetric multi-processing (SMP).

**A [supported version](https://success.docker.com/article/maintenance-lifecycle) of [Docker-ce (community edition)](https://docs.docker.com/install/linux/docker-ce/centos/) is required.**

### Build the Image

Run the following to create a user 'sasdemo' with the password 'sasdemo' for product evaluation.
A [non-root user](https://docs.docker.com/install/linux/linux-postinstall/#manage-docker-as-a-non-root-user) 
is recommended for all build commands.
```
 ./sas-container-recipes --type single --zip ~/my/path/to/SAS_Viya_deployment_data.zip --addons "addons/auth-demo"
```                         

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

For more info see the [GitHub Project Wiki Page](https://github.com/sassoftware/sas-container-recipes/wiki).

<br>

---

<br>

## For One or More Users - SAS Viya Programming-Only or SAS Viya Full Deployment Running on Multiple Containers

Use these instructions to build multiple Docker images and then use the images 
to create a SAS Viya programming-only or a SAS Viya full deployment in Kubernetes. 
These deployments can have SMP or massively parallel processing (MPP) CAS servers,
which provide in-memory analytics, and can be used by one or more users. 

A programming-only deployment supports data scientists and programmers who use 
SAS Studio or direct programming interfaces such as Python or REST APIs. 
Understand that this type of deployment does not include SAS Drive, 
SAS Environment Manager, and the complete suite of services that are 
included with a full deployment. Therefore, make sure that you are providing 
your users with the features that they require.

### Prerequisites

- A [supported version](https://success.docker.com/article/maintenance-lifecycle) of [Docker-ce](https://docs.docker.com/install/linux/docker-ce/centos/) (community edition) on Linux or Mac must be installed on the build machine
- `java-1.8.0-openjdk` or another Java Runtime Environment (1.8.x) must be installed on the build machine
- `ansible` must be installed on the build machine
- **Access to a Docker registry:** The build process will push built Docker images automatically to the Docker registry. Before running `sas-container-recipes` do a `docker login docker.registry.company.com` and make sure that the `$HOME/.docker/config.json` is filled in correctly.
- Access to a Kubernetes environment and [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed: required for the deployment step but not required for the build step.
- **Strongly recommended:** A local mirror of the SAS software. [Here's why](https://github.com/sassoftware/sas-container-recipes/wiki/The-Basics#why-do-i-need-a-local-mirror-repository). 

### How to Build
Examples of running sas-container-recipes to build multiple containers are provided below. A non-root user is recommended for all build commands.

**Example: Programming-Only Deployment, Mulitple Containers**

```    
  ./sas-container-recipes \
  --type multiple \
  --zip /path/to/SAS_Viya_deployment_data.zip \
  --docker-registry-namespace myuniquename \
  --docker-registry-url myregistry.myhost.com \
  --addons "addons/auth-demo"
```

**Example: Full Deployment, Multiple Containers**

```
  ./sas-container-recipes \
  --type full \
  --zip /path/to/SAS_Viya_deployment_data.zip \
  --docker-registry-namespace myuniquename \
  --docker-registry-url myregistry.myhost.com \
  --addons "addons/auth-sssd"
```

**sas-container-recipes Arguments**

```
# Required Arguments

    --type [multiple | full | single]
        Sets the deployment type.
        single  : SAS Viya programming-only container started with a `docker run` command
        multiple: SAS Viya programming-only deployment, multiple containers using Kubernetes
        full    : SAS Viya full deployment, multiple containers using Kubernetes.
        
        default: single

    --zip <value>
        Path to the SAS_Viya_deployment_data.zip file from your Software Order Email (SOE).
        If you do not know if your organization has a SAS license then contact
        https://www.sas.com/en_us/software/how-to-buy.html
        
        example: /path/to/SAS_Viya_deployment_data.zip
    
    --docker-namespace <value>
        The namespace in the Docker registry where Docker
        images will be pushed to. Used to prevent collisions.
        
        example: mynamespace
    
    --docker-registry-url <value>
        URL of the Docker registry where Docker images will be pushed to.
        
        example: 10.12.13.14:5000 or my-registry.docker.com


# Optional Arguments 

    --virtual-host 
        The Kubernetes Ingress path that defines the location of the HTTP endpoint.
        For more details on Ingress see the official Kubernetes documentation at
        https://kubernetes.io/docs/concepts/services-networking/ingress/
        
        example: user-myproject.mycluster.com
    
    --addons "<value> <value> ..."
        A space or comma separated list of addon names. Each requires additional configuration:
        See the GitHub Wiki: https://github.com/sassoftware/sas-container-recipes/wiki/Appendix:-Under-the-Hood
        Access Engines: access-greenplum, access-hadoop, access-odbc, access-oracle, access-pcfiles, access-postgres, access-redshift, access-teradata
        Authentication: auth-sssd, auth-demo
        Other: ide-jupyter-python3
    
    --base-image <value>
        Specifies the Docker image from which the SAS images will build on top of.
        Default: centos
    	
    --base-tag <value>
        Specifies the Docker tag for the base image that is being used.
        Default: 7
    
    --mirror-url <value>
        The location of the mirror URL. See the Mirror Manager guide at
        https://support.sas.com/en/documentation/install-center/viya/deployment-tools/34/mirror-manager.html
    
    --tag <value>
        Override the default tag formatted as "19.0.4-20190405074255-50645c9"
            ( <recipe-version> - <date time> - <git sha1 > )

    --workers <integer>
        Specify the number of CPU cores to allocate for the build process.
        default: Utilize all cores on the build machine
    
    --verbose
        Output the result of each Docker layer creation.
        default: false
    
    --build-only "<container-name> <container-name> ..."
        Build specific containers by providing a comma or space separated list of container names, no "sas-viya-" prefix, in quotes.
        [WARNING] This is meant for developers that require specific small components to rapidly be build.
        
        example: --build-only "consul" or --build-only "consul httpproxy sas-casserver-primary"
    
    --skip-mirror-url-validation
        Skips validating the mirror URL from the --mirror-url flag.
        default: false
    
    --skip-docker-url-validation
        Skip verifying the Docker registry URL.
        default: false
    
    --builder-port <integer>
        Port to listen on and serve entitlement and CA certificates from. Serving certificates is required to avoid leaving sensitive order data in the layers.
        WARNING: Changing this between builds will invalidate your layer cache.
        default: 1976
    
    --generate-manifests-only
        Will only build manifests. They will be placed in the /builds/<deployment_type> directory.
        default: false

    --version
    	Print the SAS Container Recipes version and exit.
    	
    --help
    	Displays details on all required and optional arguments.
```

### Running Multiple Containers

The build process creates Kubernetes manifests that you use to run multiple containers. 

   * For a SAS Viya programming-only deployment, the Kubernetes manifests are located at `$PWD/viya-programming/viya-multi-container/working/manifests`
   * For a SAS Viya full deployment, the Kubernetes manifests are located at `$PWD/viya-visuals/working/manifests`

For information about using the manifests, see [Build and Run SAS Viya Multiple Containers](https://github.com/sassoftware/sas-container-recipes/wiki/Build-and-Run-SAS-Viya-Multiple-Containers).

## Log on to SAS Studio ##

After the containers are running, users can sign on to SAS Studio.

- If you deployed a programming-only environment, then your environment contains SAS Studio 4.4.
- If you deployed a full environment, then your environment contains both SAS Studio 4.4 and SAS Studio 5.1. By default, you will log on to SAS Studio 5.1.

Here are some examples of how to log on:

- For SAS Studio 4.4 via Docker run without TLS:

  `https://docker-host:8081/SASStudio`

- For SAS Studio 4.4 via Kubernetes:

  `https://ingress-path/SASStudio`

- For SAS Studio 5.1:

  `https://ingress-path/SASStudioV`

<img src="docs/sas-logon-screen.png" alt="SAS Logon Screen" style="width: 100%; height: 100%; object-fit: contain;">

<br>

---

<br>

## Additional Resources

- [Wiki: Documentation](https://github.com/sassoftware/sas-container-recipes/wiki)
- [Issues: Questions and Project Improvements](https://github.com/sassoftware/sas-container-recipes/issues)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [Docker Documentation](https://docs.docker.com/)
- [SAS License Assistance](https://support.sas.com/en/technical-support/license-assistance.html)
- [SAS Software Purchase](https://www.sas.com/en_us/software/how-to-buy.html)
- [SAS Software Trial](https://www.sas.com/en_us/trials.html)

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
