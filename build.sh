#!/bin/bash -e
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
#

# How to have a script log against itself that supports Linux and MacOS
# https://stackoverflow.com/questions/3173131/redirect-copy-of-stdout-to-log-file-from-within-bash-script-itself/5200754#5200754
# For now, we will only log on a linux system. A MacOS system will skip the logging.

unameSystem="$(uname -s)"
case "${unameSystem}" in
    Linux*)     OPERATING_SYSTEM=linux;;
    Darwin*)    OPERATING_SYSTEM=darwin;;
    *)          echo "[WARN] : Unknown system: ${unameSystem}. Will assume Linux."
esac

#
# Setup logging
#

if [[ "${OPERATING_SYSTEM}" != "darwin" ]]; then
    if [ -f "${PWD}/build_sas_container.log" ]; then
        echo
        mkdir -vp ${PWD}/logs
        # shellcheck disable=SC2086
        mv -v ${PWD}/build_sas_container.log ${PWD}/logs/build_sas_container_${sas_datetime}.log
        echo
    fi

    exec > >(tee -a "${PWD}"/build_sas_container.log) 2>&1
fi


### TODO: -r argument 

#
# Functions
#
function usage() {
    echo -e ""
    echo -e "Framework to deploy SAS Viya environments using containers."
    echo -e "   https://github.com/sassoftware/sas-container-recipes/wiki"
    echo -e ""
    echo -e "Single Container Arguments: "
    echo -e "------------------------ "
    echo -e ""
    echo -e " Required: "
    echo -e ""
    echo -e "  -y|--type single        The type of deployment"
    echo -e "                               Options: [ single | multiple | full ]"
    echo -e "                               Default: single"
    echo -e ""
    echo -e "  -z|--zip <value>        Path to the SAS_Viya_deployment_data.zip file"
    echo -e "                              example: /path/to/SAS_Viya_deployment_data.zip"
    echo -e ""
    echo -e " Optional:"
    echo -e ""
    echo -e "  -a|--addons \"<value> [<value>]\"  "
    echo -e "                          A space separated list of layers to add on to the main SAS image"
    echo -e ""
    echo -e ""
    echo -e "Multi-Container Arguments "
    echo -e "------------------------ "
    echo -e ""
    echo -e " Required: "
    echo -e ""
    echo -e "  -y|--type [ multiple | full ] "
    echo -e "                          The type of deployment"
    echo -e ""
    echo -e "  -n|--docker-registry-namespace <value>"
    echo -e "                          The namespace in the Docker registry where Docker"
    echo -e "                           images will be pushed to. Used to prevent collisions."
    echo -e "                               example: mynamespace"
    echo -e ""
    echo -e "  -u|--docker-registry-url <value>"
    echo -e "                          URL of the Docker registry where Docker images will be pushed to."
    echo -e "                               example: 10.12.13.14:5000 or my-registry.docker.com, do not add 'http://' "
    echo -e ""
    echo -e "  -z|--zip <value>"
    echo -e "                          Path to the SAS_Viya_deployment_data.zip file"
    echo -e "                               example: /path/to/SAS_Viya_deployment_data.zip"
    echo -e "      [EITHER/OR]          "
    echo -e ""
    echo -e "  -l|--playbook-dir <value>"
    echo -e "                          Path to the sas_viya_playbook directory. If this is passed in along with the "
    echo -e "                               SAS_Viya_deployment_data.zip then this will take precedence."
    echo -e ""
    echo -e "  -v|--virtual-host "
    echo -e "                          The Kubernetes ingress path that defines the location of the HTTP endpoint."
    echo -e "                               example: user-myproject.mylocal.com" 
    echo -e ""
    echo -e " Optional: "
    echo -e ""
    echo -e "  -i|--baseimage <value>"
    echo -e "                          The Docker image from which the SAS images will build on top of"
    echo -e "                               Default: centos"
    echo -e ""
    echo -e "  -t|--basetag <value>"
    echo -e "                          The Docker tag for the base image that is being used"
    echo -e "                               Default: latest"
    echo -e ""
    echo -e "  -m|--mirror-url <value>"
    echo -e "                          The location of the mirror URL."
    echo -e "                               See https://support.sas.com/en/documentation/install-center/viya/deployment-tools/34/mirror-manager.html"
    echo -e "                               for more information on setting up a mirror."
    echo -e ""
    echo -e "  -p|--platform <value>"
    echo -e "                          The type of operating system we are installing on top of"
    echo -e "                               Options: [ redhat | suse ]"
    echo -e "                               Default: redhat"
    echo -e ""
    echo -e "  -d|--skip-docker-url-validation"
    echo -e "                          Skips validating the Docker registry URL"
    echo -e ""
    echo -e "  -k|--skip-mirror-url-validation"
    echo -e "                          Skips validating the mirror URL"
    echo -e ""
    echo -e "  -e|--environment-setup"
    echo -e "                          Setup python virtual environment"
    echo -e ""
    echo -e "  -s|--sas-docker-tag"
    echo -e "                          The tag to apply to the images before pushing to the Docker registry"
    echo -e ""
    echo -e "  -h|--help               Prints out this message"
    echo -e ""
}

function copy_deployment_data_zip()
{
    local target_location=$1
    if [[ -n ${SAS_VIYA_PLAYBOOK_DIR} ]]; then
        echo "[INFO]  : Copying ${SAS_VIYA_PLAYBOOK_DIR} to ${target_location}"
        cp -a "${SAS_VIYA_PLAYBOOK_DIR}" "${target_location}"
    elif [[ -n ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} ]]; then
        echo "[INFO]  : Copying ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} to ${target_location}"
        cp -v "${SAS_VIYA_DEPLOYMENT_DATA_ZIP}" "${target_location}"
    else
        if [[ ! -f ${target_location}/SAS_Viya_deployment_data.zip ]]; then
            echo "[ERROR] : No SAS_Viya_deployment_data.zip at ${target_location}"
            exit 30
        else
            echo "[INFO]  : Using ${target_location}/SAS_Viya_deployment_data.zip"
        fi
    fi
}

function add_layers()
{
    # Now run through the addons
    # access and auth: added to programming, CAS and compute
    # ide: added to programming
    docker_reg_location=$(echo "${DOCKER_REGISTRY_URL}" | cut -d'/' -f3 )/"${DOCKER_REGISTRY_NAMESPACE}"
    for sas_image in "${PROJECT_NAME}-programming" "${PROJECT_NAME}-computeserver" "${PROJECT_NAME}-sas-casserver-primary" "${PROJECT_NAME}-httpproxy"; do
        # Make sure the image exists
        # shellcheck disable=SC2086
        if [[ "$(docker images -q ${docker_reg_location}/${sas_image}:${SAS_DOCKER_TAG} 2> /dev/null)" != "" ]]; then
            str_previous_image=${sas_image}
            new_image=false
            echo "[INFO]  : Preserve image ${str_previous_image} before it is modified..."
            set -x
            docker tag "${docker_reg_location}"/"${sas_image}:${SAS_DOCKER_TAG}" "${docker_reg_location}"/"${sas_image}:${SAS_DOCKER_TAG}-base"
            set +x
            echo "[INFO]  : ...and now push the preserver image."
            set -x
            docker push "${docker_reg_location}"/"${sas_image}:${SAS_DOCKER_TAG}-base"
            set +x
            for str_image in ${ADDONS}; do
                if [[( "${str_image}" == *"ide"* && "${sas_image}" == "${PROJECT_NAME}-programming" ) || \
                     ( "${str_image}" == *"access"* && "${sas_image}" != "${PROJECT_NAME}-httpproxy" ) || \
                     ( "${str_image}" == *"auth"* && "${sas_image}" != "${PROJECT_NAME}-httpproxy" ) ]]; then

                    echo "[INFO]  : Adding '${str_image}' to '${sas_image}'"
                    pushd "${str_image}"
                    if [ -f "Dockerfile" ]; then
                        new_image=true
                        addon_name=$(basename "${str_image}")
                        str_image_tag=svc-"${addon_name}"
                        echo
                        echo "[INFO]  : Building image '${str_image_tag}'"
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
                            echo "[ERROR] : Could not add layer '${str_image_tag}'"
                            echo
                            popd
                            exit 2
                        fi

                        echo
                        echo "[INFO]  : Image created with image name '${str_image_tag}'"
                        echo
                        str_previous_image="${str_image_tag}"
                    else
                        echo "[WARN]  : No Dockerfile exists in '${PWD}' so skipping building of image"
                    fi
                    popd
                else
                    echo "[INFO]  : Skipping putting '${str_image}' into '${sas_image}'"
                fi
                if [[ "${sas_image}" == "${PROJECT_NAME}-httpproxy" ]]; then
                    echo "[INFO]  : Checking each addon to see if it has a http proxy configuration."
                    pushd "${str_image}"
                    if [ -f "Dockerfile_http" ]; then
                        new_image=true
                        addon_name=$(basename "${str_image}")
                        str_image_tag="svc-${addon_name}-http"
                        echo
                        echo "[INFO]  : Building image '${str_image_tag}'"
                        echo
                        set +e
                        set -x
                        docker build \
                            --file Dockerfile_http \
                            --label "sas.layer.${addon_name}.http=true" \
                            --build-arg BASEIMAGE="${str_previous_image}" \
                            ${BUILD_ARG_PLATFORM} \
                            . \
                            --tag "${str_image_tag}"
                        n_docker_build_rc=$?
                        set +x
                        set -e
                        if (( n_docker_build_rc != 0 )); then
                            echo
                            echo "[ERROR] : Could not add http layer '${str_image_tag}'"
                            echo
                            popd
                            exit 2
                        fi

                        echo
                        echo "[INFO]  : Image created with image name '${str_image_tag}'"
                        echo
                        str_previous_image="${str_image_tag}"
                    else
                        echo "[WARN]  : No Dockerfile_http exists in '${PWD}' so skipping building of image"
                    fi
                    popd
                fi
            done

            # push updated images to docker registry

            # if manifests exist, update the tags for programming, CAS and compute
            if [[ "${new_image}" == "true" ]]; then
                echo "[INFO]  : Base images were adjusted so we need to retag the image..."
                set -x
                docker tag "${str_previous_image}":latest "${docker_reg_location}"/"${sas_image}:${SAS_DOCKER_TAG}"
                set +x
                echo "[INFO]  : ...and now push the image."
                set -x
                docker push "${docker_reg_location}"/"${sas_image}:${SAS_DOCKER_TAG}"
                set +x
            else
                echo "[INFO]  : No base images were adjusted so there are no new images to tag and push."
            fi
        else
            echo "[INFO]  : The image '${sas_image}' doe not exist"
        fi
    done
}

function echo_footer()
{
    echo "[INFO]  : Listing Docker images where \"label=sas.recipe.version=${sas_recipe_version}\" :"
    echo
    docker images --filter "label=sas.recipe.version=${sas_recipe_version}"
    echo
    echo "Kubernetes manifests can be found at $1/manifests/kubernetes."
    echo "One should review the settings of the yaml files in $1/manifests/kubernetes/configmaps/"
    echo "to make sure they contain the desired configuration"
    echo ""
    echo "To deploy a Symmetric Multiple Processor (SMP) environment, run the following"
    echo ""
    echo "kubectl create -f $1/working/manifests/kubernetes/configmaps/"
    echo "kubectl create -f $1/working/manifests/kubernetes/secrets/"
    echo "kubectl create -f $1/working/manifests/kubernetes/deployments-smp/"
    echo ""
    echo "To deploy a Massively Parallel Processing (MPP)environment, run the following"
    echo ""
    echo "kubectl create -f $1/working/manifests/kubernetes/configmaps/"
    echo "kubectl create -f $1/working/manifests/kubernetes/secrets/"
    echo "kubectl create -f $1/working/manifests/kubernetes/deployments-mpp/"
    echo ""
    kubectl version > /dev/null 2>&1 || echo -e "*** Kubernetes (kubectl) is required for the deployment step. See https://kubernetes.io/docs/tasks/tools/install-kubectl/"
}

function missing_dependencies() {
    echo -e "The dependency '$1' is missing. See the README for prerequisites to the build process."
    exit 1
}

function echo_experimental()
{
    echo
    echo "  _______  ______  _____ ____  ___ __  __ _____ _   _ _____  _    _     "
    echo " | ____\ \/ /  _ \| ____|  _ \|_ _|  \/  | ____| \ | |_   _|/ \  | |    "
    echo " |  _|  \  /| |_) |  _| | |_) || || |\/| |  _| |  \| | | | / _ \ | |    "
    echo " | |___ /  \|  __/| |___|  _ < | || |  | | |___| |\  | | |/ ___ \| |___ "
    echo " |_____/_/\_\_|   |_____|_| \_\___|_|  |_|_____|_| \_| |_/_/   \_\_____|"
    echo
}

#
# Set some defaults
#

sas_recipe_version=$(cat docs/VERSION)
sas_datetime=$(date "+%Y%m%d%H%M%S")
sas_sha1=$(git rev-parse --short HEAD || echo "no-git-sha")

[[ -z ${OPERATING_SYSTEM+x} ]]   && OPERATING_SYSTEM=linux
[[ -z ${SAS_RECIPE_TYPE+x} ]]    && SAS_RECIPE_TYPE=single
[[ -z ${BASEIMAGE+x} ]]          && BASEIMAGE=centos
[[ -z ${BASETAG+x} ]]            && BASETAG=latest
[[ -z ${PLATFORM+x} ]]           && PLATFORM=redhat
[[ -z ${SAS_VIYA_CONTAINER+x} ]] && SAS_VIYA_CONTAINER="viya-single-container"
[[ -z ${CHECK_MIRROR_URL+x} ]]   && CHECK_MIRROR_URL=true
[[ -z ${CHECK_DOCKER_URL+x} ]]   && CHECK_DOCKER_URL=true
[[ -z ${SAS_RPM_REPO_URL+x} ]]   && export SAS_RPM_REPO_URL=https://ses.sas.download/ses/
[[ -z ${SAS_DOCKER_TAG+x} ]]     && export SAS_DOCKER_TAG=${sas_recipe_version}-${sas_datetime}-${sas_sha1}
[[ -z ${PROJECT_NAME+x} ]]       && export PROJECT_NAME=sas-viya

# Set options
str_previous_image=${SAS_VIYA_CONTAINER}

# Use command line options if they have been provided. This overrides environment settings,
while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
        -h|--help)
            shift
            usage
            echo
            exit 0
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
        -r|--docker-registry-type)
            shift # past argument
            DOCKER_REGISTRY_TYPE="$1"
            shift # past value
            ;;
        -m|--mirror-url)
            shift # past argument
            export SAS_RPM_REPO_URL=$1
            shift # past value
            ;;
        -p|--platform)
            shift # past argument
            PLATFORM="$1"
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
        -d|--skip-docker-url-validation)
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
        -v|--virtual-host)
            shift # past argument
            export CAS_VIRTUAL_HOST="$1"
            shift # past value
            ;;
        -l|--playbook-dir)
            shift # past argument
            export SAS_VIYA_PLAYBOOK_DIR="$1"
            shift # past value
            ;;
        *)    # Assuming this is an addon for backward compatibility.
            ADDONS="${ADDONS} $1"
            shift # past argument
    ;;
    esac
done

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

echo
echo "=============="
echo "Variable check"
echo "=============="
echo ""
echo "  Build System OS                 = ${OPERATING_SYSTEM}"
echo "  Deployment Type                 = ${SAS_RECIPE_TYPE}"
echo "  BASEIMAGE                       = ${BASEIMAGE}"
echo "  BASETAG                         = ${BASETAG}"
echo "  Mirror URL                      = ${SAS_RPM_REPO_URL}"
echo "  Validate Mirror URL             = ${CHECK_MIRROR_URL}"
echo "  Platform                        = ${PLATFORM}"
echo "  Deployment Data Zip             = ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}"
echo "  Addons                          = ${ADDONS}"
echo "  Docker registry URL             = ${DOCKER_REGISTRY_URL}"
echo "  Docker registry namespace       = ${DOCKER_REGISTRY_NAMESPACE}"
echo "  Docker registry type            = ${DOCKER_REGISTRY_TYPE}"
echo "  Validate Docker registry URL    = ${CHECK_DOCKER_URL}"
echo "  HTTP Ingress endpoint           = ${CAS_VIRTUAL_HOST}"
echo "  Tag SAS will apply              = ${SAS_DOCKER_TAG}"
echo

# Do some validation before we go build images.
accepted_platforms=(suse redhat)
target_platform=$(echo "${BUILD_ARG_PLATFORM:=redhat}" | cut -d'=' -f2)

match=0
for ap in "${accepted_platforms[@]}"; do
    if [ "${ap}" = "${target_platform}" ]; then
        match=1
        break
    fi
done
if (( match == 0 )); then
    echo "[ERROR] : The provided platform of '${target_platform}' is not valid. Please use 'redhat' or 'suse'."
    echo
    exit 10
fi

if [ "${PLATFORM}" = "suse" ] && [[ -z ${SAS_RPM_REPO_URL+x} ]]; then
    echo "[ERROR] : For SuSE based platforms, a mirror must be provided."
    echo
    exit 20
fi

if [[ ! -z ${SAS_RPM_REPO_URL+x} ]] && ${CHECK_MIRROR_URL} && [[ "${SAS_RPM_REPO_URL}" != "https://ses.sas.download/ses/" ]]; then
    set +e
    response=$(curl --write-out "%{http_code}" --silent --location --head --output /dev/null "${SAS_RPM_REPO_URL}")
    set -e
    if [ "${response}" != "200" ]; then
        echo "[ERROR] : Not able to ping mirror URL: ${SAS_RPM_REPO_URL}"
        echo
        exit 5
    else
        echo "[INFO]  : Successful ping of mirror URL: ${SAS_RPM_REPO_URL}"
    fi
else
    echo "[INFO]  : Bypassing validation of mirror URL: ${SAS_RPM_REPO_URL}"
fi

# Currently for anything that is not a "single", the process will build and then
# try to push to the Docker registry. If the correct info is not provided then this
# action will fail. This script will also fail when we try to build the addons.
# For now, validate that if we are doing a multiple of full build, that we
# perform the right set of verification.

if [[ "${SAS_RECIPE_TYPE}" != "single" ]]; then
    if [[ ! -z ${DOCKER_REGISTRY_URL+x} ]] && ${CHECK_DOCKER_URL}; then
        echo "[INFO]  : Running curl against Docker registry URL: https://${DOCKER_REGISTRY_URL}"
        set +e
        set -x
        response=$(curl --write-out "%{http_code}" --silent --location --head --output /dev/null "https://${DOCKER_REGISTRY_URL}")
        set +x
        set -e
        if [ "${response}" != "200" ]; then
            echo "[ERROR] : Not able to ping Docker registry URL: ${DOCKER_REGISTRY_URL}"
            echo
            exit 5
        else
            echo "[INFO]  : Successful ping of Docker registry URL: ${DOCKER_REGISTRY_URL}"
        fi
    else
        echo "[INFO]  : Bypassing validation of Docker registry URL: ${DOCKER_REGISTRY_URL}"
    fi

    if [[ -z ${CAS_VIRTUAL_HOST+x} ]]; then
        echo "[ERROR] : The HTTP ingress path was not passed in. Exiting."
        exit 6
    fi

    if [[ -z ${DOCKER_REGISTRY_URL+x} || -z ${DOCKER_REGISTRY_NAMESPACE+x} ]]; then
        echo "[ERROR] : Trying to use a type of '${SAS_RECIPE_TYPE}' without giving the Docker registry URL or name space"
        exit 7
    fi
fi

echo; # Formatting

#
# Start the process
#

case ${SAS_RECIPE_TYPE} in
    single)
        # Ensure docker is installed
        docker --version || missing_dependencies docker

        copy_deployment_data_zip viya-programming/${SAS_VIYA_CONTAINER}

        echo; # Formatting

        for str_image in ${SAS_VIYA_CONTAINER} ${ADDONS}; do
            if [ "${str_image}" = "${SAS_VIYA_CONTAINER}" ]; then
                pushd viya-programming/"${str_image}"
                echo
                echo "[INFO]  : Building the base image"
                echo
                set +e
                set -x
                docker build \
                    --file Dockerfile \
                    --label "sas.recipe.version=${sas_recipe_version}" \
                    --label "sas.layer.${str_image}=true" \
                    ${BUILD_ARG_BASEIMAGE} \
                    ${BUILD_ARG_BASETAG} \
                    ${BUILD_ARG_SAS_RPM_REPO_URL} \
                    ${BUILD_ARG_PLATFORM} \
                    . \
                    --tag "${str_image}"
                n_docker_build_rc=$?
                set +x
                set -e
                if (( n_docker_build_rc != 0 )); then
                    echo
                    echo "[ERROR] : Could not create base image"
                    echo
                    popd
                    exit 1
                fi
                echo
                echo "[INFO]  : Image created with image name '${str_image}'"
                echo
                str_previous_image="${str_image}"
                popd
            else
                pushd "${str_image}"
                if [ -f "Dockerfile" ]; then
                    addon_name=$(basename "${str_image}")
                    str_image_tag=svc-"${addon_name}"
                    echo
                    echo "[INFO]  : Building image '${str_image_tag}'"
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
                        echo "[ERROR] : Could not add layer '${str_image_tag}'"
                        echo
                        popd
                        exit 2
                    fi

                    echo
                    echo "[INFO]  : Image created with image name '${str_image_tag}'"
                    echo
                    str_previous_image="${str_image_tag}"
                else
                    echo "[WARN]  : No Dockerfile exists in '${PWD}' so skipping building of image"
                fi
                    if [ -f "Dockerfile_http" ]; then
                        new_image=true
                        addon_name=$(basename "${str_image}")
                        str_image_tag="svc-${addon_name}-http"
                        echo
                        echo "[INFO]  : Building image '${str_image_tag}'"
                        echo
                        set +e
                        set -x
                        docker build \
                            --file Dockerfile_http \
                            --label "sas.layer.${addon_name}.http=true" \
                            --build-arg BASEIMAGE="${str_previous_image}" \
                            ${BUILD_ARG_PLATFORM} \
                            . \
                            --tag "${str_image_tag}"
                        n_docker_build_rc=$?
                        set +x
                        set -e
                        if (( n_docker_build_rc != 0 )); then
                            echo
                            echo "[ERROR] : Could not add http layer '${str_image_tag}'"
                            echo
                            popd
                            exit 2
                        fi

                        echo
                        echo "[INFO]  : Image created with image name '${str_image_tag}'"
                        echo
                        str_previous_image="${str_image_tag}"
                    else
                        echo "[WARN]  : No Dockerfile_http exists in '${PWD}' so skipping building of image"
                    fi
                popd
            fi
        done

        set -x
        docker tag "${str_previous_image}:latest" "${PROJECT_NAME}-programming:${SAS_DOCKER_TAG}"
        set +x

        echo "[INFO]  : Listing Docker images:"
        echo
        docker images
        echo
        echo "For the '${PROJECT_NAME}-programming' docker image, you can run the following command to create and start the container:"
        echo "docker run --detach --rm --env CASENV_CAS_VIRTUAL_HOST=$(hostname -f) --env CASENV_CAS_VIRTUAL_PORT=8081 --publish-all --publish 8081:80 --name <docker container name> --hostname <docker hostname> ${PROJECT_NAME}-programming:${sas_recipe_version}-${sas_datetime}-${sas_sha1}"
        echo
        echo "To create and start a container with the 'viya-single-container' image and no addons, submit:"
        echo "docker run --detach --rm --env CASENV_CAS_VIRTUAL_HOST=$(hostname -f) --env CASENV_CAS_VIRTUAL_PORT=8081 --publish-all --publish 8081:80 --name ${PROJECT_NAME}-programming --hostname sas.viya.programming viya-single-container"
        echo
        ;;
    multiple)

        # Check for required dependencies
        docker --version || missing_dependencies docker
        python --version || missing_dependencies python
        pip    --version || missing_dependencies pip

        # Copy the zip or the playbook to project
        copy_deployment_data_zip viya-programming/viya-multi-container

        pushd viya-programming/viya-multi-container

        # Call to build and push images and generate deployment manifests

        # export the values so that they are picked up by the lower level scipt.
        # We will not pass the CHECK_*_URL values here as they are not used in the lower level script
        [[ ! -z ${SAS_RPM_REPO_URL} ]] && export SAS_RPM_REPO_URL

        ./viya-multi-build.sh \
          --baseimage "${BASEIMAGE}" \
          --basetag "${BASETAG}" \
          --platform "${PLATFORM}" \
          --docker-url "${DOCKER_REGISTRY_URL}" \
          --docker-registry-type "${DOCKER_REGISTRY_TYPE}" \
          --docker-namespace "${DOCKER_REGISTRY_NAMESPACE}" \
          --sas-docker-tag "${SAS_DOCKER_TAG}" \
          --virtual-host "${CAS_VIRTUAL_HOST}"

        popd

        # Add more layers to the programming and CAS containers
        add_layers

        # Provide some information to the end user on next steps
        echo_footer viya-programming/viya-multi-container
        ;;
    full)
        echo_experimental

        # Copy the zip or the playbook to project
        copy_deployment_data_zip viya-visuals

        pushd viya-visuals

        # Check for required dependencies
        docker --version || missing_dependencies docker
        python --version || missing_dependencies python
        pip    --version || missing_dependencies pip

        # export the values so that they are picked up by the lower level scipt.
        [[ ! -z ${CHECK_MIRROR_URL} ]] && export CHECK_MIRROR_URL
        [[ ! -z ${CHECK_DOCKER_URL} ]] && export CHECK_DOCKER_URL
        [[ ! -z ${SAS_RPM_REPO_URL} ]] && export SAS_RPM_REPO_URL

        ./viya-visuals-build.sh \
          --baseimage "${BASEIMAGE}" \
          --basetag "${BASETAG}" \
          --platform "${PLATFORM}" \
          --docker-url "${DOCKER_REGISTRY_URL}" \
          --docker-namespace "${DOCKER_REGISTRY_NAMESPACE}" \
          --sas-docker-tag "${SAS_DOCKER_TAG}" \
          --virtual-host "${CAS_VIRTUAL_HOST}"

        popd

        add_layers

        echo_footer viya-visuals
        echo_experimental
        ;;
    *)
        echo "[ERROR] : Unknown type of '${SAS_RECIPE_TYPE}' passed in"
        echo "[INFO]  : Type must be a value of [ single | multiple | full ]"
        ;;
esac


echo; # Formatting

exit 0

