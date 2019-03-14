## Contents

- [Configuration](#configuration)
  - [Ansible Overrides](#ansible-overrides)
  - [Running Using Configuration by Convention](#running-using-configuration-by-convention)
  - [Running using Environment Variables](#running-using-environment-variables)
  - [Precedence](#precedence)
- [How to Build](#how-to-build)
  - [Overview](#overview)
  - [Building on a Red Hat Enterprise Linux Image](#building-on-a-red-hat-enterprise-linux-image)
  - [Building on a SUSE Linux Image](#building-on-a-suse-linux-image)
  - [Advanced Building Options](#advanced-building-options)
  - [Logging](#logging)
  - [Errors During Build](#errors-during-build)
- [How to Run](#how-to-run)
  - [Docker](#docker)
  - [Enabling SSL/TLS](#enabling-ssltls)
  - [SAS Batch Server](#sas-batch-server)
  - [Kubernetes](#kubernetes)

## Configuration

Before we build the images, here is some information about the different ways that you can modify the configuration of the image.

### Ansible Overrides
If you are familiar with SAS Viya configuration and would like to make configuration settings for the SAS Programming Runtime Environnment (SPRE) or the Cloud Analytics Server (CAS) that will be applied to the image when it is being created, edit the `viya-programming/viya-single-container/vars_usermods.yml` file. In the _vars_usermods.yml_ you can add and fill in any of the following content and it will customize the configuration of the container:

```
# The following is the initial Admin user for use with CAS Server Monitor. 
# This is the user you will log into CAS Server Monitor with
# in order to create global CAS libs and set access rights.
# If not set, the casenv_user will be used by default.
# If all defaults are taken, the "cas" user will not have a password
# defined for it. To have one created by the deployment process,
# review how to define a password as documented with the sas_users
# collection above.

#casenv_admin_user: 


#### CAS Specific ####
# Anything in this list will end up in the cas.settings file
#CAS_SETTINGS:
   #1: ODBCHOME=ODBC home directory
   #2: ODBCINI=$ODBCHOME/odbc.ini
   #3: ORACLE_HOME=Oracle home directory
   #4: JAVA_HOME=/usr/lib/jvm/jre-1.8.0
   #5: LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$ORACLE_HOME/lib:$JAVA_HOME/lib/amd64/server:$ODBCHOME/lib

# Anything in this list will end up in the casconfig.lua file
#   The env section will create a env.VARIABLE in the file
#     Example: env.CAS_DISK_CACHE = '/tmp'
#   The cfg section will create a cas.variable in the file
#     Example: cas.port = 5570
#
# If you have defined hosts for the sas-casserver-worker then the MODE will
# automatically be set to 'mpp'. If the environment variables HADOOP_HOME and 
# HADOOP_NAMENODE are set, the COLOCATION option will automatically equal 'hdfs'.
# If HADOOP_HOME and HADOOP_NAMENODE are not set, then the COLOCATION option 
# will automatically equal 'none'.

CAS_CONFIGURATION:
   env:
     #CAS_DISK_CACHE: /tmp
     #CAS_VIRTUAL_HOST: 'loadbalancer.company.com'
     #CAS_VIRTUAL_PROTO: 'https'
     #CAS_VIRTUAL_PORT: 443
   cfg:
     #gcport: 0
     #httpport: 8777
     #port: 5570
     #colocation: 'none'
     #SERVICESBASEURL: 'https://loadbalancer.company.com'

############################################################################
## Foundation Configuration
############################################################################

# Optional: Will use the CAS controller host as defined in the inventory
#           file. If one is not defined it will default to localhost.
#           If you know the host of the controller you want to connect to,
#           provide that here
#sasenv_cas_host:

# Optional: If a value is not provided, the system will use the CAS port
#           as defined for the CAS controller.
#           If you know the port of the grid you want to connect to,
#           provide that here.
#sasenv_cas_port:

# Set the ports that SAS/CONNECT will listen on
#sasenv_connect_port: 17551
#sasenv_connect_mgmt_port: 17541

# Updates the init_deployment.properties and appserver_deployment.sh
STUDIO_CONFIGURATION:
  init:
    #sasstudio.appserver.port_comment: '# Port that Studio is listening on'
    #sasstudio.appserver.port: 7080
    #sasstudio.appserver.https.port: 7443
    #webdms.workspaceServer.hostName: localhost
    #webdms.workspaceServer.port: 8591
  appserver:
    #1: '# Comment about KEY'
    #2: KEY="value with spaces"

# Updates spawner.cfg
SPAWNER_CONFIGURATION:
  #sasPort: 8591

# Updates the workspaceserver autoexec_deployment.sas
#WORKSPACESERVER_CONFIGURATION:
  #1: '/* Comment about key */'
  #2: key=value;

# Creates a workspaceserver sasenv_deployment file
#FOUNDATION_CONFIGURATION:
  #1: '# Comment about KEY'
  #2: KEY=value

# Creates a workspaceserver sasv9_deployment.cfg file
#SASV9_CONFIGURATION:
  #1: '/* Comment about OPTION */'
  #2: 'OPTION value'
```

### Running Using Configuration by Convention
You can provide configuration files that the container will process as it starts. To accomplish this task, map a volume to `/sasinside` in the container. The contents of that directory would contain any of the following files:

* casconfig_usermods.lua
* cas_usermods.settings
* casstartup_usremods.lua
* autoexec_usermods.sas
* sasv9_usermods.cfg
* batchserver_usremods.sh
* connectserver_usremods.sh
* workspaceserver_usremods.sh
* sasstudio_usermods.properties

If any of these files are found, then the contents are appended to the existing usermods file. A change to the files in the `/sasinside` directory would not change the behavior of a running system. Only on a restart would the behavior change.

### Running Using Environment Variables
For CAS, you can change the configuration of the container by using environment variables. The CAS container will look for environment variables of a certain prefix:

* CASCFG_ - An environment variable with this prefix translates to a `cas.` option which ends up in the `casconfig_docker.lua` file. These values are a predefined set and cannot be made up. If CAS sees an option that it does not understand, it will not run.
* CASENV_ - An environment variable with this prefix translates to a `env.` option which ends up in the casconfig_docker.lua. These values can be anything.
* CASSET_ - An environment variable with this prefix translates to an environment variable which ends up in `cas_docker.settings`. These values can be anything.
* CASLLP_ - An environment variable with this prefix translates to setting the _LD_LIBRARY_PATH_ in `cas_docker.settings`. These values can be anything.

### Precedence
Here is the order of precedence from least to greatest (the last listed variables winning prioritization):

* vars.yml from the playbook
* vars_usermods.yml
* files from `/tmp`
* files from `/sasinisde`
* environment variables

## How to Build

### Overview

Use the `build.sh` script in the root of the directory: `sas-container-recipes/build.sh`. You will be able to pass in the base image and tag that you want to build from as well as providing any addons to create your custom image. The following examples use a mirror URL, which is [strongly recommended](Tips#create-a-local-mirror-repository).

To see what options `build.sh` takes, run 

```
build.sh --help
```

For single-container, the _addons_, _baseimage_, _basetag_, _mirror-url_, _platform_, type and _zip_ options are used. The _zip_ file will be copied to `viya-programming/viya-single-container/` so the Docker build process can use it.

For information on how to manually build as well as add on layers, see [Advanced Building Options](#advanced-building-options).

### Building on a Red Hat Enterprise Linux Image

The following example pulls down the most recent "CentOS:7" image from DockerHub, and then adds the `addons/auth-sssd` and  `addons/access-odbc` layers once the main SAS image is built. If more addons are desired, add to the space delimited list and make sure that the list is encapsulated in double quotes.

To change the base image from which we will build the SAS image to any Red Hat 7 variant, change the values for the `--baseimage` and `--basetag` options. Only Red Hat Enterprise Linux 7 based images are supported for recipes. If the `--baseimage` and `--basetag` options are not provided then _centos:latest_ from DockerHub will be used.

```
build.sh \
--type single \
--baseimage centos \
--basetag 7 \
--zip /path/to/SAS_Viya_deployment_data.zip \
--mirror-url http://host.company.com/sas_repo \
--addons "addons/auth-sssd addons/access-odbc"
```

### Building on a SUSE Linux Image

The following example pulls down the "opensuse/leap:42" image from DockerHub, and then adds the `addons/auth-sssd` and  `addons/access-odbc` layers once the main SAS image is built. If more addons are desired, add to the space delimited list. Make sure that the list is encapsulated in double quotes.

To change the base image from which we will build the SAS image to any SUSE variant, change the values for the `--baseimage` and `--basetag` options. Right now _opensuse/leap_ with tags _42.*_ is supported.

```
build.sh \
--type single \
--baseimage opensuse/leap \
--basetag 42 \
--zip /path/to/SAS_Viya_deployment_data.zip \
--mirror-url http://host.company.com/sas_repo \
--addons "addons/auth-sssd addons/access-odbc"
```

### Advanced Building Options
#### Running Docker build

If you want to run the Docker build on your own, navigate to the `viya-programming/viya-single-container` directory and run

```
docker build \
--file Dockerfile \
--build-arg BASEIMAGE=centos \
--build-arg BASETAG=7 \
--build-arg PLATFORM=redhat \
. \
--tag viya-single-container
```

The result will create a Docker image tagged as `viya-single-container:latest`

To change the base image, change the _BASEIMAGE_ and _BASETAG_ options. If using a SuSE based operating system, make sure to set `PLATFORM=suse`.  

#### Extending the Base Image

To add to the base image, change into any of the subdirectories and run a build 
with the provided Dockerfile. Below are examples of adding the _sasdemo_ user to 
the initial image and then adding the Jupyter with python3 support to the 
_svc-auth-demo_ image. 

__Note:__ Unless a custom base image is provided that already
supports host level authentication, the addons/auth-sssd 
or addons/auth-demo layers will need to be 
added in order to support full functionality of the SAS Viya container.

##### To Create an Image with the sasdemo User

```
cd /path/to/sassoftware/sas-container-recipes/addons/auth-demo
docker build --file Dockerfile . --tag svc-auth-demo
docker run --detach --publish-all --rm --name svc-auth-demo --hostname svc-auth-demo svc-auth-demo
```

##### To Create an Image with Jupyter Notebook
```
cd /path/to/sassoftware/sas-container-recipes/addons/ide-jupyter-python3
docker build --file Dockerfile --build-arg BASEIMAGE=svc-auth-demo . --tag svc-ide-jupyter-python3
docker run --detach --publish-all --rm --name svc-ide-jupyter-python3 --hostname svc-ide-jupyter-python3 svc-ide-jupyter-python3
```

### Logging

The content that is displayed to the console when building is also captured in a log file named `${PWD}/logs/build_sas_container.log`. If a log file exists at the time of the run, the previous file is preserved with a name of `build_sas_container_<date-time stamp>.log`. If problems are encountered during the build process, review the log file or provide it when opening up tickets.

### Errors During Build

If there was an error during the build process there is a chance some intermediate build containers were left behind. To see any images that are a result of the SAS recipe build process, run:

`docker images --filter "dangling=true" --filter "label=sas.recipe.version"`

If you encounter any of these you can remove these images by running:

`docker rmi $(docker images -q --filter "dangling=true" --filter "label=sas.recipe.version")`

The command between the parentheses returns the image ids that meet the filter and then will remove those images.

See the Docker documentation for more options on cleaning up your build system. Here are some specific topics:

- To remove all unused data, see [docker system prune](https://docs.docker.com/engine/reference/commandline/system_prune/).
- To remove images, see [docker image rm](https://docs.docker.com/engine/reference/commandline/image_rm/).

## How to Run

### Docker

In the root of the directory there is a _samples_ directory that provides a sample script that does a `docker run` of the single container. To use this script, copy and edit the file so it matches your environment. The following assumes that you know the tag value that you would like to use. Replace `<tag>` with the actual value.

```
mkdir -p ${PWD}/run
cp samples/viya-single-container/example_launchsas.sh ${PWD}/run/launchsas.sh
sed -i 's/@REPLACE_ME_WITH_TAG@/<tag>/' ${PWD}/run/launchsas.sh
cd run
```

When the script is run, it will create several directories for you. These are setup either to persist data or to help with [configuration](#configuration). 

```
mkdir -p ${PWD}/sasinside      # Configuration
mkdir -p ${PWD}/sasdemo        # In some cases persist user data
mkdir -p ${PWD}/cas/data       # Persist CAS data
mkdir -p ${PWD}/cas/cache      # Allow for writing temporary files to a different location
mkdir -p ${PWD}/cas/permstore  # Persist CAS permissions
```

Create the container:

```
./launchsas.sh
```

Check that all the services are started (there should be three services and status should be 'up'):

```
docker exec --interactive --tty sas-programming /etc/init.d/sas-viya-all-services status
  Service                                            Status     Host               Port     PID
  sas-viya-cascontroller-default                     up         N/A                 N/A     607
  sas-viya-sasstudio-default                         up         N/A                 N/A     386
  sas-viya-spawner-default                           up         N/A                 N/A     356

sas-services completed in 00:00:00
```

At this point both `http://docker-host` is reachable.

#### Enabling SSL/TLS
A certificate and key can be passed into the Docker image to encrypt traffic between the single container and the client.

Example:
```
docker run --interactive --tty \
--volume /my/path/to/casigned.cer:/etc/pki/tls/certs/casigned.cer \
--volume /my/path/to/servertls.key:/etc/pki/tls/private/servertls.key \
--env SSL_CERT_NAME=casigned.cer \
--env SSL_KEY_NAME=servertls.key \
--env CASENV_CAS_VIRTUAL_HOST=myhostname \
--env CASENV_CAS_VIRTUAL_PORT=8443 \
--hostname sas-viya-programming \
--publish 8443:443 \
--name viya-single-container \
viya-single-container:latest
```

- `SSL_CERT_NAME` must be the file name of your certificate signed by the Certificate Authority.
- `SSL_KEY_NAME` must be the file name of your key.
- The file provided by `--volume /my/path/to/casigned.cer` is placed inside the container in the /etc/pki/tls/certs/ directory so that it can be used by the HTTPD SSL configuration.
- The file provided by `--volume /my/path/to/servertls.key` is placed inside the container in the /etc/pki/tls/private/ directory so that it can be used by the HTTPD SSL configuration.
- HTTPS runs on port 8443 and is published by using the `--publish 8443:443` argument in the Docker run command

### SAS Batch Server

The container can be run using the SAS batch server. The expectation is that the SAS program is not in the container and will be made available to the container
at run time.

This example is expecting that there is a _/sasinside_ directory on the Docker host that has the SAS program. When the container is started we will mount the _sasiniside_ directory to the container so that the code can be run:

```
docker run \
--interactive \
--tty \
--rm \
--volume ${PWD}/sasinside:/sasinside \
sas-viya-programming:<tag> \
--batch /sasinside/sasprogram.sas
```

Here is an example running a sample program that just does 'proc javainfo; run;'
```
docker run --interactive --tty --rm --volume ${PWD}/sasinside:/sasinside sas-viya-programming:<tag> --batch /sasinside/javainfo.sas

removed '/opt/sas/viya/config/var/log/all-services/default/all-services_2018-08-31_13-51-24.log'
removed '/opt/sas/viya/config/var/log/all-services/default/all-services_2018-08-31_13-41-36.log'
removed '/opt/sas/viya/config/var/log/cas/default_audit/cas_2018-08-31_e8c8ab0df875_6748.log'
removed '/opt/sas/viya/config/var/log/connect/default/ConnectSpawner_2018-08-31_e8c8ab0df875_16491.log'
removed '/opt/sas/viya/config/var/log/connect/default/connectspawner_console_2018-08-31_13-20-11.log'
removed '/opt/sas/viya/config/var/log/connect/default/register_connect.log'
removed '/opt/sas/viya/config/var/log/connect/default/unregister_connect.log'
removed '/opt/sas/viya/config/etc/sysconfig/cas/default/cas_grid_vars'
[INFO] : CASENV_CAS_VIRTUAL_HOST is 'localhost'
[INFO] : CASENV_CAS_VIRTUAL_PORT is '443'
[INFO] : CASENV_ADMIN_USER is 'sasdemo'
Sourcing /opt/sas/viya/home/share/cas/docconvjars.cascfg
removed '/opt/sas/viya/config/etc/cas/default/start.d/05updateperms_startup.lua'
Running "exec --batch /sasinside/javainfo.sas"
Starting Cloud Analytic Services...
CAS Consul Health:
    Consul not present
    CAS bypassing Consul serfHealth status check of CAS nodes

/sasinside /tmp/demo_auth
sourcing /opt/sas/viya/config/etc/sysconfig/sas-javaesntl/sas-java

1                                                          The SAS System                        Friday, August 31, 2018 05:31:00 PM
NOTE: Copyright (c) 2016 by SAS Institute Inc., Cary, NC, USA.
NOTE: SAS (r) Proprietary Software V.03.04 (TS4M0 MBCS3170)
      Licensed to lots o stuff, Site 70180938.
NOTE: This session is executing on the Linux 3.10.0-693.el7.x86_64 (LIN X64) platform.

NOTE: Analytical products:

      SAS/STAT 14.3
      SAS/ETS 14.3
      SAS/OR 14.3
      SAS/IML 14.3
      SAS/QC 14.3

NOTE: Additional host information:

 Linux LIN X64 3.10.0-693.el7.x86_64 #1 SMP Thu Jul 6 19:56:57 EDT 2017 x86_64 CentOS Linux release 7.5.1804 (Core)

NOTE: SAS initialization used:
      real time           0.28 seconds
      cpu time            0.03 seconds

NOTE: AUTOEXEC processing beginning; file is /opt/sas/viya/config/etc/batchserver/default/autoexec.sas.

NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds

NOTE: AUTOEXEC processing completed.

1          proc javainfo; run;

PFS_TEMPLATE = /opt/sas/spre/home/SASFoundation/misc/tkjava/qrpfstpt.xml
java.class.path = /opt/sas/spre/home/SASFoundation/lib/base/base-tkjni.jar
java.class.version = 52.0
java.runtime.name = OpenJDK Runtime Environment
java.runtime.version = 1.8.0_181-b13
java.security.auth.login.config = /opt/sas/spre/home/SASFoundation/misc/tkjava/sas.login.config
java.security.policy = /opt/sas/spre/home/SASFoundation/misc/tkjava/sas.policy
java.specification.version = 1.8
java.vendor = Oracle Corporation
java.version = 1.8.0_181
java.vm.name = OpenJDK 64-Bit Server VM
java.vm.specification.version = 1.8
java.vm.version = 25.181-b13
sas.ext.config = /opt/sas/spre/home/SASFoundation/misc/tkjava/sas.java.ext.config
user.country = US
user.language = en

NOTE: PROCEDURE JAVAINFO used (Total process time):
      real time           1.02 seconds
      cpu time            0.00 seconds

♀2                                                          The SAS System                        Friday, August 31, 2018 05:31:00 PM


NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414
NOTE: The SAS System used:
      real time           1.34 seconds
      cpu time            0.06 seconds

/tmp/demo_auth

Shutting down!

    Stop httpd
httpd (no pid file) not running
    Stop SAS services
```

The log should also be back on the Docker host in the _sasinside_ directory.

```
> ls -l sasinside/
total 72
-rw-r--r--. 1 root   root  2308 Aug 30 22:39 javainfo.log
-rw-r--r--. 1 user   users   20 Aug 28 17:44 javainfo.sas
```

### Kubernetes

Before you run the SAS Viya Programming image in Kubernetes, we need to push that image to a Docker registry that the Kubernetes environment has access to. We need to `docker tag` the image so that it matches the location of where we want to push the image. In the following examples, replace `docker.registry.com` and `/sas/` with the location of your Docker registry and the user space that you want the image to be pushed to:

```
docker tag sas-viya-programming:<tag> docker.registry.com/sas/sas-viya-programming:<tag>
```

Then we need to `docker push` the image so it gets into the Docker registry

```
docker push docker.registry.com/sas/sas-viya-programming:<tag>
```

Now with the image in the Docker registry, we can create a Kubernetes manifest in order to deploy the image. In the root of the directory there is a _samples_ directory that provides a sample Kubernetes manifest for the single container. To use this copy and edit the file so it matches your environment.

```
mkdir run
cp samples/viya-single-container/example_programming.yml run/programming.yml
vi run/programming.yml
```

In `samples/viya-single-container/programming.yml` find all occurrences of _@REPLACE_ME*@_ and replace that with the needed information. Also replace the line `contents-of-license-file` with the contents of the SAS license file. Make sure that spacing is honored after the contents are copied.

The manifest already defined several paths where data that needs to persist between restarts can be stored. By default these are set up to point to local storage that will disappear once the Kubernetes pod is deleted. Update this portion of the manifest to support how your site implements persistence storage. It is strongly suggested that your review [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) to understand what options are available. 

```
      volumes:
      - name: cas-volume
        emptyDir: {}
      - name: data-volume
        emptyDir: {}
#      - name: sasinside
#        nfs:
#          server: "server-name"
#          path: "path-to-mount"
```

Create the deployment. In this example, we are creating the SAS Programming container in the _sasviya_ Kubernetes namespace. For more information about _namespaces_, see [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/).

```
kubectl -n sasviya create -f run/programming.yml
```

In order to make sure things are running like we expect, we will need to list the pods and identify the sas-viya-prgramming pod:

```
kubectl -n sasviya get pods
[TODO show list of pods]
```

Check that all the services are started (there should be three services and status should be 'up'):

```
kubectl -n sasviya exec -it sas-viya-programming-<uuid> -- /etc/init.d/sas-viya-all-services status
  Service                                            Status     Host               Port     PID
  sas-viya-cascontroller-default                     up         N/A                 N/A     607
  sas-viya-sasstudio-default                         up         N/A                 N/A     386
  sas-viya-spawner-default                           up         N/A                 N/A     356

sas-services completed in 00:00:00
```

Depending on how ingress has been configured, either `http://ingress-path` or `https://ingress-path` are reachable. We will use the `https` URL going forward but if you did not configure the ingress for https, substitute http in the provided examples.

