# Historical Note
This folder is the content that was presented at SAS Global Forum 2018.  It remains here as a historical artefact -- In September 2018, we published a more officially supported set on instructions and the `build.sh` script to help you build a multi-layered container for SAS Viya.  It has layers for many more access engines, and provides for sssd authorization rather that just hardcoding a `sasdemo` username.  Please use that approach instead.

# Background
A docker container for a data scientist. An analytics work bench (awb) that is not unlike that wooden one in your garage ... a comfortable place to hack on your projects using your tools of choice.

Take your pick of:
* SAS Studio
* R Studio
* Jupyter Lab

# How to Build

```
cd $HOME/sas-container-recipes/all-in-one
ORDER={Your-6-digit-SAS-order-number}
mkdir -p download/$ORDER
# copy the "SAS_Viya_deployment_data.zip" attachment from your SAS Order email into download/$ORDER directory
# edit $ORDER into sasORDER ENV variable definition in the Dockerfile
docker-compose build
```

# How to Run

```
cd $HOME/sas-container-recipes/all-in-one
docker-compose up
```

If you are running the container on Windows, you can delete the /sys/fs/cgroup mount from the docker-compose.yml

To check that all the services are started:

```
# There should be 4 services and status should be 'up'
cd $HOME/sas-container-recipes/all-in-one
./dostatus
```

After all the services are started, you can access these links (substitute `localhost` maybe)
* http://localhost:80/cas-shared-default-http/tkcas.dsp  for CAS Monitor
* http://localhost:80/SASStudio for SAS Studio
* http://localhost:80/Jupyter for Jupyter

You may find that something is already using port 80 on the computer where the container is running. You can adjust the port by editing docker-compose.yml and change the first 80 in 80:80 - that line maps external-port:container-port, so if you change it to 8081:80, then you would visit http://_my-computer_:8081/SASStudio for SAS Studio.

If you have not changed things, you can use `sasdemo` as the username; `sasDEMO` as the password.

When you are finished using the container, you can shut it down.
```
cd $HOME/sas-container-recipes/all-in-one
docker-compose down
```

# How to run myjob.sas (a good old batch sas execution)

You can override the commands run when the docker container starts - see the ```dosas``` script.

```
cd $HOME/mysas
$HOME/sas-container-recipes/all-in-one/dosas -nodms -myjob.sas -ls 120
```

# Curious?
You can use the `./doshell` script to ssh into the container while it is running and take a look around.

# Support
This is an example for you to use and change as you see fit. Most likely, you don't want hard-coded passwords like we use here.  

# Copyright

Copyright 2018 SAS Institute Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
