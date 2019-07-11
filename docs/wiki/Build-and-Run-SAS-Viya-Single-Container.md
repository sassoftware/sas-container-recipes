## Contents

- [Optional Configuration](#optional-configuration)
  - [Using Custom Values to Override the Playbook Settings](#using-custom-values-to-override-the-playbook-settings)
  - [Using Configuration Files](#using-configuration-files)
  - [Using Environment Variables](#using-environment-variables)
  - [Order of Configuration](#order-of-configuration)
- [How to Build](#how-to-build)
  - [Overview](#overview)
  - [Building on a CentOS Image](#building-on-a-centos-image)
  - [Building on a SUSE Linux Image](#building-on-a-suse-linux-image)
  - [Advanced Building Options](#advanced-building-options)
  - [Logging](#logging)
  - [Errors During Build](#errors-during-build)
- [How to Run](#how-to-run)
  - [Using Docker](#using-docker)
    - [(Optional) Enabling SSL/TLS](#optional-enabling-ssltls)
    - [(Optional) Using SAS Batch Server](#optional-using-sas-batch-server)
  - [Using Kubernetes](#using-kubernetes)

## Optional Configuration

Before you build the images and run the container, read about the different ways that you can modify the configuration.

### Using Custom Values to Override the Playbook Settings
You can override the default configuration settings for the SAS Programming 
Runtime Environment (SPRE) and the SAS Cloud Analytic Services (CAS) server 
that are applied to the image when it is being created. To set these 
configuration values, copy the util/vars_usermods.yml file into the 
sas-container-recipes project directory, and then edit the values in the new copy.

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

### Using Configuration Files
You can provide configuration files that the container will process as it starts. To use configuration files, map a volume to the /sasinside directory in the container. The contents of that directory can include one or more of the following files:

* casconfig_usermods.lua
* cas_usermods.settings
* casstartup_usermods.lua
* autoexec_usermods.sas
* sasv9_usermods.cfg
* batchserver_usermods.sh
* connectserver_usermods.sh
* workspaceserver_usermods.sh
* sasstudio_usermods.properties

When the container starts, the content of each file is appended to the existing usermods file.

**Note:** A change to the files in the /sasinside directory does not change the configuration of a running system. A restart is required to change the configuration of a running system.

### Using Environment Variables
You can change the configuration of the CAS server by using environment variables. The CAS container will look for environment variables whose names are preceded by a particular prefix:

**CASCFG_**

This prefix indicates a _cas._ option, which is included in the casconfig_docker.lua file. These values are a predefined set and cannot be user-created. If an option is not recognized by the CAS server, it will not run.

**CASENV_**

This prefix indicates an _env._ option, which is included in the casconfig_docker.lua file.

**CASSET_**

This prefix indicates an environment variable that is included in the cas_docker.settings file.

**CASLLP_**

This prefix indicates setting the LD_LIBRARY_PATH variable in the cas_docker.settings file.

### Order of Configuration
The configuration of software follows the order of the methods (configuration files or environment variables) shown below, where the last method used sets the configuration:  

* vars.yml from the playbook
* vars_usermods.yml (override the playbook settings)
* files in the /tmp directory
* files in the /sasinside the directory
* environment variables

## How to Build

### Overview

Use the `build.sh` script in the root of the directory: sas-container-recipes/build.sh. You will be able to pass in the base image, tag what you want to build from, and provide any addons to create your custom image.

**Note:** The following examples use a mirror repository, which is [strongly recommended](Tips#create-a-local-mirror-repository).

To see what arguments can be used, run the following:

```
build.sh --help
```

For a single container, the `--addons`, `--base-image`, `--base-tag`, `--mirror-url`, `--platform`, `--type` and `--zip` arguments are used.

For information about how to manually build as well as add layers, see [Advanced Building Options](#advanced-building-options).

### Building on a CentOS Image

In the following example, the most recent CentOS:7 image is pulled from DockerHub, and the addons/auth-sssd and addons/access-odbc layers are added after the main SAS image is built. If you decide to use more addons, add them to the space-delimited list, and make sure that the list is enclosed in double quotation marks.

```
build.sh \
--type single \
--base-image centos \
--base-tag 7 \
--zip /path/to/SAS_Viya_deployment_data.zip \
--mirror-url http://host.company.com/sas_repo \
--addons "auth-sssd access-odbc"
```

**Note:** If the `--base-image` and `--base-tag` arguments are not provided, then centos:latest from DockerHub will be used. Although building on other Red Hat Enterprise Linux (RHEL) based images is not currently
not supported, different options for the `--base-image` and `--base-tag` arguments can be provided on an experimental basis.

### Building on a SUSE Linux Image

In the following example, the opensuse/leap:42 image is pulled from DockerHub, and the addons/auth-sssd and addons/access-odbc layers are added after the main SAS image is built. If you decide to use more addons, add them to the space-delimited list, and make sure that the list is enclosed in double quotation marks.

To change the base image from which the SAS image will be built to any SUSE variant, change the values for the `--base-image` and `--base-tag` arguments. Currently, opensuse/leap with tags 42.* is supported.

```
build.sh \
--type single \
--base-image opensuse/leap \
--base-tag 42 \
--zip /path/to/SAS_Viya_deployment_data.zip \
--mirror-url http://host.company.com/sas_repo \
--addons "auth-sssd access-odbc"
```

### Advanced Building Options
#### Running Docker build

To explicitly run the Docker build, first copy your SAS_Viya_deployment_data.zip file and the vars_usermods.yml file into the `util/programming-only-single/` directory, and then run the following:

```
docker build . \
--file Dockerfile \
--build-arg BASEIMAGE=centos \
--build-arg BASETAG=7 \
--build-arg PLATFORM=redhat \
--tag sas-viya-single-programming-only
```

The result will create a Docker image tagged as sas-viya-single-programming-only:latest.

To change the base image, change the `BASEIMAGE` and `BASETAG` options. If using a SUSE-based operating system, make sure to set `PLATFORM=suse`.  

#### Extending the Base Image

To add to the base image, navigate to any of the subdirectories and run a build 
with the provided Dockerfile. Below are examples of adding the sasdemo user to 
the initial image and then adding Jupyter with python3 support to the 
svc-auth-demo image. 

**Note:** Unless a custom base image that already
supports host-level authentication is provided, the addons/auth-sssd 
or addons/auth-demo layers must be 
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

When building the images, the content that is displayed to the console is captured in the builds/single/build.log file.

If problems are encountered during the build process, review the log file or provide it when opening up tickets.

### Errors During Build

If an error occurred during the build process, it is possible that some intermediate build containers were left behind. To see any images that are a result of the SAS recipe build process, run the following:

```
docker images --filter "dangling=true" --filter "label=sas.recipe.version"
```

If you encounter any of these you can remove these images by running the following:

```
docker rmi $(docker images -q --filter "dangling=true" --filter "label=sas.recipe.version")
```

The command between the parentheses returns the image IDs that meet the filter criteria and then will remove those images.

**Tip:** For information about how to clean up your build system, see the following Docker documentation:

- To remove all unused data, see [docker system prune](https://docs.docker.com/engine/reference/commandline/system_prune/).
- To remove images, see [docker image rm](https://docs.docker.com/engine/reference/commandline/image_rm/).

## How to Run

### Using Docker

In the root of the directory, locate the samples/viya-single-container/example_launchsas.sh file, which contains the `docker run` command. Copy the file, and then edit it so that it matches your environment. 

Here is example of running the script:

```
mkdir -p ${PWD}/run
cp samples/viya-single-container/example_launchsas.sh ${PWD}/run/launchsas.sh
sed -i 's|@REPLACE_ME_WITH_TAG@|<tag>|' ${PWD}/run/launchsas.sh
cd run
```

**Note:** 
- Replace `<tag>` with the tag value of the sas-viya-single-programming-only image. To retrieve the tag value, run the `docker images` command.
- By default, the user account for the CAS administrator (the CASENV_ADMIN_USER variable) is sasdemo. If you built the image with the auth-sssd addon or customized the user in the auth-demo addon, make sure to specify a valid user name for the CASENV_ADMIN_USER variable.

When the script is run, it will create several directories for you. These are set up either to cause data to persist or to help with [configuration](#configuration). 

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

Check that all the services are started (there should be three services and the status for each should be "up"):

```
docker exec --interactive --tty sas-viya-single-programming-only /etc/init.d/sas-viya-all-services status
  Service                                            Status     Host               Port     PID
  sas-viya-cascontroller-default                     up         N/A                 N/A     607
  sas-viya-sasstudio-default                         up         N/A                 N/A     386
  sas-viya-spawner-default                           up         N/A                 N/A     356

sas-services completed in 00:00:00
```

At this point, `http://docker-host` is reachable.

#### (Optional) Enabling SSL/TLS
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
--hostname sas-viya-single-programming-only \
--publish 8443:443 \
--name sas-viya-single-programming-only \
sas-viya-single-programming-only:<VERSION-TAG>
```

- `SSL_CERT_NAME` must be the file name of your certificate signed by the Certificate Authority.
- `SSL_KEY_NAME` must be the file name of your key.
- The file provided by `--volume /my/path/to/casigned.cer` is placed inside the container in the /etc/pki/tls/certs/ directory so that it can be used by the HTTPD SSL configuration.
- The file provided by `--volume /my/path/to/servertls.key` is placed inside the container in the /etc/pki/tls/private/ directory so that it can be used by the HTTPD SSL configuration.
- HTTPS runs on port 8443 and is published by using the `--publish 8443:443` argument in the Docker run command.

#### (Optional) Using SAS Batch Server

The container can be run using the SAS batch server. It is assumed that the SAS program is not in the container but will be made available to the container
at run time.

This example assumes that the /sasinside directory on the Docker host contains the SAS program. When the container is started, the /sasinside directory is mounted to the container so that the code can be run:

```
docker run \
--interactive \
--tty \
--rm \
--volume ${PWD}/sasinside:/sasinside \
sas-viya-single-programming-only:<tag> \
--batch /sasinside/sasprogram.sas
```

Here is an example of how to run a sample program that executes 'proc javainfo; run;':
```
docker run --interactive --tty --rm --volume ${PWD}/sasinside:/sasinside sas-viya-single-programming-only:<tag> --batch /sasinside/javainfo.sas

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

The log should be in the /sasinside directory on the Docker host.

```
> ls -l sasinside/
total 72
-rw-r--r--. 1 root   root  2308 Aug 30 22:39 javainfo.log
-rw-r--r--. 1 user   users   20 Aug 28 17:44 javainfo.sas
```

### Using Kubernetes

Before you run the SAS Viya programming-only image in Kubernetes, you must push that image to a Docker registry that the Kubernetes environment has access to.

Use `docker tag` so that the tag matches the location of where we want to push the image. In the following examples, replace docker.registry.com and /sas/ with the location of your Docker registry and the user space that you want the image to be pushed to:

```
docker tag sas-viya-single-programming-only:<tag> docker.registry.com/sas/sas-viya-single-programming-only:<tag>
```

Next, use `docker push` to push the image to the Docker registry:

```
docker push docker.registry.com/sas/sas-viya-single-programming-only:<tag>
```

With the image in the Docker registry, you can create a Kubernetes manifest in order to deploy the image. In the root of the directory, there is a /samples directory that provides a sample Kubernetes manifest for the single container. Copy the file, and modify it, as appropriate:

```
mkdir run
cp samples/viya-single-container/example_programming.yml run/programming.yml
vi run/programming.yml
```

In samples/viya-single-container/programming.yml file, find each occurrence of @REPLACE_ME*@ and replace it with the appropriate value. Also, replace the line `contents-of-license-file` with the contents of the SAS license file. Make sure that spacing remains intact after the contents are copied.

The manifest already contains several defined paths where data that needs to persist between restarts can be stored. By default, these paths are set up to point to local storage that will disappear after the Kubernetes pod is deleted. Update this part of the manifest to support how your site implements persistence storage. It is recommended that you review [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) for details about available options. 

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

Create the deployment. In this example, you create the SAS programming-only container in the sasviya Kubernetes namespace. For more information about namespaces, see [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/).

```
kubectl -n sasviya apply -f run/programming.yml
```

To very that the system is running successfully, list the pods and identify the sas-viya-single-programming-only pod:

```
kubectl -n sasviya get pods
```

Check that all the services are started (there should be three services and the status for each should be "up"):

```
kubectl -n sasviya exec -it sas-viya-single-programming-only-<uuid> -- /etc/init.d/sas-viya-all-services status
  Service                                            Status     Host               Port     PID
  sas-viya-cascontroller-default                     up         N/A                 N/A     607
  sas-viya-sasstudio-default                         up         N/A                 N/A     386
  sas-viya-spawner-default                           up         N/A                 N/A     356

sas-services completed in 00:00:00
```

Depending on how the ingress has been configured, either http://ingress-path or https://ingress-path can be reached. The examples in this documentation use https. However, if you did not configure the ingress for https, use http.