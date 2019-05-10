#! /bin/bash -e

IMAGE=sas-viya-single-programming-only:@REPLACE_ME_WITH_TAG@
SAS_HTTP_PORT=8080
SAS_HTTPS_PORT=8443

mkdir -p ${PWD}/sasinside      # Configuration
mkdir -p ${PWD}/sasdemo        # In some cases persist user data
mkdir -p ${PWD}/cas/data       # Persist CAS data
mkdir -p ${PWD}/cas/cache      # Allow for writing temporary files to a different location
mkdir -p ${PWD}/cas/permstore  # Persist CAS permissions

run_args="
--name=sas-programming
--rm
--hostname sas-programming
--env RUN_MODE=developer
--env CASENV_ADMIN_USER=sasdemo
--env CASENV_CAS_VIRTUAL_HOST=$(hostname -f)
--env CASENV_CAS_VIRTUAL_PORT=${SAS_HTTP_PORT}
--env CASENV_CASDATADIR=/cas/data
--env CASENV_CASPERMSTORE=/cas/permstore
--publish-all
--publish 5570:5570
--publish ${SAS_HTTP_PORT}:80
--publish ${SAS_HTTPS_PORT}:443
--volume ${PWD}/sasinside:/sasinside
--volume ${PWD}/sasdemo:/data
--volume ${PWD}/cas/data:/cas/data
--volume ${PWD}/cas/cache:/cas/cache 
--volume ${PWD}/cas/permstore:/cas/permstore"

# Run in detached mode
docker run --detach ${run_args} $IMAGE "$@"

# For debugging startup, comment out the detached mode command and uncomment the following

#docker run --interactive --tty ${run_args} $IMAGE "$@"

