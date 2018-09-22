# Overview

This is an example on how to add Jupyter Notebook with Python3 to a SAS Viya
programming Docker image. The pre-requisite is that the SAS Viya programming Docker
image has already been built. It is suggested to build this on top of an image
that has host authentication already added, i.e. _auth-demo_ or _auth-sssd_.

# How to build

```
# This is using the default name of the SAS Viya programming image
docker build \
    --file Dockerfile \
    --build-arg BASEIMAGE=svc-auth-demo \
    --build-arg BASETAG=latest \
    . \
    --tag svc-ide-jupyter-python3
```

## Build Arguments

* BASEIMAGE
    * Definitiion: Define the namespace and image name to build from
    * Default: sas-viya-programming
* BASETAG
    * Definition: The verision of the image to build from
    * Default: latest
* PLATFORM
    * Definition: The type of host that the software is being installed on
    * Default: redhat
    * Valid values: redhat, suse
* SASPYTHONSWAT
    * Definition: The version of [SAS Scripting Wrapper for Analytics Transfer (SWAT) package](https://github.com/sassoftware/python-swat)
    * Default: 1.4.0
* JUPYTER_TOKEN
    * Definition: The value of the token that the the notebook uses to authenticate requests. By default it is empty turning off authentication.
    * Default: ''
* ENABLE_TERMINAL
    * Definition: Indicates if the terminal should be accessible by the notebook. By default it will be enabled.
    * Default: True
    * Valid values: True, False (case sensitive)
* ENABLE_NATIVE_KERNEL
    * Definition: Indicates if the python3 kernel should be accessible by the notebook. By default it will be enabled.
    * Default: True
    * Valid values: True, False (case sensitive)
    
# How to run
```
docker run \
    --detach \
    --rm \
    --env CASENV_CAS_VIRTUAL_HOST=$(hostname) \
    --env CASENV_CAS_VIRTUAL_PORT=8081 \
    --publish-all \
    --publish 8081:80 \
    --name svc-ide-jupyter-python3 \
    --hostname svc-ide-jupyter-python3 \
    svc-ide-jupyter-python3

# Check Status
docker ps --filter name=svp_jupyter --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}} \t{{.Ports}}"
CONTAINER ID        NAMES                       IMAGE                       STATUS              PORTS
4b426ce49b6b        svc-ide-jupyter-python3     svc-ide-jupyter-python3     Up 2 minutes        0.0.0.0:8081->80/tcp, 0.0.0.0:33221->443/tcp, 0.0.0.0:33220->5570/tcp
```

Now go to the __http://\<hostname of Docker host\>:8081/Jupyter__

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
