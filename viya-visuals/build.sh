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
    echo -e ""
    echo -e " Framework to deploy SAS Viya environments using containers."
    echo -e ""


    # Required Arguments
    # ------------------------ 
    echo -e " Required Arguments: "
    echo -e ""

    echo -e "  -n|--docker-namespace <value>"
    echo -e "                           The namespace in the Docker registry where Docker 
                                        images will be pushed to. Used to prevent collisions."
    echo -e "                               example: mynamespace"

    echo -e "  -u|--docker-url <value>  URL of the Docker registry where Docker images will be pushed to."
    echo -e "                               example: 10.12.13.14 or my-registry.docker.com"
    echo -e ""

    echo -e "  -z|--zip <value>         Path to the SAS_Viya_deployment_data.zip file"
    echo -e "                               example: /path/to/SAS_Viya_deployment_data.zip"


    # ------------------------ 
    echo -e " Optional Arguments: "
    echo -e ""

    echo -e "  -a|--addons \"<value> [<value>]\"  "
    echo -e "                           A space separated list of layers to add on to the main SAS image"

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

    echo -e "  -s|--skip-docker-url-validation" 
    echo -e "                           Skips validating the Docker registry URL"

    echo -e "  -k|--skip-mirror-url-validation"
    echo -e "                           Skips validating the mirror URL"

    echo -e "  -h|--help                Prints out this message"
}

function add_layers() {
    # Now run through the addons
    # access and auth get put on programming, CAS and compute
    # ide are added to programming
    # using sas-viya, but this is probably something else that could be made a variable
    docker_reg_location=$(echo -e "${DOCKER_REGISTRY_URL}" | cut -d'/' -f3 )/"${DOCKER_REGISTRY_NAMESPACE}"
    for sas_image in sas-viya-programming sas-viya-computeserver sas-viya-sas-casserver-primary; do
        # Make sure the image exists
        # shellcheck disable=SC2086
        if [[ "$(docker images -q ${docker_reg_location}/${sas_image}:${SAS_DOCKER_TAG} 2> /dev/null)" != "" ]]; then
            str_previous_image=${sas_image}
            new_image=false
            for str_image in ${ADDONS}; do
                if ([[ "${str_image}" == *"ide"* ]] && [ "${sas_image}" = "sas-viya-programming" ]) || \
                   [[ "${str_image}" == *"access"* ]] || \
                   [[ "${str_image}" == *"auth"* ]]; then

                    echo -e "[INFO]  : Adding '${str_image}' to '${sas_image}'"
                    pushd "${str_image}"
                    if [ -f "Dockerfile" ]; then
                        new_image=true
                        addon_name=$(basename "${str_image}")
                        str_image_tag=svc-"${addon_name}"
                        echo
                        echo -e "[INFO]  : Building image '${str_image_tag}'"
                        echo
                        set +e
                        set -x
                        docker build \
                            --file Dockerfile \
                            --label sas.layer."${addon_name}"=true \
                            --build-arg BASEIMAGE="${str_previous_image}" \
                            ${BUILD_ARG_PLATFORM} \
                            . \
                            --tag "${str_image_tag}"
                        n_docker_build_rc=$?
                        set +x
                        set -e
                        if (( n_docker_build_rc != 0 )); then
                            echo
                            echo -e "[ERROR] : Could not add layer '${str_image_tag}'"
                            echo
                            popd
                            exit 2
                        fi

                        echo
                        echo -e "[INFO]  : Image created with image name '${str_image_tag}'"
                        echo
                        str_previous_image="${str_image_tag}"
                    else
                        echo -e "[WARN]  : No Dockerfile exists in '${PWD}' so skipping building of image"
                    fi
                    popd
                else
                    echo -e "[INFO]  : Skipping putting '${str_image}' into '${sas_image}'"
                  fi
            done
        fi
    done
}

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

# Set some defaults sas_version=$(cat templates/VERSION) sas_datetime=$(date +"%Y%m%d%H%M%S")
sas_version=$(cat templates/VERSION)
sas_datetime=$(date "+%Y%m%d%H%M%S")
sas_sha1=$(git rev-parse --short HEAD)

[[ -z ${SAS_RECIPE_TYPE+x} ]]         && SAS_RECIPE_TYPE=single
[[ -z ${CHECK_MIRROR_URL+x} ]]        && CHECK_MIRROR_URL=true
[[ -z ${CHECK_DOCKER_URL+x} ]]        && CHECK_DOCKER_URL=false
[[ -z ${SAS_DOCKER_TAG+x} ]]          && SAS_DOCKER_TAG=${sas_version}-${sas_datetime}-${sas_sha1}
[[ -z ${DOCKER_REGISTRY_URL+x} ]]     && DOCKER_REGISTRY_URL=localhost
[[ -z ${DOCKER_REGISTRY_NAMESPACE} ]] && DOCKER_REGISTRY_NAMESPACE=$USER
[[ -n "${BASEIMAGE}" ]]               && BUILD_ARG_BASEIMAGE="--build-arg BASEIMAGE=${BASEIMAGE}"
[[ -n "${BASETAG}" ]]                 && BUILD_ARG_BASETAG="--build-arg BASETAG=${BASETAG}"
[[ -n "${SAS_RPM_REPO_URL}" ]]        && BUILD_ARG_SAS_RPM_REPO_URL="--build-arg SAS_RPM_REPO_URL=${SAS_RPM_REPO_URL}"
[[ -n "${PLATFORM}" ]]                && BUILD_ARG_PLATFORM="--build-arg PLATFORM=${PLATFORM}"

# Use command line options if they have been provided. 
# This overrides environment settings.
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
            BUILD_ARG_BASEIMAGE="--build-arg BASEIMAGE=$1"
            shift # past value
            ;;
        -t|--basetag)
            shift # past argument
            BUILD_ARG_BASETAG="--build-arg BASETAG=$1"
            shift # past value
            ;;
        -m|--mirror-url)
            shift # past argument
            export SAS_RPM_REPO_URL=$1
            BUILD_ARG_SAS_RPM_REPO_URL="--build-arg SAS_RPM_REPO_URL=${SAS_RPM_REPO_URL}"
            shift # past value
            ;;
        -p|--platform)
            shift # past argument
            export PLATFORM=$1
            BUILD_ARG_PLATFORM="--build-arg PLATFORM=${PLATFORM}"
            shift # past value
            ;;
        -z|--zip)
            shift # past argument
            SAS_VIYA_DEPLOYMENT_DATA_ZIP="$1"
            shift # past value
            ;;
        -k|--skip-mirror-url-validation)
            shift # past argument
            CHECK_MIRROR_URL=false
            ;;
        -s|--skip-docker-url-validation)
            shift # past argument
            CHECK_DOCKER_URL=false
            ;;
        -a|--addons)
            shift # past argument
            ADDONS="${ADDONS} $1"
            shift # past value
            ;;
        -y|--type)
            shift # past argument
            SAS_RECIPE_TYPE="$1"
            shift # past value
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
        *)  echo -e "Invalid argument: $1"
            exit 1;
            shift # past argument
    ;;
    esac
done


function setup_logging() {
    echo "" > result-${sas_datetime}.log
    exec > >(tee -a "${PWD}"/build_sas_container.log) 2>&1
    echo
    echo -e "  Deployment Type                 = ${SAS_RECIPE_TYPE}"
    # shellcheck disable=SC2086
    echo -e "  BASEIMAGE                       = $(echo ${BUILD_ARG_BASEIMAGE:=centos} | cut -d'=' -f2)"
    # shellcheck disable=SC2086
    echo -e "  BASETAG                         = $(echo ${BUILD_ARG_BASETAG:=latest} | cut -d'=' -f2)"
    # shellcheck disable=SC2086
    echo -e "  Mirror URL                      = $(echo ${BUILD_ARG_SAS_RPM_REPO_URL} | cut -d'=' -f2)"
    echo -e "  Validate Mirror URL             = ${CHECK_MIRROR_URL}"
    # shellcheck disable=SC2086
    echo -e "  Platform                        = $(echo ${BUILD_ARG_PLATFORM:=redhat} | cut -d'=' -f2)"
    echo -e "  Deployment Data Zip             = ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}"
    echo -e "  Addons                          = ${ADDONS}"
    echo -e "  Docker registry URL             = ${DOCKER_REGISTRY_URL}"
    echo -e "  Docker registry namespace       = ${DOCKER_REGISTRY_NAMESPACE}"
    echo -e "  Validate Docker registry URL    = ${CHECK_DOCKER_URL}"
    echo
}

function validate_input() {

    # Validate that required arguments were provided
    #if [ -z ${DOCKER_REGISTRY_URL} ||  -z ${DOCKER_REGISTRY_NAMESPACE} ||  -z ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} ]; then
    #    usage  
    #    exit 1
    #fi 

    # Validate that the provided platform is accepted
    accepted_platforms=(suse redhat)
    target_platform=$(echo -e "${BUILD_ARG_PLATFORM:=redhat}" | cut -d'=' -f2)
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
        mirror_url=$(echo -e "${BUILD_ARG_SAS_RPM_REPO_URL}" | cut -d'=' -f2)
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
        else
            echo -e "[INFO]  : Successful ping of mirror URL: ${mirror_url}"
        fi
    else
        echo -e "[INFO]  : Bypassing validation of mirror URL: ${mirror_url}"
    fi

    # Validates that the provided docker registry exists
    if [[ ! -z ${DOCKER_REGISTRY_URL+x} ]] && ${CHECK_DOCKER_URL}; then
        set +e
        response=$(curl --write-out "%{http_code}" --silent --location --head --output /dev/null "${DOCKER_REGISTRY_URL}")
        set -e
        if [ "${response}" != "200" ]; then
            echo -e "[ERROR] : Not able to ping Docker registry URL: ${DOCKER_REGISTRY_URL}"
            echo
            exit 5
        else
        echo -e "[INFO]  : Successful ping of Docker registry URL: ${DOCKER_REGISTRY_URL}"
    fi
    else
        echo -e "[INFO]  : Bypassing validation of Docker registry URL: ${DOCKER_REGISTRY_URL}"
    fi

    if [[ ( -z ${DOCKER_REGISTRY_URL+x} || -z ${DOCKER_REGISTRY_URL+x} ) && "${SAS_RECIPE_TYPE}" != "single" ]]; then
        echo -e "[ERROR] : Trying to use a type of '${SAS_RECIPE_TYPE}' without giving the Docker registry URL or name space"
        echo
        exit 6
    fi
}

function get_playbook() {
    echo -e "[INFO]  : Generating  playbook"
    sas-orchestration build --input ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}
    tar xvf SAS_Viya_playbook.tgz
    rm SAS_Viya_playbook.tgz
    cp sas_viya_playbook/*.pem .
}

# Move everything into a working directory to isolate the debugging space
setup_environment() {
    if [[ -d debug/ ]]; then 
       rm -rf debug/
    fi
    mkdir debug/
    cp templates/container.yml debug/
    cp templates/generate_manifests.yml debug/
    cd debug
}


function make_ansible_yamls() {
    for file in $(ls -1 sas_viya_playbook/group_vars); do
        echo -e "*** Create the roles directory for the host groups"
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
            
                echo "***   Create the roles directory for service '${file}'"; echo
                mkdir --parents --verbose roles/${file}/tasks
                mkdir --parents --verbose roles/${file}/templates
                mkdir --parents --verbose roles/${file}/vars
               
                if [ ! -f "roles/${file}/tasks/main.yml" ]; then
                    echo; echo "***     Copy the tasks file for service '${file}'"; echo
                    cp --verbose ../templates/task.yml roles/${file}/tasks/main.yml
                else
                    echo; echo "***     Tasks file for service '${file}' already exists"; echo
                fi

                if [ ! -f "roles/${file}/templates/entrypoint" ]; then
                    echo; echo "***     Copy the entrypoint file for service '${file}'"; echo
                    cp --verbose ../templates/entrypoint roles/${file}/templates/entrypoint
                else
                    echo; echo "***     entrypoint file for service '${file}' already exists"; echo
                fi

                # Each file in the static-service directory has the same file name as its service name
                # If the file name is the same as the service then the service exists in the order
                is_static=false
                static_services=$(ls ../templates/static-services/)
                for service in ${static_services}; do
                    if [ "${file,,}.yml" == ${service} ]; then
                        # Append static service definition to the debug/container.yml
                        cat ../templates/static-services/${service} >> container.yml
                        echo -e "" >> container.yml
                        is_static=true
                    fi
                done

                # Service is not static, meaning it needs to be dynamically created
                if [ ! $is_static ]; then
                    cat >> container.yml <<EOL

      ${file,,}:
        from: "centos:7"
        roles:
        - sas-java
        - ${file}
        ports: {}
        entrypoint: ["/opt/sas/viya/home/bin/${file,,}-entrypoint.sh"]
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
                echo -e "*** Skipping adding service '${file}' to Docker list" fi
            fi 
        fi
    done

    # Configure ansible-container to pull from an internal registry
    cat >> container.yml <<EOL

registries: 
  internal-sas:
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
                sudo rm -v roles/${role}/vars/${role}
            fi
            
            # Copy the role's vars directory if it exists
            if [ -d roles/${role}/vars ]; then
                cp -v sas_viya_playbook/group_vars/${role} roles/${role}/vars/
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
    echo "" >> everything.yml
    echo "DEPLOYMENT_ID: viya" >> everything.yml
    echo "SPRE_DEPLOYMENT_ID: spre" >> everything.yml

    if [[ ! -z ${INCLUDE_DEMOUSER+x} ]]; then
        echo "INCLUDE_DEMOUSER: yes"
        exit 0
    fi

    cp sas_viya_playbook/group_vars/all temp_all
    sed -i 's|^DEPLOYMENT_ID:.*||' temp_all
    sed -i 's|^SPRE_DEPLOYMENT_ID:.*||' temp_all
    cat temp_all >> everything.yml
    sudo rm -v temp_all

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
}

# Generate the Kubernetes configs
function make_deployments() {
    ansible-playbook generate_manifests.yml -e "docker_tag=${SAS_DOCKER_TAG}" -e 'ansible_python_interpreter=/usr/bin/python'
    if [[ -d ../deploy ]]; then
        rm -rf ../deploy
    fi
    mv deploy/ ../
}

# Push built images to the specified private docker registry
function push_images() {
    set -x
    for role in $(ls roles/); do
        docker tag sas-viya-${role,,} ${DOCKER_REGISTRY_URL}:5000/${DOCKER_REGISTRY_NAMESPACE}/sas-viya-${role,,} && \
        docker push ${DOCKER_REGISTRY_URL}:5000/${DOCKER_REGISTRY_NAMESPACE}/sas-viya-${role,,}:latest
    done
    set +x

}

setup_environment  # Make the working directory "debug/" and copy in templates
validate_input     # Check provided arguments
setup_logging      # Show build variables and enable logging if debug is on
get_playbook       # From an SOE zip or previous playbook
make_ansible_yamls # Create the container.yml and everything.yml
add_layers         # Addons and docker push to registry
ansible_build      # Build services from continer.yml 
push_images        # Transfer images to defined registry
make_deployments   # Generate Kubernetes configs
exit 0

