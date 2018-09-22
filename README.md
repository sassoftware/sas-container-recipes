# Background
A collections of recipes for building containers with SAS and other tools.

* [viya-programming](viya-programming/README.md) is a set of tools for creating SAS Viya 3.4 containers.
* [addons](addons/README.md) is a set of tools for adding to the SAS Viya 3.4 containers.
* [utilities](utilities/README.md) is a set of files that can be used when creating SAS Viya 3.4 containers.
* [all-in-one](all-in-one/README.md) is a set of tools for creating a SAS Viya 3.3 single container, for convenience and simplicity for the person using said container.

# Prerequisites

* A SAS order and the SAS_Viya_deployment_data.zip from the Software Order Email (SOE)
* A [supported version](https://success.docker.com/article/maintenance-lifecycle) of Docker(https://www.docker.com/)
* Git

# How to clone from github

These examples are for a linux host that has git and docker installed.  
This can be done on Windows (with Powershell), and on a Mac too. 
To keep the example simple, we'll put the cloned folder in your $HOME directory.

```
cd $HOME
git clone https://github.com/sassoftware/sas-container-recipes.git
```

# How To Quickly Build a Viya 3.4 Image

At the root level there is a script called _build.sh_. Once a user has cloned
the _sassoftware/sas-container-recipes_ project, one can run _build.sh_ to 
quickly build a set of Docker images that represent a Viya 3.4 image and a 
Viya 3.4 image with a default user. The following assumes that you are in the 
/$HOME/sas-container-recipes directory.

```
cp /path/to/SAS_Viya_deployment_data.zip viya-programming/viya-single-container
build.sh addons/auth-demo
```

Running build.sh will print what is happening to the console as well as to a file
named _build_sas_container.log_. Once everything is built, looking at the available
docker images we should see something like

```
REPOSITORY                                 TAG                 IMAGE ID            CREATED             SIZE
svc-auth-demo                              latest              965b522a213d        21 hours ago        8.52GB
viya-single-container                      latest              2351f556f15a        2 days ago          8.52GB
centos                                     latest              5182e96772bf        6 weeks ago         200MB
```

Note that the size of the _viya-single-container_ varies depending on your order.
Also, there are not two images each with a size of 8.52 GB on the system. The two
images are made from the same set of layers with the _svc-auth-demo_ image having
some layers added to the image.

# Frequently Asked Questions
## Errors when building the Docker image
### ERRO[0000] failed to dial gRPC: cannot connect to the Docker daemon

For Linux hosts, make sure the Docker daemon is running. 

```
sudo systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2018-08-08 06:57:53 EDT; 1 months 12 days ago
     Docs: https://docs.docker.com
 Main PID: 24833 (dockerd)
    Tasks: 104
```

If the process is running, then one may need to execute the Docker commands with
_sudo_. To remove the need for _sudo_, see the [post install instructions](https://docs.docker.com/v17.12/install/linux/linux-postinstall/)
provided by Docker.

### COPY failed: stat /var/lib/docker/tmp/docker-builderXXXXXXXXXX/\<file name\>: no such file or directory

Dockerfiles will attempt to copy files from directory where the current directory.
In some cases the user is expected to copy files into the current directory. This
is needed for building the _viya-single-container_ image as well as some of the 
addons. If the file is not present, the Docker build process will have an error
message like the title of this section. To resolve it, make sure the file that is
needed resides in the directory where the _docker build_ is taking place.

### Ansible playbook fails 

Usually this will be due to Docker running out of space on the host where the Docker
daemon is running. Look back through the Ansible output and see if there is a message
like

```
        "Error Summary",
        "-------------",
        "Disk Requirements:",
        "  At least 6344MB more space needed on the / filesystem."
```

If this is happening, try pruning the Docker system

```
docker system prune --force --volumes
```

Even after pruning, if this error persists, double check the storage driver for Docker:

```
docker system info 2>/dev/null | grep "Storage Driver"
```

If the returning value is _Storage Driver: devicemapper_ then this could be the 
source of the issue. _devicemapper_ has a default layer size of 10 GB and the SAS
image is usually bigger than this limit. One can try to change the size or switch to
the [overlay2 driver](https://docs.docker.com/storage/storagedriver/overlayfs-driver/).


## Warnings when building the Docker image
### warning: /var/cache/yum/x86_64/7/**/*.rpm: Header V3 RSA/SHA256 Signature, key ID \<key\>: NOKEY

This is indicating that the Gnu Privacy Guard (gpg) key is not available on the host. 
When seeing this message, it is followed by a call to retrieve the missing key.
It is safe to ignore this warning.

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
