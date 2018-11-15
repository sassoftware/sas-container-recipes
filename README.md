# SAS for Containers: Recipes
This repository contains a collection of recipes and other resources for building containers that include the SAS Viya software and other tools.

- [/all-in-one](all-in-one/README.md) creates a SAS Viya programming-only analytic container from one Dockerfile for convenience and simplicity. This recipe, which was presented at SAS Global Forum 2018, includes SAS Studio, R Studio, and Jupyter Lab.
- [/viya-programming](viya-programming/README.md) is a folder that includes a recipe and resources for creating SAS Viya 3.4 programming-only Docker images.
- [/addons](addons/README.md) contains recipes and resources that enhance the base SAS Viya software, such as configuration of SAS/ACCESS software and integration with LDAP.
- [/utilities](utilities/README.md) contains resources that can be used to customize Docker images of SAS Viya software.
- A [build script](#use-buildsh-to-build-the-images) that you can use to create a container image that includes the SAS Viya software and addon layers.

## Prerequisites
### SAS Software

SAS Viya 3.4 software: a SAS Viya 3.4 on Linux order and the SAS_Viya_deployment_data.zip from the Software Order Email (SOE) are required.

**Important:** It is strongly recommended that you create a local mirror repository of the SAS Viya software, which can save you time and protect you from download limits. Each time that you build an image of the SAS Viya software, the required RPM files must be accessed. Setting up a local mirror repository for the RPM files can save time because you access the RPM files locally each time that you build or rebuild an image. If you do not create a local mirror repository, then the RPM files are downloaded from servers that are hosted by SAS, which can take longer. Also, there is a limit to how many times that you can download a SAS Viya software order from the SAS servers. For more information about creating a local mirror repository, see [Create a Mirror Repository](https://go.documentation.sas.com/?docsetId=dplyml0phy0lax&docsetTarget=p1ilrw734naazfn119i2rqik91r0.htm&docsetVersion=3.4) in the SAS Viya for Linux: Deployment Guide.

To include any future updates of the SAS Viya 3.4 software, you must rebuild recipes with the updated SAS Viya 3.4 software that is available from the SAS servers, or from a local mirror repository of the updated software.

### Other Software

- A [supported version](https://success.docker.com/article/maintenance-lifecycle) of Docker is required.
- Git is required.

### Clone the Repository

Here is an example of the `git clone` command for a Linux host that has Git and Docker installed. 
The command assumes that you will clone the repository in the $HOME directory.

```
cd $HOME
git clone https://github.com/sassoftware/sas-container-recipes.git
```

**Note:** On Windows, you can clone the repository by using PowerShell. Also, you can clone the repository on a Mac.

## Use build.sh to Build the Images

A script named `build.sh` is at the repository root level. After the sassoftware/sas-container-recipes project is cloned, run `build.sh` to build a set of Docker images for SAS Viya 3.4.

The following example assumes that you are in the 
/$HOME/sas-container-recipes directory, a mirror repository is set up at `http://host.company.com/sas_repo`, and an addon layer, [auth-demo](addons/auth-demo/README.md), is included in the build.

```
cp /path/to/SAS_Viya_deployment_data.zip viya-programming/viya-single-container
export SAS_RPM_REPO_URL=http://host.company.com/sas_repo
build.sh addons/auth-demo
```

To use a mirror repository, you must access it through an HTTP server. If you do not have an HTTP server, you can start a simple one:
  
```
cd ~/sas_repo
nohup python -m SimpleHTTPServer 8123 &
```

After you start the HTTP server, you can pass the following parameter as input to the build:

```
export SAS_RPM_REPO_URL=http://$(hostname -f):8123/
```

**Notes:**

- The auth-demo addon sets up a demo user, which allows you to log on to SAS Studio after the container is running. No additional configuration is required before using the auth-demo addon.
- You can include multiple [addons](addons/README.md) with the `build.sh` command. Here is an example that includes three addons:

  ```
  build.sh addons/auth-demo addons/ide-jupyter-python3 addons/access-pcfiles
  ```
- Some addons require additional configuration before they can be used with the `build.sh` command. For example, the [access-hadoop](addons/access-hadoop/README.md) addon requires Hadoop configuration and JAR files to be in a specific location. To understand if additional configuration is required, see the respective README file for each addon. 
- Running `build.sh` prints to the console and to a file named build_sas_container.log. 

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

## Start the Container

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

# Check the status
docker ps --filter name=sas-viya-programming --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}} \t{{.Ports}}"
CONTAINER ID        NAMES                   IMAGE                   STATUS              PORTS
4b426ce49b6b        sas-viya-programming    sas-viya-programming    Up 2 minutes        0.0.0.0:8081->80/tcp, 0.0.0.0:33221->443/tcp, 0.0.0.0:33220->5570/tcp    
```

After the container has started, log on to SAS Studio with the user name `sasdemo` and the password `sasdemo` at:
 
 http://_host-name-where-docker-is-running_:8081

 **Note:** The user name `sasdemo` and the password `sasdemo` are the credentials for the demo user that is set up by the auth-demo addon. 

## Troubleshooting
### Errors When Building the Docker Image
#### ERRO[0000] failed to dial gRPC: cannot connect to the Docker daemon

For Linux hosts, make sure that the Docker daemon is running: 

```
sudo systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2018-08-08 06:57:53 EDT; 1 months 12 days ago
     Docs: https://docs.docker.com
 Main PID: 24833 (dockerd)
    Tasks: 104
```

If the process is running, then you might need to run the Docker commands using sudo. For information on running the Docker commands without using sudo, see the [Docker documentation](https://docs.docker.com/v17.12/install/linux/linux-postinstall/).

#### COPY failed: stat /var/lib/docker/tmp/docker-builderXXXXXXXXXX/\<file name\>: no such file or directory

The `docker build` command expects a Dockerfile and a build "context," which is a set of files in a specified path or URL. If the files are not present, the Docker build will display the error
message. To resolve it, make sure that the files are in the directory where the Docker build takes place.

**Notes:**

- For this project, the build context is where the files are copied from. In the examples,  `.` represents the build context.  
- In some recipes, the user is expected to copy the files into the current directory before running the `docker build` command. For example, copying files is required for building the [viya-single-container](viya-programming/viya-single-container/README.md) image and some of the 
[addon](addons/README.md) images.

#### Ansible Playbook Fails 

This error might indicate that Docker is running out of space on the host where the Docker
daemon is running. To find out if more space is needed, look in the Ansible output for a message similar to the following example:

```
        "Error Summary",
        "-------------",
        "Disk Requirements:",
        "  At least 6344MB more space needed on the / filesystem."
```

If more space is needed, try pruning the Docker system:

```
docker system prune --force --volumes
```

If the error persists after the pruning, check to see if the Device Mapper storage driver is used:

```
docker system info 2>/dev/null | grep "Storage Driver"
```

If the output is _Storage Driver: devicemapper_, then the Device Mapper storage driver is used. The Device Mapper storage driver has a default layer size of 10 GB, and the SAS Viya 
image is typically larger. Possible workarounds to free up space are to change the layer size or to switch to
the [overlay2 storage driver](https://docs.docker.com/storage/storagedriver/overlayfs-driver/).


### Warnings When Building the Docker Image
#### warning: /var/cache/yum/x86_64/7/**/*.rpm: Header V3 RSA/SHA256 Signature, key ID \<key\>: NOKEY

It is safe to ignore this warning. This warning indicates that the Gnu Privacy Guard (gpg) key is not available on the host, and it is followed by a call to retrieve the missing key.

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
