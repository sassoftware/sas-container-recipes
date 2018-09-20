# Background
A docker container for a data scientist. An analytics work bench (awb) not unlike that wooden one in your garage - a comfortable place to hack on your projects using your tools of choice.  Take your pick of:
* SAS Studio
* R Studio
* Jupyter Lab

# How to build

```
cd $HOME/sas-container-recipes/all-in-one
ORDER={Your-6-digit-SAS-order-number}
mkdir -p download/$ORDER
# copy the "SAS_Viya_deployment_data.zip" attachment from your SAS Order email into download/$ORDER directory
# edit $ORDER into sasORDER ENV variable definition in the Dockerfile
docker-compose build
```

# How to run

```
cd $HOME/sas-container-recipes/all-in-one
docker-compose up
```

If you are running the container on windows, you can delete the /sys/fs/cgroup mount from the docker-compose.yml

To check that the services are all started:

```
# There should be 4 services and status should be 'up'
cd $HOME/sas-container-recipes/all-in-one
./dostatus
```

Once the services are all up, you can access these links (substitute `localhost` maybe)
* http://localhost:80/cas-shared-default-http/tkcas.dsp  for CAS Monitor
* http://localhost:80/SASStudio for SAS Studio
* http://localhost:80/Jupyter for Jupyter

You may find that something is already using port 80 on the computer you run the container on.  You can adjust the port by editing docker-compose.yml and change the first 80 in "80:80" - that line maps external-port:container-port, so if you change it to "8081:80" then of course you would visit http://my-computer:8081/SASStudio for SAS Studio.

If you have not changed things, you can use `sasdemo` as the username; `sasDEMO` as the password.

When you are finished using the container, you can shut it down.
```
cd $HOME/sas-container-recipes/all-in-one
docker-compose down
```


# Curious?
You can use the `./doshell` script to ssh into the container while it is running and take a look around.

# Support
This is an example for you to use and change as you see fit.  Probably you don't want hard coded passwords like we use here.  

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
