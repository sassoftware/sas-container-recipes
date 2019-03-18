#!/bin/bash -e
#
# Utility that uses containers to build, customize, and deploy a SAS environment based on your software order.
#
#
# Copyright 2018 SAS Institute Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# Run the ansible-container build in the clean workspace and build all services.
# Or define the environment variable "REBUILDS" to only build a few services.
# example: export REBUILDS="myservice myotherservice anotherone" ./build.sh ...
# https://www.ansible.com/integrations/containers/ansible-container
function ansible_build() {
    # Need to remove the latest tag as the push process is looking for the latest tag.
    # If we are running the build process a second time, the latest tag will be found
    # and pushed which may not be want we want. We will remove the latest tag
    # and then kick off ansible-container. ansible-container always tags the image
    # as latest and with a date-time stamp. Removing the latest tag does not remove
    # the image.
    echo -e "[INFO]  : Remove the latest tag from images if they already exist."
    readarray -t sorted_services < <(printf '%s\0' "${all_services[@]}" | sort -z | xargs -0n1)
    for service in "${sorted_services[@]}"; do
        set +e
        docker rmi ${PROJECT_NAME}-${service}:latest 2> /dev/null
        set -e
    done

    SAS_ANSIBLE_CONTAINER_PID=
    if [[ ! -z ${REBUILDS} ]]; then
        echo -e "Rebuilding services ${REBUILDS}"
        ansible-container build --services $REBUILDS &
        SAS_ANSIBLE_CONTAINER_PID=$!
    else
        ansible-container build &
        SAS_ANSIBLE_CONTAINER_PID=$!
    fi
    echo ${SAS_ANSIBLE_CONTAINER_PID} > ${PWD}/sas_ansible_container.pid
}

# At the start of the process output details on the environment and build flags
function setup_logging() {
    echo "" > result-${sas_datetime}.log
    exec > >(tee -a "${PWD}"/build_sas_container.log) 2>&1
    echo -e ""
    echo -e "  BASEIMAGE                       = ${BASEIMAGE}"
    echo -e "  BASETAG                         = ${BASETAG}"
    echo -e "  Mirror URL                      = ${SAS_RPM_REPO_URL}"
    echo -e "  Platform                        = ${PLATFORM}"
    echo -e "  HTTP Ingress endpoint           = ${CAS_VIRTUAL_HOST}"
    echo -e "  Deployment Data Zip             = ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}"
    echo -e "  Addons                          = ${ADDONS}"
    echo -e "  Docker registry URL             = ${DOCKER_REGISTRY_URL}"
    echo -e "  Docker registry namespace       = ${DOCKER_REGISTRY_NAMESPACE}"
    echo -e "  Validate Docker registry URL    = ${CHECK_DOCKER_URL}"
    echo -e "  Validate Mirror URL             = ${CHECK_MIRROR_URL}"
    echo -e "  Tag SAS will apply              = ${SAS_DOCKER_TAG}"
    echo -e "  Build System OS                 = ${OPERATING_SYSTEM}"
    echo
}

# Checks arguments and flags for input that is supported
function validate_input() {

    # Validate that required arguments were provided
    # TODO: proper if/else
    if [[ -z ${DOCKER_REGISTRY_URL} ]]; then
        usage
        echo -e "A docker registry URL is required."
        exit 1
    fi
    if [[ -z ${DOCKER_REGISTRY_NAMESPACE} ]]; then
        usage
        echo -e "A docker registry namespace is required."
        exit 1
    fi

    # Validate that the provided platform is accepted
    accepted_platforms=(suse redhat)
    target_platform="${PLATFORM}"
    match=0
    for ap in "${accepted_platforms[@]}"; do
        if [ "${ap}" = "${target_platform}" ]; then
            match=1
            break
        fi
    done
    if (( match == 0 )); then
        echo -e "[ERROR] : The provided platform of '${target_platform}' is not valid. Please use 'redhat' or 'suse'."
        echo
        exit 10
    fi
    if [ "${PLATFORM}" = "suse" ] && [[ -z ${SAS_RPM_REPO_URL+x} ]]; then
        echo -e "[ERROR] : For SuSE based platforms, a mirror must be provided."
        echo
        exit 20
    fi

    if [[ ( -z ${DOCKER_REGISTRY_URL+x} || -z ${DOCKER_REGISTRY_URL+x} ) && "${SAS_RECIPE_TYPE}" != "single" ]]; then
        echo -e "[ERROR] : Trying to use a type of '${SAS_RECIPE_TYPE}' without giving the Docker registry URL or name space"
        echo
        exit 6
    fi
}


# Handles both the '--zip' and '--playbook' options.
#
# Given the '--playbook' does not use the sas-orchestration tool to create a new playbook.
#
# Given the '--zip' option, unzip the contents and use the sas-orchestration
# tool to create the playbook. Any changes made to this playbook will get # overridden in the next build.
#
function get_playbook() {
    if [[ ! -z ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} ]]; then
        # SAS_Viya_deployment_data.zip given and it's valid
        SAS_ORCHESTRATION_LOCATION=${PWD}/../sas-orchestration
        if [[ ! -f ${SAS_ORCHESTRATION_LOCATION} ]]; then
            if [[ "${OPERATING_SYSTEM}" == "darwin" ]]; then
                echo "[INFO]  : fetching sas-orchestration tool Mac";echo
                curl --silent --remote-name https://support.sas.com/installation/viya/34/sas-orchestration-cli/mac/sas-orchestration-osx.tgz
                tar xvf sas-orchestration-osx.tgz
                rm sas-orchestration-osx.tgz
                # Fetch the binary and move it above the working directory
                mv sas-orchestration ../
            else
                echo "[INFO]  : fetching sas-orchestration tool";echo
                curl --silent --remote-name https://support.sas.com/installation/viya/34/sas-orchestration-cli/lax/sas-orchestration-linux.tgz
                tar xvf sas-orchestration-linux.tgz
                rm -v sas-orchestration-linux.tgz
                # Fetch the binary and move it above the working directory
                mv sas-orchestration ../
            fi
        fi

        echo -e "[INFO]  : Building the playbook from the SOE zip."
        ${SAS_ORCHESTRATION_LOCATION} build \
            --input ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} \
            --repository-warehouse ${SAS_RPM_REPO_URL} \
            --platform ${PLATFORM} \
            --deployment-type programming

        tar xvf SAS_Viya_playbook.tgz
        rm -v SAS_Viya_playbook.tgz
        cp -v sas_viya_playbook/*.pem .

    else
        echo -e "[ERROR] : Could not find a zip file to use"
        echo -e ""
        exit 1
    fi
}

function setup_defaults() {
    sas_datetime=$(date "+%Y%m%d%H%M%S")
    sas_sha1=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git-sha")

    [[ -z ${SAS_RECIPE_TYPE+x} ]]              && SAS_RECIPE_TYPE=single
    [[ -z ${SAS_RECIPE_VERSION+x} ]]           && SAS_RECIPE_VERSION=$(cat ../../docs/VERSION)
    [[ -z ${CHECK_MIRROR_URL+x} ]]             && CHECK_MIRROR_URL=true
    [[ -z ${CHECK_DOCKER_URL+x} ]]             && CHECK_DOCKER_URL=true
    [[ -z ${SETUP_VIRTUAL_ENVIRONMENT+x} ]]    && SETUP_VIRTUAL_ENVIRONMENT=true
    [[ -z ${SAS_DOCKER_TAG+x} ]]               && SAS_DOCKER_TAG=${SAS_RECIPE_VERSION}-${sas_datetime}-${sas_sha1}
    [[ -z ${PROJECT_NAME+x} ]]                 && PROJECT_NAME=sas-viya
    [[ -z ${SAS_K8S_NAMESPACE+x} ]]            && SAS_K8S_NAMESPACE="${PROJECT_NAME}"
    [[ -z ${SAS_K8S_INGRESS_DOMAIN+x} ]]       && SAS_K8S_INGRESS_DOMAIN="company.com"
    [[ -z ${BASEIMAGE+x} ]]                    && BASEIMAGE=centos
    [[ -z ${BASETAG+x} ]]                      && BASETAG="7"
    [[ -z ${SAS_VIYA_DEPLOYMENT_DATA_ZIP+x} ]] && SAS_VIYA_DEPLOYMENT_DATA_ZIP=${PWD}/SAS_Viya_deployment_data.zip
    [[ -z ${SAS_VIYA_PLAYBOOK_DIR+x} ]]        && SAS_VIYA_PLAYBOOK_DIR=${PWD}/sas_viya_playbook
    [[ -z ${PLATFORM+x} ]]                     && PLATFORM=redhat
    [[ -z ${SAS_RPM_REPO_URL+x} ]]             && SAS_RPM_REPO_URL=https://ses.sas.download/ses/
    [[ -z ${DOCKER_REGISTRY_URL+x} ]]          && DOCKER_REGISTRY_URL=http://docker.company.com
    [[ -z ${DOCKER_REGISTRY_NAMESPACE+x} ]]    && DOCKER_REGISTRY_NAMESPACE=sas
    [[ -z ${PROJECT_DIRECTORY+x} ]]            && PROJECT_DIRECTORY=working
    [[ -z ${OPERATING_SYSTEM+x} ]]             && OPERATING_SYSTEM=linux
}

# Move everything into a working directory, set up the python virtual environment, and check for a docker config
function setup_environment() {

    # Check for docker config so images can be pushed
    if [[ ! -f ~/.docker/config.json ]]; then
        echo -e "File '~/.docker/config.json' not found."
        echo -e "Authentication with a docker registry is required. Run \`docker login\` on your registry ${DOCKER_REGISTRY_URL}"
        echo -e ""
        exit 1
    fi

    # Setup the python virtual environment and install the requirements inside
    if [ ${SETUP_VIRTUAL_ENVIRONMENT} = "true" ]; then
        # Detect virtualenv with $VIRTUAL_ENV
        if [[ -n $VIRTUAL_ENV ]]; then
            echo -e "Existing virtualenv detected..."
        # Create default env if none
        elif [[ -z $VIRTUAL_ENV ]] && [[ ! -d env/ ]]; then
            echo -e "Creating virtualenv env..."
            virtualenv --system-site-packages env
            . env/bin/activate
        # Activate existing env if available
        elif [[ -d env/ ]]; then
            echo -e "Activating virtualenv env..."
            . env/bin/activate
        fi
        # Ensure env active or die
        if [[ -z $VIRTUAL_ENV ]]; then
            echo -e "Failed to activate virtualenv....exiting."
            echo -e ""
            exit 1
        fi
        # Detect python 2+ or 3+
        PYTHON_MAJOR_VER="$(python -c 'import platform; print(platform.python_version()[0])')"
        if [[ $PYTHON_MAJOR_VER -eq "2" ]]; then
            # Install ansible-container
            pip install --upgrade pip==9.0.3
            pip install --no-deps ansible-container[docker]==0.9.2
            echo "Updating the client timeout for the created virtual environment."
            echo 'ENV DOCKER_CLIENT_TIMEOUT=600' >> ${VIRTUAL_ENV}/lib/python2.7/site-packages/container/docker/templates/conductor-local-dockerfile.j2
        elif [[ $PYTHON_MAJOR_VER -eq "3" ]]; then
            echo "WARN: Python3 support is experimental in ansible-container."
            echo "Updating requirements file for python3 compatibility..."
            sed -i.bak '/ruamel.ordereddict==0.4.13/d' ./templates/requirements.txt
            pip install --upgrade pip==9.0.3
            pip install --no-deps -e git+https://github.com/ansible/ansible-container.git@release-0.9.2#egg=ansible-container[docker]
            echo "Updating the client timeout for the created virtual environment."
            echo 'ENV DOCKER_CLIENT_TIMEOUT=600' >> ${VIRTUAL_ENV}/src/ansible-container/container/docker/templates/conductor-local-dockerfile.j2
        fi
        # Restore latest pip version
        pip install --upgrade pip setuptools
        pip install -r templates/requirements.txt
        pip install ansible==2.7
    fi

    # Start with a clean working space by moving everything into the working directory
    if [[ -d ${PROJECT_DIRECTORY}/ ]]; then
      mv "${PROJECT_DIRECTORY}" "${PROJECT_DIRECTORY}_${sas_datetime}"
    fi
    mkdir ${PROJECT_DIRECTORY}
    cp -v templates/container.yml ${PROJECT_DIRECTORY}/
    cp -v templates/generate_manifests.yml ${PROJECT_DIRECTORY}/
    # Copy over the default. This is a place holder. Users should provide their
    # own copy and put it in the sas-container-recipes/viya-visuals direcotry
    cp -v templates/vars_usermods.yml ${PROJECT_DIRECTORY}/

# sitedefault file is not used in programming.
    # See if the user provided their own copy of vars_usermods
    if [[ -f vars_usermods.yml ]]; then
        cp -v vars_usermods.yml ${PROJECT_DIRECTORY}/
    fi
}


# Setup the ansible-container directory structure.
#
# ansible-container requires a "roles" directory, a yaml containing all key/value pairs,
# and a container.yml file containing a list of services to build.
#
# https://www.ansible.com/integrations/containers/ansible-container
#
function make_ansible_yamls() {
    all_services=() # Keep a list of the built services so they can be pushed a registry
    # Each directory in the group_vars is a new host
    for file in $(ls -1 sas_viya_playbook/group_vars); do
        echo; echo "*** Create the roles directory for the host groups"
        # Ignore some default hosts
        if [ "${file}" != "all" ] && \
           [ "${file}" != "CommandLine" ] && \
           [ "${file}" != "sas-all" ] && \
           [ "${file}" != "sas-casserver-secondary" ] && \
           [ "${file}" != "sas-casserver-worker" ]; then

            # Lets check to see if the file actually has packages for us to install
            # An ESP order is an example of this
            set +e
            grep --quiet "SERVICE_YUM_PACKAGE" sas_viya_playbook/group_vars/${file}
            pkg_grep_rc=$?
            grep --quiet "SERVICE_YUM_GROUP" sas_viya_playbook/group_vars/${file}
            grp_grep_rc=$?
            set -e

            if (( ${pkg_grep_rc} == 0 )) || (( ${grp_grep_rc} == 0 )); then
                all_services+=( ${file,,} )

                echo "***   Create the roles directory for service '${file}'"; echo
                mkdir -p -v roles/${file}/tasks
                mkdir -p -v roles/${file}/templates
                mkdir -p -v roles/${file}/vars

                if [ ! -f "roles/${file}/tasks/main.yml" ]; then
                    echo; echo "***     Copy the tasks file for service '${file}'"; echo
                    cp -v ../templates/task.yml roles/${file}/tasks/main.yml
                else
                    echo; echo "***     Tasks file for service '${file}' already exists"; echo
                fi

                # if [ ! -f "roles/${file}/templates/entrypoint" ]; then
                #     echo; echo "***     Copy the entrypoint file for service '${file}'"; echo
                #     cp -v ../templates/entrypoint roles/${file}/templates/entrypoint
                # else
                #     echo; echo "***     entrypoint file for service '${file}' already exists"; echo
                # fi

            else
                echo
                echo "*** There are no packages or yum groups in '${file}'"
                echo "*** Skipping adding service '${file}' to Docker list"
                echo
            fi
        else
            echo; echo "*** Skipping creating the roles directory for service '${file}'"; echo
        fi
    done

    echo
    # Copy over static roles, override others already added in the generated roles
    cp -rf ../templates/static-roles/* roles/
    # For all roles in the playbook's list that are also in in the group_vars directory...
    for role in $(ls -1 roles); do
        if [ -f sas_viya_playbook/group_vars/${role} ]; then
            if [ -f roles/${role}/vars/${role} ]; then
                rm -v roles/${role}/vars/${role}
            fi
            if [ -d roles/${role}/vars ]; then
                cp -v sas_viya_playbook/group_vars/${role} roles/${role}/vars/
                chmod u+w roles/${role}/vars/${role}
            fi
        fi
    done

    # When first starting with Ansible-Container, it would not take multiple
    # var files. This section here dumps everything into one file and then
    # adjusts the everything.yml file to make sure variables are in the correct order
    #

    echo
    echo "PROJECT_NAME: ${PROJECT_NAME}" > everything.yml
    echo "SAS_K8S_NAMESPACE: ${SAS_K8S_NAMESPACE}" >> everything.yml
    echo "SAS_K8S_INGRESS_DOMAIN: ${SAS_K8S_INGRESS_DOMAIN}" >> everything.yml
    echo "BASEIMAGE: ${BASEIMAGE}" >> everything.yml
    echo "BASETAG: ${BASETAG}" >> everything.yml
    echo "PLATFORM: ${PLATFORM}" >> everything.yml
    echo "DOCKER_REGISTRY_URL: ${DOCKER_REGISTRY_URL}" >> everything.yml
    echo "DOCKER_REGISTRY_NAMESPACE: ${DOCKER_REGISTRY_NAMESPACE}" >> everything.yml
    echo "SAS_RECIPE_VERSION: ${SAS_RECIPE_VERSION}" >> everything.yml
    echo "" >> everything.yml
    echo "DEPLOYMENT_ID: viya" >> everything.yml
    echo "SPRE_DEPLOYMENT_ID: spre" >> everything.yml

    cp sas_viya_playbook/group_vars/all temp_all
    chmod u+w temp_all

    # MAC sed works different than linux
    # https://stackoverflow.com/a/22084103/1212443
    if [[ "$OPERATING_SYSTEM" == "darwin" ]]; then
        sed_i_option="-i ''"
    else
        sed_i_option='-i '
    fi

    sed ${sed_i_option} 's|^DEPLOYMENT_ID:.*||' temp_all
    sed ${sed_i_option} 's|^SPRE_DEPLOYMENT_ID:.*||' temp_all

    cat temp_all >> everything.yml

    rm -v -f temp_all

    cat sas_viya_playbook/vars.yml >> everything.yml
    cat sas_viya_playbook/internal/soe_defaults.yml >> everything.yml

    sed ${sed_i_option} 's|---||g' everything.yml
    sed ${sed_i_option} 's|^SERVICE_NAME_DEFAULT|#SERVICE_NAME_DEFAULT|' everything.yml
    sed ${sed_i_option} 's|^CONSUL_EXTERNAL_ADDRESS|#CONSUL_EXTERNAL_ADDRESS|' everything.yml
    sed ${sed_i_option} 's|^YUM_INSTALL_BATCH_SIZE|#YUM_INSTALL_BATCH_SIZE|' everything.yml
    sed ${sed_i_option} 's|^sasenv_license|#sasenv_license|' everything.yml
    sed ${sed_i_option} 's|^sasenv_composite_license|#sasenv_composite_license|' everything.yml
    sed ${sed_i_option} 's|^METAREPO_CERT_SOURCE|#METAREPO_CERT_SOURCE|' everything.yml
    sed ${sed_i_option} 's|^ENTITLEMENT_PATH|#ENTITLEMENT_PATH|' everything.yml
    sed ${sed_i_option} 's|^SAS_CERT_PATH|#SAS_CERT_PATH|' everything.yml
    sed ${sed_i_option} 's|^SECURE_CONSUL:.*|SECURE_CONSUL: false|' everything.yml

    #
    # Copy over the certificates that will be needed to do the install
    #

    if [ -f ${PWD}/entitlement_certificate.pem ]; then
        rm -f ${PWD}/entitlement_certificate.pem
    fi
    cp -v sas_viya_playbook/entitlement_certificate.pem .
    chmod u+w entitlement_certificate.pem

    if [ -f ${PWD}/SAS_CA_Certificate.pem ]; then
        rm -f ${PWD}/SAS_CA_Certificate.pem
    fi
    cp -v sas_viya_playbook/SAS_CA_Certificate.pem .
    chmod u+w SAS_CA_Certificate.pem

    #
    # Update Container yaml
    #
    # This is the default on MAC.
    # https://stackoverflow.com/a/46464081/1212443
    if [[ "${OPERATING_SYSTEM}" == "darwin" ]]; then
      setinit_enc=$(cat sas_viya_playbook/SASViyaV0300*.txt | base64 )
    else
      setinit_enc=$(cat sas_viya_playbook/SASViyaV0300*.txt | base64 --wrap=0 )
    fi
    sed ${sed_i_option} "s|SETINIT_TEXT_ENC=|SETINIT_TEXT_ENC=${setinit_enc}|g" container.yml
    sed ${sed_i_option} "s|{{ DOCKER_REGISTRY_URL }}|${DOCKER_REGISTRY_URL}|" container.yml
    sed ${sed_i_option} "s|{{ DOCKER_REGISTRY_NAMESPACE }}|${DOCKER_REGISTRY_NAMESPACE}|" container.yml
    sed ${sed_i_option} "s|{{ PROJECT_NAME }}|${PROJECT_NAME}|" container.yml
    if [[ -n ${CAS_VIRTUAL_HOST} ]]; then
        sed ${sed_i_option} "s|{{ CAS_VIRTUAL_HOST }}|${CAS_VIRTUAL_HOST}|" container.yml
    else
        sed ${sed_i_option} "s|{{ CAS_VIRTUAL_HOST }}|sas-viya|" container.yml
    fi
}

# Generate the Kubernetes resources
function make_deployments() {
    # Force Ansible to show the colored output
    ANSIBLE_FORCE_COLOR=true
    ansible-playbook \
        --connection=local \
        --inventory 127.0.0.1, \
        generate_manifests.yml \
        -e "docker_tag=${SAS_DOCKER_TAG}" \
        -e 'ansible_python_interpreter=/usr/bin/python'
}

# Push built images to the specified docker registry
function push_images() {
    # Sort the services so they are in alphabetical order
    #https://stackoverflow.com/questions/7442417/how-to-sort-an-array-in-bash
    readarray -t sorted_services < <(printf '%s\0' "${all_services[@]}" | sort -z | xargs -0n1)
    for service in "${sorted_services[@]}"; do
        early_exit=false
        done=false
        while [[ "$done" != "true" && "${early_exit}" == "false" ]]; do
            if [[ "$(docker images -q ${PROJECT_NAME}-${service}:latest 2> /dev/null)" != "" ]]; then
                echo "[INFO]  : Pushing ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}"
                docker tag ${PROJECT_NAME}-${service}:latest ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}
                docker push ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}
                echo "[INFO]  : Completed push of ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}"
                done=true
            else
                echo "[INFO]  : Cannot find '${PROJECT_NAME}-${service}:latest'...pausing 30 seconds"
                sleep 30
                # Check a-c process to make sure it did not exit out
                if [[ "$(ps --no-headers ${SAS_ANSIBLE_CONTAINER_PID} | awk '{print $1}')" == "" ]]; then
                    # if a-c is no longer running, break
                    echo "[WARN]  : ansible-controller has stopped but not all images are built."
                    early_exit=true
                fi
            fi
        done
        # Check a-c process to make sure it did not exit out
        # if a-c is no longer running, break
        if [[ "${early_exit}" == "true" ]]; then
            break
        fi
    done

    # Run through it one more time and collect any services that do not have images
    # If we have any services with no images and a-c has exited, then we will assume
    # that a-c exited early and thus we are in a error state and need to return early.
    missing_images=()
    for service in "${sorted_services[@]}"; do
        if [[ "$(docker images -q ${PROJECT_NAME}-${service}:latest 2> /dev/null)" == "" ]]; then
            missing_images+=( ${service} )
        else
            echo "[INFO]  : Second attempt to push ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}"
            docker tag ${PROJECT_NAME}-${service}:latest ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}
            docker push ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}
        fi
    done

    # If we have any images that were not built, then we need to exit
    if (( ${#missing_images[@]} > 0 )); then
        echo "[ERROR] : Looks like ansible-container exited early and not all expected images are built...exiting"
        exit 22
    fi
}
# Use command line options if they have been provided. This overrides environment settings,
while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
        -i|--baseimage)
            shift # past argument
            BASEIMAGE="$1"
            shift # past value
            ;;
        -t|--basetag)
            shift # past argument
            BASETAG="$1"
            shift # past value
            ;;
        -m|--mirror-url)
            shift # past argument
            export SAS_RPM_REPO_URL=$1
            shift # past value
            ;;
        -p|--platform)
            shift # past argument
            export PLATFORM=$1
            shift # past value
            ;;
        -z|--zip)
            shift # past argument
            export SAS_VIYA_DEPLOYMENT_DATA_ZIP=$1
            shift # past value
            ;;
        -k|--skip-mirror-url-validation)
            shift # past argument
            CHECK_MIRROR_URL=false
            ;;
        -d|--skip-docker-url-validation)
            shift # past argument
            CHECK_DOCKER_URL=false
            ;;
        -u|--docker-url|--docker-registry-url)
            shift # past argument
            export DOCKER_REGISTRY_URL="$1"
            shift # past value
            ;;
        -n|--docker-namespace|--docker-registry-namespace)
            shift # past argument
            export DOCKER_REGISTRY_NAMESPACE="$1"
            shift # past value
            ;;
        -e|--environment-setup)
            shift # past argument
            SETUP_VIRTUAL_ENVIRONMENT=true
            ;;
        -v|--virtual-host)
            shift # past argument
            CAS_VIRTUAL_HOST="$1"
            shift # past value
            ;;
        -s|--sas-docker-tag)
            shift # past argument
            SAS_DOCKER_TAG="$1"
            shift # past value
            ;;
    esac
done

# Multi-Container Procedure
function main() {
    echo -e "[INFO]  : Setting up defaults"
    setup_defaults
    echo -e "[INFO]  : Setting up environment"
    setup_environment
    pushd ${PROJECT_DIRECTORY}
    echo -e "[INFO]  : Validating input"
    validate_input
    echo -e "[INFO]  : Setting up logging"
    setup_logging
    echo -e "[INFO]  : Fetching playbook"
    get_playbook
    echo -e "[INFO]  : Creating ansible-container yamls"
    make_ansible_yamls
    echo -e "[INFO]  : Building ansible-container services"
    ansible_build
    echo -e "[INFO]  : Pushing images to registry"
    push_images
    echo -e "[INFO]  : Generating deployments"
    make_deployments

    popd # back to viya-visuals directory
    exit 0
}
main
