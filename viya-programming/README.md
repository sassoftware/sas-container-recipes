# SAS Viya Programming Quickstart
### For SAS Viya 3.4 Linux orders
Made for independent data scientists who want to run small projects in a quick SAS Studio + CAS (Cloud Analytic Services) environment. This creates a single Docker image that you can run locally on your own machine. If you require Massive Parallel Processing (MPP) then see the top level `viya-visuals` directory for details on deploying with Kubernetes.

# Getting Started
```
cd $HOME/sas-container-recipes/viya-programming/viya-single-container
cp /path/to/SAS_Viya_deployment_data.zip .
sed -i 's|^COPY sas_viya_playbook|#COPY sas_viya_playbook|g' Dockerfile
```

```
docker build . --tag sas-viya-programming-single

OPTIONAL: --build-arg BASEIMAGE=<name of base image>
example: 
    docker build --file Dockerfile--build-arg BASEIMAGE=docker.company.com/rh/rhvariance --build-arg BASETAG=7.2 . --tag viya-single-container

```

## Validation
To check that all the services are started:

```docker run --detach --publish-all --rm --name viya-single-container --hostname viya-single-container viya-single-container```

```
# There should be three services and status should be 'up'
docker exec --interactive --tty viya-single-container /etc/init.d/sas-viya-all-services status
  Service                                            Status     Host               Port     PID
  sas-viya-cascontroller-default                     up         N/A                 N/A     607
  sas-viya-sasstudio-default                         up         N/A                 N/A     386
  sas-viya-spawner-default                           up         N/A                 N/A     356

sas-services completed in 00:00:00
```

## Customization

## Creating an Image with the sasdemo user
```
cd /path/to/sassoftware/sas-container-recipes/addons/auth-demo
docker build -f Dockerfile . -t svc-auth-demo
docker run --detach --publish-all --rm --name svc-auth-demo --hostname svc-auth-demo svc-auth-demo
```

## Creating an Image with Jupyter Notebook
```
cd /path/to/sassoftware/sas-container-recipes/addons/ide-jupyter-python3
docker build -f Dockerfile --build-arg BASEIMAGE=svc-auth-demo . -t svc-ide-jupyter-python3
docker run --detach --publish-all --rm --name svc-ide-jupyter-python3 --hostname svc-ide-jupyter-python3 svc-ide-jupyter-python3
```

## Override Default Configurations
After the Docker build you can apply different configurations to the SAS Workspace Server or to CAS. Create a directory called `sasinside` and create any of the following files inside the newly created directory:
* casconfig_usermods.lua
* cas_usermods.settings
* autoexec_usermods.sas
* sasv9_usermods.cfg
* batchserver_usermods.sh
* workspaceserver_usermods.sh
* sasstudio_usermods.properties

Then start the container with the newly created directory mounted as a volume:
```
docker run --detach --publish-all --rm --volume /my/path/to/sasinside:/sasinside --name viya-single-container --hostname viya-single-container viya-single-container
```

The image will symlink the files at the /sasinside directory to the location that the SAS and CAS software expects to find them, which allows future changes without having to stop container. New sessions will pick up the changes.

# Copyright

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
