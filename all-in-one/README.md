# Background
A docker container for a data scientist. An analytics work bench (awb) not unlike that wooden one in your garage - a comfortable place to hack on your projects using your tools of choice.  Take your pick of:
* SAS Studio
* R Studio
* Jupyter Lab

# How to clone from github

These examples are for a linux host that has git and docker installed.  You can do this on Windows (with Powershell), and on a Mac too. To keep the example simple, we'll put the cloned folder in your $HOME directory.

```
cd $HOME
git clone https://github.com/sassoftware/sas-container-recipes.git
```

# How to build

```
cd $HOME/sas-container-recipes/all-in-one
ORDER={Your-6-digit-SAS-order-number}
mkdir -p download/$ORDER
# copy the "SAS_Viya_deployment_data.zip" attachment from your SAS Order email into download/$ORDER directory
# edit $ORDER into sasORDER ENV variable definition in the Dockerfile
docker-compose build
```

# How to add Vendor dependencies

If the SAS/Access Software in your order requires some collateral vendor dependencies, please read [VENDOR.md](VENDOR.md).  The ```files/install_vendor.sh``` script tries to help configure the components for you, provided you have placed the necessary artefats inside vendor/xxx subfolders.

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

# How to run myjob.sas (a good old batch sas execution)

You can override the commands run when the docker container starts - see the ```dosas``` script.

```
cd $HOME/mysas
$HOME/sas-container-recipes/all-in-one/dosas -nodms -myjob.sas -ls 120
```

# Curious?
You can use the `./doshell` script to ssh into the container while it is running and take a look around.

# Support
This is an example for you to use and change as you see fit.  Probably you don't want hard coded passwords like we use here.  

# Copyright
Copyright 2018 SAS Institute Inc.

This work is licensed under a Creative Commons Attribution 4.0 International License.
You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/ 



