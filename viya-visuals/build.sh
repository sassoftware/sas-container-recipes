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

function usage() {
    set +x
    echo -e ""
    echo -e " Framework to deploy SAS Viya environments using containers."
    echo -e ""
    echo -e "Single Container Arguments: "
    echo -e "------------------------ "
    echo -e ""
    echo -e " Required: "
    echo -e ""
    echo -e "  -g|--single-container"
    echo -e ""
    echo -e "  -z|--zip <value>         Path to the SAS_Viya_deployment_data.zip file"
    echo -e "                               example: /path/to/SAS_Viya_deployment_data.zip"
    echo -e ""
    echo -e " Optional:"
    echo -e "  -a|--addons \"<value> [<value>]\"  "
    echo -e "                           A space separated list of layers to add on to the main SAS image"
    echo -e ""
    echo -e ""
    echo -e "Multi-Container Arguments "
    echo -e "------------------------ "
    echo -e ""
    echo -e "  Required: "
    echo -e ""

    echo -e "  -n|--docker-namespace <value>"
    echo -e "                           The namespace in the Docker registry where Docker
                                        images will be pushed to. Used to prevent collisions."
    echo -e "                               example: mynamespace"

    echo -e "  -u|--docker-url <value>  URL of the Docker registry where Docker images will be pushed to."
    echo -e "                               example: 10.12.13.14:5000 or my-registry.docker.com, do not add 'http://' "
    echo -e ""

    echo -e "  -z|--zip <value>         Path to the SAS_Viya_deployment_data.zip file"
    echo -e "                               example: /path/to/SAS_Viya_deployment_data.zip"

    echo -e "      [EITHER/OR]          "
    echo -e "                           "

    echo -e "  -l|--playbook <value>    Path to the sas_viya_playbook directory. If this is passed in along with the "
    echo -e "                               SAS_Viya_deployment_data.zip then this will take precedence."

    echo -e "  -v|--virtual-host        The Kubernetes ingress path that defines the location of the HTTP endpoint"
    echo -e "                               example: ? (TODO)"

    # ------------------------
    echo -e ""
    echo -e "  Optional: "
    echo -e ""
    echo -e "  -i|--baseimage <value>   The Docker image from which the SAS images will build on top of"
    echo -e "                               Default: centos"

    echo -e "  -t|--basetag <value>     The Docker tag for the base image that is being used"
    echo -e "                               Default: latest"

    echo -e "  -m|--mirror-url <value>  The location of the mirror URL."
    echo -e "                               See https://support.sas.com/en/documentation/install-center/viya/deployment-tools/34/mirror-manager.html"
    echo -e "                               for more information on setting up a mirror."

    echo -e "  -p|--platform <value>    The type of operating system we are installing on top of"
    echo -e "                               Options: [ redhat | suse ]"
    echo -e "                               Default: redhat"

    echo -e "  -w|--skip-docker-url-validation"
    echo -e "                           Skips validating the Docker registry URL"

    echo -e "  -x|--skip-mirror-url-validation"
    echo -e "                           Skips validating the mirror URL"

    echo -e "  -e|--environment-setup"
    echo -e "                           Setup python virtual environment"

    echo -e "  -s|--sas-docker-tag      The tag to apply to the images before pushing to the Docker registry"
    echo -e "  -d|--debug               Calls 'set -x' for verbose debugging"
    echo -e ""

    echo -e "  -h|--help                Prints out this message"
    echo -e ""
}

# Run the ansible-container build in the clean workspace and build all services.
# Or define the environment variable "REBUILDS" to only build a few services.
# example: export REBUILDS="myservice myotherservice anotherone" ./build.sh ...
# https://www.ansible.com/integrations/containers/ansible-container
function ansible_build() {
    if [[ ! -z ${REBUILDS} ]]; then
        echo -e "Rebuilding services ${REBUILDS}"
        ansible-container build --services $REBUILDS
    else
        ansible-container build
    fi
    build_rc=$?
    set -e
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
    echo -e "  Playbook Location               = ${SAS_VIYA_PLAYBOOK_DIR}"
    echo -e "  Addons                          = ${ADDONS}"
    echo -e "  Docker registry URL             = ${DOCKER_REGISTRY_URL}"
    echo -e "  Docker registry namespace       = ${DOCKER_REGISTRY_NAMESPACE}"
    echo -e "  Validate Docker registry URL    = ${CHECK_DOCKER_URL}"
    echo -e "  Validate Mirror URL             = ${CHECK_MIRROR_URL}"
    echo -e "  Tag SAS will apply              = ${SAS_DOCKER_TAG}"
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

    # Validate that the provided RPM repo URL exists
    if [[ ! -z ${SAS_RPM_REPO_URL+x} ]] && ${CHECK_MIRROR_URL}; then
        mirror_url="${SAS_RPM_REPO_URL}"
        if [[ "${mirror_url}" != "http://"* ]]; then
            echo -e "[ERROR] : The mirror URL of '${mirror_url}' is not using an http based mirror."
            echo -e "[INFO]  : For more information, see https://github.com/sassoftware/sas-container-recipes/blob/master/README.md#use-buildsh-to-build-the-images"
            echo
            exit 30
        fi

        set +e
        response=$(curl --write-out "%{http_code}" --silent --location --head --output /dev/null "${mirror_url}")
        set -e
        if [ "${response}" != "200" ]; then
            echo -e "[ERROR] : Not able to ping mirror URL: ${mirror_url}"
            echo
            exit 5
        fi
    fi

    # Validates that the provided docker registry exists
    if [[ ! -z ${DOCKER_REGISTRY_URL+x} ]] && ${CHECK_DOCKER_URL}; then
        set +e
        response=$(curl --write-out "%{http_code}" --silent --location --head --output /dev/null "https://${DOCKER_REGISTRY_URL}")
        set -e
        if [ "${response}" != "200" ]; then
            echo -e "[ERROR] : Not able to ping Docker registry URL: ${DOCKER_REGISTRY_URL}"
            echo
            exit 5
        fi
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
# tool to create the playbook. Any changes made to this playbook will get
# overridden in the next build.
#
function get_playbook() {
    if [[ -d ${SAS_VIYA_PLAYBOOK_DIR} ]]; then
        # Playbook path given and it's valid
        cp --verbose ${SAS_VIYA_PLAYBOOK_DIR} .

    elif [[ ! -z ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} ]]; then
        # SAS_Viya_deployment_data.zip given and it's valid
        SAS_ORCHESTRATION_LOCATION=${PWD}/../sas-orchestration
        if [[ ! -f ${SAS_ORCHESTRATION_LOCATION} ]]; then
            # Fetch the binary and move it above the working directory
            echo -e "[INFO] : fetching sas-orchestration tool"
            curl --silent --remote-name https://support.sas.com/installation/viya/34/sas-orchestration-cli/lax/sas-orchestration-linux.tgz
            tar xvf sas-orchestration-linux.tgz
            rm --verbose sas-orchestration-linux.tgz
            mv sas-orchestration ../
        fi

        echo -e "[INFO] : Building the playbook from the SOE zip."
        ${SAS_ORCHESTRATION_LOCATION} build \
            --input ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} \
            --platform ${PLATFORM}
            #--repository-warehouse ${SAS_RPM_REPO_URL}
            #--deployment-type programming

        tar xvf SAS_Viya_playbook.tgz
        rm --verbose SAS_Viya_playbook.tgz
        cp --verbose sas_viya_playbook/*.pem .
    else
        echo -e "[ERROR] : Could not find a zip file or playbook to use"
        echo -e ""
        exit 1
    fi
}

function setup_defaults() {
    sas_recipe_version=$(cat templates/VERSION)
    sas_datetime=$(date "+%Y%m%d%H%M%S")
    sas_sha1=$(git rev-parse --short HEAD)

    [[ -z ${SAS_RECIPE_TYPE+x} ]]              && SAS_RECIPE_TYPE=single
    [[ -z ${CHECK_MIRROR_URL+x} ]]             && CHECK_MIRROR_URL=true
    [[ -z ${CHECK_DOCKER_URL+x} ]]             && CHECK_DOCKER_URL=true
    [[ -z ${SETUP_VIRTUAL_ENVIRONMENT+x} ]]    && SETUP_VIRTUAL_ENVIRONMENT=true
    [[ -z ${VIYA_SINGLE_CONTAINER+x} ]]        && VIYA_SINGLE_CONTAINER=false
    [[ -z ${SAS_DOCKER_TAG+x} ]]               && SAS_DOCKER_TAG=${sas_recipe_version}-${sas_datetime}-${sas_sha1}
    [[ -z ${PROJECT_NAME+x} ]]                 && PROJECT_NAME=sas-viya
    [[ -z ${BASEIMAGE+x} ]]                    && BASEIMAGE=centos
    [[ -z ${BASETAG+x} ]]                      && BASETAG="7"
    [[ -z ${SAS_VIYA_DEPLOYMENT_DATA_ZIP+x} ]] && SAS_VIYA_DEPLOYMENT_DATA_ZIP=${PWD}/SAS_Viya_deployment_data.zip
    [[ -z ${SAS_VIYA_PLAYBOOK_DIR+x} ]]        && SAS_VIYA_PLAYBOOK_DIR=${PWD}/sas_viya_playbook
    [[ -z ${PLATFORM+x} ]]                     && PLATFORM=redhat
    [[ -z ${SAS_RPM_REPO_URL+x} ]]             && SAS_RPM_REPO_URL=https://ses.sas.com/download/ses
    [[ -z ${DOCKER_REGISTRY_URL+x} ]]          && DOCKER_REGISTRY_URL=http://docker.company.com
    [[ -z ${DOCKER_REGISTRY_NAMESPACE+x} ]]    && DOCKER_REGISTRY_NAMESPACE=sas

    # Set defaults if environment variables have not been set
    if [ -n "${BASEIMAGE}" ]; then
        BUILD_ARG_BASEIMAGE="--build-arg BASEIMAGE=${BASEIMAGE}"
    fi

    if [ -n "${BASETAG}" ]; then
        BUILD_ARG_BASETAG="--build-arg BASETAG=${BASETAG}"
    fi

    if [ -n "${SAS_RPM_REPO_URL}" ]; then
        BUILD_ARG_SAS_RPM_REPO_URL="--build-arg SAS_RPM_REPO_URL=${SAS_RPM_REPO_URL}"
    fi

    if [ -n "${PLATFORM}" ]; then
        BUILD_ARG_PLATFORM="--build-arg PLATFORM=${PLATFORM}"
    fi
}

# Move everything into a working directory and set up the python virtual environment
function setup_environment() {

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
            pip install ansible-container[docker]
            echo "Updating the client timeout for the created virtual environment."
            echo 'ENV DOCKER_CLIENT_TIMEOUT=600' >> ${VIRTUAL_ENV}/lib/python2.7/site-packages/container/docker/templates/conductor-local-dockerfile.j2
        elif [[ $PYTHON_MAJOR_VER -eq "3" ]]; then
            echo "WARN: Python3 support is experimental in ansible-container."
            echo "Updating requirements file for python3 compatibility..."
            sed -i.bak '/ruamel.ordereddict==0.4.13/d' ./templates/requirements.txt
            pip install --upgrade pip==9.0.3
            pip install -e git+https://github.com/ansible/ansible-container.git@develop#egg=ansible-container[docker]
            echo "Updating the client timeout for the created virtual environment."
            echo 'ENV DOCKER_CLIENT_TIMEOUT=600' >> ${VIRTUAL_ENV}/src/ansible-container/container/docker/templates/conductor-local-dockerfile.j2
        fi
        # Restore latest pip version
        pip install --upgrade pip setuptools
        pip install -r templates/requirements.txt
    fi

    # Start with a clean working space by moving everything into the working directory
    [[ -z ${PROJECT_DIRECTORY+x} ]] && PROJECT_DIRECTORY=working
    if [[ -d ${PROJECT_DIRECTORY}/ ]]; then
      mv "${PROJECT_DIRECTORY}" "${PROJECT_DIRECTORY}_${sas_datetime}"
    fi
    mkdir ${PROJECT_DIRECTORY}
    cp -v templates/container.yml ${PROJECT_DIRECTORY}/
    cp -v templates/generate_manifests.yml ${PROJECT_DIRECTORY}/
}


# Setup the ansible-container directory structure.
#
# ansible-container requires a "roles" directory, a yaml containing all key/value pairs,
# and a container.yml file containing a list of services to build.
#
# https://www.ansible.com/integrations/containers/ansible-container
#
function make_ansible_yamls() {
    # Each directory in the group_vars is a new host
    for file in $(ls -1 sas_viya_playbook/group_vars); do

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

                # Creates the roles/{tasks, templates, vars} directories
                mkdir --parents roles/${file}/tasks
                mkdir --parents roles/${file}/templates
                mkdir --parents roles/${file}/vars

                # Copy the tasks file for the service
                if [ ! -f "roles/${file}/tasks/main.yml" ]; then
                    cp --verbose ../templates/task.yml roles/${file}/tasks/main.yml
                fi

                # Copy the entrypoint file for the service
                if [ ! -f "roles/${file}/templates/entrypoint" ]; then
                    cp --verbose ../templates/entrypoint roles/${file}/templates/entrypoint
                fi

                # Each file in the static-service directory has the same file name as its service name
                # If the file name is the same as the service then the service exists in the order
                is_static=false
                static_services=$(ls ../templates/static-services/)
                for service in ${static_services}; do
                    if [ "${file,,}.yml" == ${service} ]; then
                        # Append static service definition to the working/container.yml
                        cat ../templates/static-services/${service} >> container.yml
                        echo -e "" >> container.yml
                        is_static=true
                    fi
                done

                # Service is not static, meaning it needs to be dynamically created
                if [ $is_static != true ]; then
                    cat >> container.yml <<EOL

  ${file,,}:
    from: "{{ BASEIMAGE }}:{{ BASETAG }}"
    roles:
    - sas-java
    - ${file}
    ports: {}
    entrypoint: ["/opt/sas/viya/home/bin/${file,,}-entrypoint.sh"]
    labels:
      sas.recipe.version: "{{ SAS_RECIPE_VERSION }}"
      sas.layer.${file,,}: "true"
    dev_overrides:
      environment:
        - "SAS_DEBUG=1"
    deployment_overrides:
      volumes:
        - "log=/opt/sas/viya/config/var/log"
      resources:
        limits:
        - "memory=10Gi"
        requests:
        - "memory=2Gi"

EOL
                 fi
            else
                echo -e "*** There are no packages or yum groups in '${file}'"
                echo -e "*** Skipping adding service '${file}' to Docker list"
              fi
            fi
    done

    # Configure ansible-container to pull from an internal registry
    cat >> container.yml <<EOL

registries:
  docker-registry:
    url: ${DOCKER_REGISTRY_URL}
    namespace: ${DOCKER_REGISTRY_NAMESPACE}

volumes:
  static-content:
    docker: {}

EOL

    # Copy over static roles, override others already added in the generated roles
    cp -rf ../templates/static-roles/* roles/

    # For all roles in the playbook's list that are also in in the group_vars directory...
    for role in $(ls -1 roles); do
        if [ -f sas_viya_playbook/group_vars/${role} ]; then

            # Remove previous roles files if they exist
            if [ -f roles/${role}/vars/${role} ]; then
                rm --verbose -f roles/${role}/vars/${role}
            fi

            # Copy the role's vars directory if it exists
            if [ -d roles/${role}/vars ]; then
                cp --verbose sas_viya_playbook/group_vars/${role} roles/${role}/vars/
            fi
        fi
    done

    # When first starting with Ansible-Container, it would not take multiple
    # var files. This section here dumps everything into one file and then
    # adjusts the 'everything' yml file to make sure variables are in the correct order
    echo
    echo "PROJECT_NAME: ${PROJECT_NAME}" > everything.yml
    echo "BASEIMAGE: ${BASEIMAGE}" >> everything.yml
    echo "BASETAG: ${BASETAG}" >> everything.yml
    echo "PLATFORM: ${PLATFORM}" >> everything.yml
    echo "DOCKER_REGISTRY_URL: ${DOCKER_REGISTRY_URL}" >> everything.yml
    echo "DOCKER_REGISTRY_NAMESPACE: ${DOCKER_REGISTRY_NAMESPACE}" >> everything.yml
    echo "SAS_RECIPE_VERSION: ${sas_recipe_version}" >> everything.yml
    echo "" >> everything.yml
    echo "DEPLOYMENT_ID: viya" >> everything.yml
    echo "SPRE_DEPLOYMENT_ID: spre" >> everything.yml

    if [[ ! -z ${INCLUDE_DEMOUSER+x} ]]; then
        echo "INCLUDE_DEMOUSER: yes"
        exit 0
    fi

    cp --verbose sas_viya_playbook/group_vars/all temp_all
    sed -i 's|^DEPLOYMENT_ID:.*||' temp_all
    sed -i 's|^SPRE_DEPLOYMENT_ID:.*||' temp_all
    cat temp_all >> everything.yml
    rm --verbose -f temp_all

    cat sas_viya_playbook/vars.yml >> everything.yml
    cat sas_viya_playbook/internal/soe_defaults.yml >> everything.yml
    sed -i 's|---||g' everything.yml
    sed -i 's|^SERVICE_NAME_DEFAULT|#SERVICE_NAME_DEFAULT|' everything.yml
    sed -i 's|^CONSUL_EXTERNAL_ADDRESS|#CONSUL_EXTERNAL_ADDRESS|' everything.yml
    sed -i 's|^YUM_INSTALL_BATCH_SIZE|#YUM_INSTALL_BATCH_SIZE|' everything.yml
    sed -i 's|^sasenv_license|#sasenv_license|' everything.yml
    sed -i 's|^sasenv_composite_license|#sasenv_composite_license|' everything.yml
    sed -i 's|^METAREPO_CERT_SOURCE|#METAREPO_CERT_SOURCE|' everything.yml
    sed -i 's|^ENTITLEMENT_PATH|#ENTITLEMENT_PATH|' everything.yml
    sed -i 's|^SAS_CERT_PATH|#SAS_CERT_PATH|' everything.yml
    sed -i 's|^SECURE_CONSUL:.*|SECURE_CONSUL: false|' everything.yml
    sed -i "s|#CAS_VIRTUAL_HOST:.*|CAS_VIRTUAL_HOST: '${CAS_VIRTUAL_HOST}'|" everything.yml

    #
    # Update Container yaml
    #

    if [ -f ${PWD}/consul.data ]; then
        consul_data_enc=$(cat ${PWD}/consul.data | base64 --wrap=0 )
        sed -i "s|CONSUL_KEY_VALUE_DATA_ENC=|CONSUL_KEY_VALUE_DATA_ENC=${consul_data_enc}|g" container.yml
    fi

    setinit_enc=$(cat sas_viya_playbook/SASViyaV0300*.txt | base64 --wrap=0 )
    sed -i "s|SETINIT_TEXT_ENC=|SETINIT_TEXT_ENC=${setinit_enc}|g" container.yml
    sed -i "s|SAS_LICENSE=|SAS_LICENSE=$(cat sas_viya_playbook/SASViyaV0300*.jwt)|g" container.yml
    sed -i "s|SAS_CLIENT_CERT=|SAS_CLIENT_CERT=$(cat entitlement_certificate.pem  | base64 --wrap=0 )|g" container.yml
    sed -i "s|SAS_CA_CERT=|SAS_CA_CERT=$(cat SAS_CA_Certificate.pem | base64 --wrap=0 )|g" container.yml
    sed -i "s|{{ DOCKER_REGISTRY_URL }}|${DOCKER_REGISTRY_URL}|" container.yml
    sed -i "s|{{ DOCKER_REGISTRY_NAMESPACE }}|${DOCKER_REGISTRY_NAMESPACE}|" container.yml
    sed -i "s|{{ PROJECT_NAME }}|${PROJECT_NAME}|" container.yml
}

# Generate the Kubernetes resources
function make_deployments() {
    pip install ansible==2.7
    ansible-playbook generate_manifests.yml -e "docker_tag=${SAS_DOCKER_TAG}" -e 'ansible_python_interpreter=/usr/bin/python'
}

# Push built images to the specified private docker registry
function push_images() {
    # Example line: `ansible-container push --push-to my-company-repo --tag 18.10.0-20181120130951-4887f72`
    # This pushes all images defined in the container.yml file to the registry defined in the container.yml
    #
    # Within the container.yml there is something similar to:
    #
    # registries:
    #   docker-registry: <--- This is the name used in the "--push-to". The url is NOT used in --push-to.
    #     url: docker.mycompany.com
    #     namespace: mynamespace
    set -x
    echo -e "ansible-container push --push-to ${DOCKER_REGISTRY_URL} --tag ${SAS_DOCKER_TAG}"
    ansible-container push --push-to docker-registry --tag ${SAS_DOCKER_TAG}
    set +x
}

# Steps mirrored in documentation - show the user what comes next
function show_next_steps() {
    echo -e ""
    echo -e "Success. The manifests directory contains all Kubernetes deployment resources."
    echo -e "To import your resources use \`kubectl (create|replace) --filename deploy/kubernetes/ ... \`"
    echo -e ""
}


# Use command line options if they have been provided and overrides environment settings
while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
        -h|--help)
            shift
            usage
            echo
            exit 0
            ;;
        -d|--debug)
            shift # past argument
            export DEBUG=true
            shift # past value
            ;;
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
        -w|--skip-mirror-url-validation)
            shift # past argument
            CHECK_MIRROR_URL=false
            ;;
        -x|--skip-docker-url-validation)
            shift # past argument
            CHECK_DOCKER_URL=false
            ;;
        -u|--docker-url)
            shift # past argument
            export DOCKER_REGISTRY_URL="$1"
            shift # past value
            ;;
        -n|--docker-namespace)
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
        -l|--playbook)
            shift # past argument
            SAS_VIYA_PLAYBOOK_DIR="$1"
            shift # past value
             ;;
        -g|--single-container) shift # past argument
            VIYA_SINGLE_CONTAINER=true
            shift # past value
             ;;
        -s|--sas-docker-tag)
            shift # past argument
            SAS_DOCKER_TAG="$1"
            shift # past value
            ;;
        *)  echo -e "Invalid argument: $1"
            exit 1;
            shift # past argument
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
    echo -e "[INFO]  : Generating deployments"
    make_deployments
    echo -e "[INFO]  : Pushing images to registry"
    push_images
    popd # back to viya-visuals directory

    show_next_steps
    exit 0
}
main
