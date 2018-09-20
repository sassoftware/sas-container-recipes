# Overview

This provides a structure of how to hook in LDAP configuration that uses sssd and PAM.

# Files
Quick description of the files and if they are needed or not
* sssd.conf : Required; contains a template sssd configuration. This should reflect an organizations configuration
* sssd_pre_deploy.sh : Required; will start sssd. Called by the main entrypoint script
* sssd.cert : Optional; contains the needed cert in order for encryption to work

# How to build

Edit the _sssd.conf_ file and fill in the desired configuration. If a SSL cert is needed
provide that via a file named _sssd.cert_.

```
# This is using the default name of the SAS Viya programming image and the default sssd.conf file
docker build \
    --file Dockerfile \
    . \
    --tag svc-auth-sssd

# This is using the default name of the SAS Viya programming image and a custom sssd conf file
docker build \
    --file Dockerfile \
    --build-arg SSSD_CONF=custom_sssd.conf \
    . \
    --tag svc-auth-sssd
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
* SSSD_CONF
    * Definition: The file that contains the organizations sssd configuration
    * Default: sssd.conf

# How to run
```
docker run \
    --detach \
    --rm \
    --env CASENV_ADMIN_USER=\<user\> \
    --env CASENV_CAS_VIRTUAL_HOST=$(hostname) \
    --env CASENV_CAS_VIRTUAL_PORT=8081 \
    --publish-all \
    --publish 8081:80 \
    --name svc-auth-sssd \
    --hostname svc-auth-sssd \
    svc-auth-sssd

# Check status
docker ps --filter name=svc-auth-sssd --format "table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}} \t{{.Ports}}"
CONTAINER ID        NAMES               IMAGE               STATUS              PORTS
4b426ce49b6b        svc-auth-sssd       svc-auth-sssd       Up 2 minutes        0.0.0.0:33222->80/tcp, 0.0.0.0:33221->443/tcp, 0.0.0.0:33220->5570/tcp
```

Now go to the __http://\<hostname of Docker host\>:33222__ and login as user that is defined in the configured LDAP environment.

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
