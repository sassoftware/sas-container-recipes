# SAS Viya Cluster Deployment
Using containers to build, customize, and deploy a SAS environment in Kubernetes based on your software order.

## Getting Started

#### Install Ansible
RHEL/CentOS: `sudo yum install ansible`
Fedora: `sudo dnf install ansible`
Ubuntu: `sudo apt-get install ansible`

#### Setup the Environment
Clone this repository using `git clone https://github.com/sassoftware/sas-container-recipes.git` then run `sudo ansible-playbook setup` inside this project directory.

This will install kubernetes, docker-ce, start a python virtual environment, and install all ansible-container dependencies inside.

### Start a private Docker Registry
This will be the location that your Kubernetes pulls images from.

For details steps see the official Docker site: https://docs.docker.com/registry/deploying/

### Build
The `build.sh` tool creates Docker images from your software order, pushes them to your docker registry, and creates Kubernetes deployment files. Define some variables that point to your Software Order Email zip file, your Docker registry location, and your Docker registry namespace:

```
./build.sh --zip /my/path/to/SAS_Viya_deployment_data.zip --docker-url <my-registry-url> --docker-namespace <my-namespace>
```

### Deploy
Kubernetes files are automatically placed into the `deploy/` directory. To import the resources for deployment:
```
kubectl create --recursive --filename deploy/kubernetes/secrets
kubectl create --recursive --filename deploy/kubernetes/configmaps
kubectl create --recursive --filename deploy/kubernetes/ [smp] OR [mpp]
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
