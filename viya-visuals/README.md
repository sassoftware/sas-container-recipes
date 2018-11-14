# SAS Viya Cluster Deployment
Using containers to build, customize, and deploy a SAS environment in Kubernetes based on your software order.

## Getting Started

#### Install a maintained version of docker-ce
See the official Docker Community Edition install steps: https://docs.docker.com/install/linux/docker-ce/centos/

### Start a private Docker Registry
This will be the location that your Kubernetes pulls images from. 
You must first authenticate with your docker registry using `docker login <my-registry>.mydomain.com`. This will prompt you for a username and password (with LDAP if configured) and a file at ~/.docker/config.json is created to store that credential.
For details steps see the official Docker site: https://docs.docker.com/registry/deploying/

#### Raise the timeout period for Docker
`echo 'ENV DOCKER_CLIENT_TIMEOUT=600' >> /usr/lib/python2.7/site-packages/ansible_container-0.9.2-py2.7.egg/container/docker/templates/conductor-local-dockerfile.j2`

#### Install Ansible Container for running the build steps
`pip install ansible-container` 
If you're using a virtual environment then see the instructions [on our wiki](https://github.com/sassoftware/sas-container-recipes/wiki).

#### Install Kubernetes
See the official Kubernetes site: https://kubernetes.io/docs/tasks/tools/install-kubectl/

### Build
Download this repository to use the build script. `git clone https://github.com/sassoftware/sas-container-recipes.git`

The `build.sh` tool creates Docker images from your software order, pushes them to your docker registry, and creates Kubernetes deployment files. Define some variables that point to your Software Order Email zip file, your Docker registry location, and your Docker registry namespace:

```
./build.sh --zip /my/path/to/SAS_Viya_deployment_data.zip --docker-url <my-registry-url> --docker-namespace <my-namespace>
```

### Deploy
Kubernetes files are automatically placed into the `deploy/` directory. 
```
kubectl create -f deploy/configmap/
kubectl create -f deploy/secrets/
kubectl create -f deploy/deployments/
```

## Documentation
Check out our [Wiki](https://github.com/sassoftware/sas-container-recipes/wiki) for specific details.
Have a quick question? Open a ticket in the "issues" tab to get a response from the maintainers and other community members. If you're unsure about something just submit an issue anyways. We're glad to help!
If you have a specific license question head over to the [support portal](https://support.sas.com/en/support-home.html).

# License
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
