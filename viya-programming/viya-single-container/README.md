# Overview

This is a recipe for creating a SAS Viya programming-only Docker image based on a SAS Viya 3.4 for Linux order.

# How to Build

```
cd $HOME/sas-container-recipes/viya-programming/viya-single-container

#
# **** DO ONE OF THE FOLLOWING: GENERATE PLAYBOOK ****
#
# if you want the "docker build" process to generate the playbook
#   copy the "SAS_Viya_deployment_data.zip" attachment from your
#   SAS Order email into the current directory

cp /path/to/SAS_Viya_deployment_data.zip .

#   edit Dockerfile to indicate the zip file is being provided

sed -i 's|^#COPY SAS_Viya_deployment_data.zip|COPY SAS_Viya_deployment_data.zip|g' Dockerfile
sed -i 's|^COPY sas_viya_playbook|#COPY sas_viya_playbook|g' Dockerfile

#
# **** OR ****
#
# if you already generated the programming only version of the playbook,
#   copy the playbook to this directory

cp -a /path/to/sas_viya_playbook .

#   edit Dockerfile to indicate the playbook is being provided

sed -i 's|^COPY SAS_Viya_deployment_data.zip|#COPY SAS_Viya_deployment_data.zip|g' Dockerfile
sed -i 's|^#COPY sas_viya_playbook|COPY sas_viya_playbook|g' Dockerfile

#
# **** END OPTIONS ****
#
#
# **** DO ONE OF THE FOLLOWING: BASE IMAGE ****
#
# To build against centos:latest base image

docker build --file Dockerfile . --tag viya-single-container

#
# **** OR ****
#
# To build against a custom RedHat variance base image

docker build --file Dockerfile --build-arg BASEIMAGE=<name of image> --build-arg BASETAG=<tag> . --tag viya-single-container

# Example: if using an image named 'rhvariance' stored in 'docker.company.com/rh' with a tag of '7.2'

docker build --file Dockerfile--build-arg BASEIMAGE=docker.company.com/rh/rhvariance --build-arg BASETAG=7.2 . --tag viya-single-container

#
# **** END OPTIONS ****
#
```

# Extending

To add to the base image, change into any of the subdirectories and run a build 
with the provided Dockerfile. Below are an example of adding the _sasdemo_ user to 
the initial image and then adding the Jupyter with python3 support to the 
_svc-auth-demo_ image. 

__Note:__ Unless a custom base image is provided that already
supports host level authentication, the [addons/auth-sssd](../../addons/auth-sssd/README.md)
or [addons/auth-demo] (../../addons/auth-demo/README.md) layers will need to be 
added in order to support full functionality of the SAS Viya container.

## To Create an Image with the sasdemo user
```
cd /path/to/sassoftware/sas-container-recipes/addons/auth-demo
docker build -f Dockerfile . -t svc-auth-demo
docker run --detach --publish-all --rm --name svc-auth-demo --hostname svc-auth-demo svc-auth-demo
```

## To Create an Image with Jupyter Notebook
```
cd /path/to/sassoftware/sas-container-recipes/addons/ide-jupyter-python3
docker build -f Dockerfile --build-arg BASEIMAGE=svc-auth-demo . -t svc-ide-jupyter-python3
docker run --detach --publish-all --rm --name svc-ide-jupyter-python3 --hostname svc-ide-jupyter-python3 svc-ide-jupyter-python3
```

# How to Run

## Interactive

```
docker run --detach --publish-all --rm --name viya-single-container --hostname viya-single-container viya-single-container
```

To check that all the services are started:

```
# There should be three services and status should be 'up'
docker exec --interactive --tty viya-single-container /etc/init.d/sas-viya-all-services status
  Service                                            Status     Host               Port     PID
  sas-viya-cascontroller-default                     up         N/A                 N/A     607
  sas-viya-sasstudio-default                         up         N/A                 N/A     386
  sas-viya-spawner-default                           up         N/A                 N/A     356

sas-services completed in 00:00:00
```

## SAS Batch Server

The container can be run using the SAS batch server. The expectation is that the SAS program is not in the container and will be made available to the container
at run time.

```
# This example is expecting that there is a /sasinside directory on the Docker host
# that has the SAS program. When the container is started we will mount the
# sasiniside directory to the container so that the code can be run

docker run --interactive --tty --rm --volume ${PWD}/sasinside:/sasinside viya-single-container --batch /sasinside/sasprogram.sas

# Here is an example running a sample program that just does 'proc javainfo; run;'
docker run --interactive --tty --rm --volume ${PWD}/sasinside:/sasinside --env SAS_LOGS_TO_DISK=true svp_jpy3 --batch /sasinside/javainfo.sas
docker run --interactive --tty --rm --volume ${PWD}/sasinside:/sasinside --env SAS_LOGS_TO_DISK=true svp_jpy3 --batch /sasinside/javainfo.sas
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

# The log should also be back on the Docker host in the sasinside directory.
> ls -l sasinside/
total 72
-rw-r--r--. 1 root   root  2308 Aug 30 22:39 javainfo.log
-rw-r--r--. 1 user   users   20 Aug 28 17:44 javainfo.sas
```

# Customizing

## During the Docker Build

If there are customizations that you want to provide during the creation of the image,
these can be added by providing a vars.yml file in the same directory as the Dockerfile.
This file will be picked up and used during the running of the playbook.

## Post Docker Build

To apply a different configuration to the SAS Workspace Server or
to CAS, perform the following task.

Create a sasinside directory, 
create any of the following files with the desired content, and 
add each file to the sasinside directory:

* casconfig_usermods.lua
* cas_usermods.settings
* autoexec_usermods.sas
* sasv9_usermods.cfg
* batchserver_usermods.sh
* workspaceserver_usermods.sh
* sasstudio_usermods.properties

With the preceding files in place, start the container as shown below:

```
docker run --detach --publish-all --rm --volume /path/to/sasinside:/sasinside --name viya-single-container --hostname viya-single-container viya-single-container
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
