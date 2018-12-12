<img src="https://gitlab.sas.com/sassoftware/sas-container-recipes/raw/master/docs/icon-sas-container-chart.jpg" width="230"><br>
# SAS Container Recipes
Framework to build and deploy SAS Viya environments using Docker images and Kubernetes.

Learn more at https://github.com/sassoftware/sas-container-recipes/wiki


### It's easy as ...
1. Retrieve the `SAS_Viya_deployment_data.zip` file from the your SAS Viya for Linux Software Order Email (SOE) or [place a purchase order of SAS Viya Software](https://www.sas.com/en_us/software/how-to-buy.html).
2. Download [the latest release of this project](https://github.com/sassoftware/sas-container-recipes/releases) or clone this repository to use the [`build.sh`](#use-buildsh-to-build-the-images) script
3. Choose your flavor and follow the recipe to build, test, and deploy your container(s).

    a. SAS Programming - [Single Container Quickstart](https://github.com/sassoftware/sas-container-recipes#single-container-quickstart) (**Dockerfile**): SAS Studio + CAS (Cloud Analytic Services) SMP for individual data scientists.

    b. SAS Programming - [Multiple Containers](https://github.com/sassoftware/sas-container-recipes#multiple-containers) (**Kubernetes**): For collaborative data science environments with SAS Studio + CAS Massively Parallel Processing (MPP).
    
    c. SAS Visuals     - [Multiple Containers](https://github.com/sassoftware/sas-container-recipes#multiple-containers) (**Kubernetes**): Visual Analytics based collaborative environment
    

---
---


# Single Container Quickstart
The SAS Viya programming run-time in a single container on the Docker platform. Includes SAS Studio, SAS Workspace Server, and the CAS server, which provides in-memory analytics. The CAS server allows for Symmetric Multi Processing (SMP) by users. Ideal for data scientists and programmers who want on-demand access and for ephemeral computing, where users should save code and store data in a permanent location outside the container. Run the container in interactive mode so that users can access the SAS Viya programming run-time or run the container in batch mode to execute SAS code on a scheduled basis.

**A [supported version](https://success.docker.com/article/maintenance-lifecycle) of Docker is required.**


### Build the Container
Run `./build.sh --zip ~/my/path/to/SAS_Viya_deploy_data.zip --addons "addons/auth-demo"` to create a user 'sasdemo' with the password 'sasdemo' for product evaluation.
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


---
---


# Multiple Containers
Build multiple Docker images of SAS Viya programming-only environments or other SAS Viya Visuals environments. Leverage Kubernetes to create the deployments, create SMP or MPP CAS, and run these environments in interactive mode.

### Prerequisites
- Python2 or Python3 and python-pip 
- **Access to a Docker registry**: The build process will push built Docker images automatically to the Docker registry. Before running `build.sh` do a `docker login docker.registry.company.com` and make sure that the `$HOME/.docker/config.json` is filled in correctly.
- [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) installed and access to a Kubernetes environment: The instructions here assume that you will be configuring an Ingress Controller to point to the `sas-viya-httpproxy` service. 
- A local mirror of the SAS software is **strongly recommended**. [Here's why](https://github.com/sassoftware/sas-container-recipes/wiki/The-Basics#why-do-i-need-a-local-mirror-repository). 

### Required `build.sh` Arguments
```    

        SAS Viya Programming example: 
            ./build.sh --type multiple --zip /path/to/SAS_Viya_deployment_data.zip --addons "addons/auth-demo"

        SAS Viya Visuals example: 
            ./build.sh --type full --docker-registry-namespace mynamespace --docker-registry-url my-registry.docker.com --zip /my/path/to/SAS_Viya_deployment_data.zip
        

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

### After running `build.sh`
* For a SAS Viya Programming deployment the Kubernetes manifests are located at `viya-programming/viya-multi-container/working/manifests/kubernetes`
* For a SAS Viya Visuals deployment the Kubernetes are located at `viya-visuals/working/manifests/kubernetes/**[deployment-smp OR deployment-mpp]**`

Choose between Symmetric Multi Processing (SMP) or Massively Parallel Processing (MPP) and run a `kubectl create --file` or `kubectl replace --file` on those manifests 

Then add hosts to your Kubernetes Ingress for `sas-viya-httpproxy` and other services using `kubectl edit ingress`:
```

    EXAMPLE

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

