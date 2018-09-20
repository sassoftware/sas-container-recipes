# Overview

This is an example on how to add a default user to a SAS Viya programming Docker image.
The pre-requisite is that the SAS Viya programming Docker image has already been built.
The user created here will also be used for the CAS Administrator and as the default
user for running Jupyter Notebook if the _ide-jupyter-python3_ example is used.

# How to build

```
# This is using the default name of the SAS Viya programming image and will create a user called sasdemo
docker build --file Dockerfile . --tag svc-auth-demo
```

# How to run
```
docker run \
    --detach \
    --rm \
    --env CASENV_CAS_VIRTUAL_HOST=$(hostname) \
    --env CASENV_CAS_VIRTUAL_PORT=8081 \
    --publish-all \
    --publish 8081:80 \
    --name svc-auth-demo \
    --hostname svc-auth-demo \
    svc-auth-demo

# Check the status
docker ps --filter name=svc-auth-demo --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}} \t{{.Ports}}"
CONTAINER ID        NAMES               IMAGE               STATUS              PORTS
4b426ce49b6b        svc-auth-demo       svc-auth-demo       Up 2 minutes        0.0.0.0:8081->80/tcp, 0.0.0.0:33221->443/tcp, 0.0.0.0:33220->5570/tcp
```

Now go to the __http://\<hostname of Docker host\>:8081__ and login as user _sasdemo_ with password _sasdemo_.

## Configure the default user
### Run Arguments
* BASEIMAGE
    * Definitiion: Define the namespace and image name to build from
    * Default: sas-viya-programming
* BASETAG
    * Definition: The verision of the image to build from
    * Default: latest
* CASENV_ADMIN_USER
    * Definition: The user to create
    * Default: sasdemo
* ADMIN_USER_PWD
    * Definition: The password of the user in plain text
    * Default: sasdemo
* ADMIN_USER_HOME
    * Definition: The home directory of the user
    * Default: /home/${CASENV_ADMIN_USER}
* ADMIN_USER_UID
    * Definition: The unique id of the user
    * Default: 1003
* ADMIN_USER_GROUP
    * Definition: The group name to assign the user to. It matches the "sas" group created during the deployment.
    * Default: sas
* ADMIN_USER_GID
    * Definition: The ID of the group to assign the user to. It matches the "sas" group created during the deployment.
    * Default: 1001

### Example
The following will create a _foo_ user with a password of _bar_, a UID of _1010_ 
belonging to a group with name of _widget_ and a GID of _1011_.

```
docker run \
    --detach \
    --rm \
    --env CASENV_CAS_VIRTUAL_HOST=$(hostname) \
    --env CASENV_CAS_VIRTUAL_PORT=8081 \
    --env CASENV_ADMIN_USER=foo \
    --env ADMIN_USER_PWD=bar \
    --env ADMIN_USER_UID=1010 \
    --env ADMIN_USER_GROUP=widget \
    --env ADMIN_USER_GID=1011 \
    --publish-all \
    --publish 8081:80 \
    --name svc-auth-demo \
    --hostname svc-auth-demo \
    svc-auth-demo
```

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
