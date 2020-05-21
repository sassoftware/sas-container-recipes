#!/bin/bash -e
#
# build.sh
# Creates a container to run the SAS Container Recipes tool.
# Run `./build.sh --help` or see `docs/usage.txt` for details.
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
#

# Allow running only `./build.sh` to show --help output
function usage() {
    cat docs/usage.txt
}
if [ $# -eq 0 ] ; then
    usage
    exit 0
fi

# Display logs only in Linux.
# Logging on MacOS is currently not supported.
set -e
if [[ -n ${SAS_DEBUG} ]]; then
    set -x
fi
unameSystem="$(uname -s)"
case "${unameSystem}" in
    Linux*)     OPERATING_SYSTEM=linux;;
    Darwin*)    OPERATING_SYSTEM=darwin;;
    *)          echo "[WARN] : Unknown system: ${unameSystem}. Will assume Linux."
esac


function sas_container_recipes_shutdown() {
    echo
    echo "================================"
    echo "Shutting down SAS recipe process"
    echo "================================"
    echo

    set +e
    echo "[INFO]  : Stop ${SAS_BUILD_CONTAINER_NAME} if it is running"
    docker stop ${SAS_BUILD_CONTAINER_NAME}
    echo "[INFO]  : Remove ${SAS_BUILD_CONTAINER_NAME}"
    docker rm -f ${SAS_BUILD_CONTAINER_NAME}
    set -e

    exit 1
}
trap sas_container_recipes_shutdown SIGTERM
trap sas_container_recipes_shutdown SIGINT

# Parse command arguments and flags
while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
        -h|--help)
            shift
            usage
            exit 0
            ;;
        --verbose)
            shift # past argument
            VERBOSE=true
            ;;
        -i|--baseimage|--base-image)
            shift # past argument
            BASEIMAGE="$1"
            shift # past value
            ;;
        -t|--basetag|--base-tag)
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
	    echo -e "\nNote: -k|--skip-mirror-url-validation has been deprecated. This function is no longer performed and its usage can be ignored.\n"
            ;;
        -d|--skip-docker-url-validation)
            shift # past argument
            CHECK_DOCKER_URL=false
            ;;
        --skip-docker-registry-push)
            shift # past argument
            SKIP_DOCKER_REGISTRY_PUSH=true
            ;;
        -a|--addons)
            shift # past argument
            ADDONS="$1"
            shift # past value
            ;;
        -y|--type)
            shift # past argument
            SAS_RECIPE_TYPE="$1"
            shift # past value
            ;;
        -u|--docker-url|--docker-registry-url)
            shift # past argument
            export DOCKER_REGISTRY_URL=$(echo $1 | cut -d'/' -f3)
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
        -j|--project-name)
            shift # past argument
            export PROJECT_NAME="$1"
            shift # past value
            ;;
        --tag)
            shift # past argument
            export SAS_DOCKER_TAG="$1"
            shift # past value
            ;;
        --builder-port)
            shift # past argument
            export BUILDER_PORT="$1"
            shift # past value
            ;;
        --generate-manifests-only)
            shift # past argument
            export GENERATE_MANIFESTS_ONLY=true
            ;;
        -b|--build-only)
            shift # past argument
            export BUILD_ONLY="$1"
            shift # past value
            ;;
        -w|--workers)
            shift # past argument
            export WORKERS="$1"
            shift # past value
            ;;
        *)
            usage
            echo -e "\n\nOne or more arguments were not recognized: \n$@"
            echo
            exit 1
            shift
    ;;
    esac
done

# Set some defaults
[[ -z ${CHECK_DOCKER_URL+x} ]]          && CHECK_DOCKER_URL=true
[[ -z ${SKIP_DOCKER_REGISTRY_PUSH+x} ]] && SKIP_DOCKER_REGISTRY_PUSH=false

git_sha=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git-sha")
datetime=$(date "+%Y%m%d%H%M%S")
sas_recipe_version=$(cat docs/VERSION)
[[ -z ${SAS_DOCKER_TAG+x} ]] && SAS_DOCKER_TAG=${sas_recipe_version}-${datetime}-${git_sha}
SAS_BUILD_CONTAINER_NAME="sas-container-recipes-builder-${SAS_DOCKER_TAG}"
SAS_BUILD_CONTAINER_TAG=${sas_recipe_version}-${datetime}-${git_sha}

# Pass each argument if it exists. Allow the sas-container-recipes binary to catch any missing
# arguments that are required and fill in the default values of those that are not provided.
run_args=""
if [[ -n ${SAS_RPM_REPO_URL} ]]; then
    run_args="${run_args} --mirror-url ${SAS_RPM_REPO_URL}"
fi

if [[ -n ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} ]]; then
    run_args="${run_args} --zip /$(basename ${SAS_VIYA_DEPLOYMENT_DATA_ZIP})"
fi

if [[ -n ${SAS_RECIPE_TYPE} ]]; then
    run_args="${run_args} --type ${SAS_RECIPE_TYPE}"
fi

if [[ -n ${WORKERS} ]]; then
    run_args="${run_args} --workers ${WORKERS}"
fi

if [[ -n ${VERBOSE} ]]; then
    run_args="${run_args} --verbose"
fi

if [[ -n ${DOCKER_REGISTRY_URL} ]]; then
    run_args="${run_args} --docker-registry-url ${DOCKER_REGISTRY_URL}"
fi

if [[ -n ${DOCKER_REGISTRY_NAMESPACE} ]]; then
    run_args="${run_args} --docker-namespace ${DOCKER_REGISTRY_NAMESPACE}"
fi

if [[ -n ${SAS_DOCKER_TAG} ]]; then
    run_args="${run_args} --tag ${SAS_DOCKER_TAG}"
fi

if [[ -n ${BASEIMAGE} ]]; then
    run_args="${run_args} --base-image ${BASEIMAGE}:${BASETAG}"
fi

if [[ -n ${ADDONS} ]]; then
    ADDONS=${ADDONS## } # remove trailing space
    ADDONS=${ADDONS//  /} # replace multiple spaces with a single space
    ADDONS=${ADDONS// /,} # replace spaces with a comma
    run_args="${run_args} --addons ${ADDONS}"
fi

if [[ -n ${CAS_VIRTUAL_HOST} ]]; then
    run_args="${run_args} --virtual-host '${CAS_VIRTUAL_HOST## }'"
fi

if [[ ${CHECK_DOCKER_URL} == false ]]; then
    run_args="${run_args} --skip-docker-url-validation"
fi

if [[ ${GENERATE_MANIFESTS_ONLY} == true ]]; then
    run_args="${run_args} --generate-manifests-only"
fi

if [[ -n ${BUILDER_PORT} ]]; then
    run_args="${run_args} --builder-port ${BUILDER_PORT}"
fi

if [[ -n ${PROJECT_NAME} ]]; then
    run_args="${run_args} --project-name ${PROJECT_NAME}"
fi

if [[ -n ${BUILD_ONLY} ]]; then
    run_args="${run_args} --build-only ${BUILD_ONLY}"
fi

if [[ ${SKIP_DOCKER_REGISTRY_PUSH} == true  ]]; then
    run_args="${run_args} --skip-docker-registry-push"
fi

echo "==============================="
echo "Building Docker Build Container"
echo "==============================="
echo
DOCKER_GID=$(getent group docker|awk -F: '{print $3}')
USER_GID=$(id -g)
mkdir -p ${PWD}/builds
docker build . \
    --label sas.recipe=true \
    --label sas.recipe.builder.version=${SAS_DOCKER_TAG} \
    --build-arg USER_UID=${UID} \
    --build-arg DOCKER_GID=${DOCKER_GID} \
    --tag sas-container-recipes-builder:${SAS_DOCKER_TAG} \
    --file Dockerfile \
    --ulimit memlock=-1


echo
echo "=============================="
echo "Running Docker Build Container"
echo "=============================="
echo
# If a Docker config exists then run the builder with the config mounted as a volume.
# Otherwise, not having a Docker config is acceptable if no registry authentication is required.
DOCKER_CONFIG_PATH=${HOME}/.docker/config.json
if [[ -f ${DOCKER_CONFIG_PATH} ]]; then 
    docker run -d \
        --name ${SAS_BUILD_CONTAINER_NAME} \
        --ulimit memlock=-1 \
        -u ${UID}:${DOCKER_GID} \
        -v $(realpath ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}):/$(basename ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}) \
        -v ${PWD}/builds:/sas-container-recipes/builds \
        -v /var/run/docker.sock:/var/run/docker.sock \
        -v ${HOME}/.docker/config.json:/home/sas/.docker/config.json \
        sas-container-recipes-builder:${SAS_DOCKER_TAG} ${run_args}
else 
    docker run -d \
        --name ${SAS_BUILD_CONTAINER_NAME} \
        --ulimit memlock=-1 \
        -u ${UID}:${DOCKER_GID} \
        -v $(realpath ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}):/$(basename ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}) \
        -v ${PWD}/builds:/sas-container-recipes/builds \
        -v /var/run/docker.sock:/var/run/docker.sock \
        sas-container-recipes-builder:${SAS_DOCKER_TAG} ${run_args}
fi
docker logs -f ${SAS_BUILD_CONTAINER_NAME}


# Clean up and exit
build_container_exit_status=$(docker inspect ${SAS_BUILD_CONTAINER_NAME} --format='{{.State.ExitCode}}')
docker rm ${SAS_BUILD_CONTAINER_NAME}
exit ${build_container_exit_status}
