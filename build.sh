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

function sas_container_recipes_shutdown()
{
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

function usage() {
    echo -e "
    Framework to build SAS Viya Docker images and create deployments using Kubernetes.
        https://github.com/sassoftware/sas-container-recipes

    Single Container Arguments:
    ------------------------

        example: ./build.sh --zip ~/my/path/to/SAS_Viya_deploy_data.zip

    Required:

      -z|--zip <value>
          Path to the SAS_Viya_deployment_data.zip file
            example: /path/to/SAS_Viya_deployment_data.zip

      Note: The --type flag is set for a 'single' container deployment by default.

    Optional:

      -a|--addons \"[<value>] [<value>]\"
          A space separated list of layers to add on to the main SAS image.
          See the 'Appendix: Under the Hood' section in the wiki for details
          on adding access engines and other tools.
          https://github.com/sassoftware/sas-container-recipes/wiki/Appendix:-Under-the-Hood
            example: --addons \"addons/auth-sssd addons/access-postgres\"

      -i|--baseimage <value>
          The Docker image from which the SAS images will build on top of
            Default: centos

      -t|--basetag <value>
          The Docker tag for the base image that is being used
            Default: latest

      -m|--mirror-url <value>
          The location of the mirror URL. See the Mirror Manager guide at
          https://support.sas.com/en/documentation/install-center/viya/deployment-tools/34/mirror-manager.html

      -p|--platform <value>
          The type of distribution of the image defined by the \"baseimage\" option.
            Options: [ redhat | suse ]
            Default: redhat

      -k|--skip-mirror-url-validation
          Skips validating the mirror URL from the --mirror-url flag.

      -s|--sas-docker-tag
          The tag to apply to the images before pushing to the Docker registry.
            default: \${recipe_project_version}-\${datetime}-\${last_commit_sha1}
            example: 18.12.0-20181209115304-b197206


    Multi-Container Arguments
    ------------------------

        SAS Viya Programming example:
            ./build.sh --type multiple --zip /path/to/SAS_Viya_deployment_data.zip --addons "addons/auth-demo"

        SAS Viya Visuals example:
            ./build.sh --type full --docker-registry-namespace mynamespace --docker-registry-url my-registry.docker.com --zip /my/path/to/SAS_Viya_deployment_data.zip


      -y|--type [ multiple | full | single ]
          The type of deployment.
            Multiple: SAS Viya Programming Multi-Container deployment with Kubernetes
            Full: SAS Visuals based deployment with Kubernetes.
            Single: One container for SAS Programming. See the "Single Container" guide section.

      -n|--docker-registry-namespace <value>
          The namespace in the Docker registry where Docker
          images will be pushed to. Used to prevent collisions.
            example: mynamespace

      -u|--docker-registry-url <value>
          URL of the Docker registry where Docker images will be pushed to.
            example: 10.12.13.14:5000 or my-registry.docker.com

      -z|--zip <value>
          Path to the SAS_Viya_deployment_data.zip file from your Software Order Email (SOE).
          If you do not know if your organization has a SAS license then contact
          https://www.sas.com/en_us/software/how-to-buy.html

            example: /path/to/SAS_Viya_deployment_data.zip

    Optional:

      -a|--addons \"[<value>] [<value>]\"
          A space separated list of layers to add on to the main SAS image.
          See the 'Appendix: Under the Hood' section in the wiki for details
          on adding access engines and other tools.
          https://github.com/sassoftware/sas-container-recipes/wiki/Appendix:-Under-the-Hood
            example: --addons \"addons/auth-sssd addons/access-postgres\"

      -i|--baseimage <value>
          The Docker image from which the SAS images will build on top of
            Default: centos

      -t|--basetag <value>
          The Docker tag for the base image that is being used
            Default: latest

      -m|--mirror-url <value>
          The location of the mirror URL.See the Mirror Manager guide at
          https://support.sas.com/en/documentation/install-center/viya/deployment-tools/34/mirror-manager.html

      -v|--virtual-host <value>
          The Kubernetes Ingress path that defines the location of the HTTP endpoint.
          For more details on Ingress see the official Kubernetes documentation at
          https://kubernetes.io/docs/concepts/services-networking/ingress/

            example: user-myproject.mylocal.com

      -p|--platform <value>
          The type of distribution of the image defined by the \"baseimage\" option.
            Options: [ redhat ]
            Default: redhat

      -d|--skip-docker-url-validation
          Skips validating the Docker registry URL

      -k|--skip-mirror-url-validation
          Skips validating the mirror URL from the --mirror-url flag.

      -s|--sas-docker-tag
          The tag to apply to the images before pushing to the Docker registry.
            default: \${recipe_project_version}-\${datetime}-\${last_commit_sha1}
            example: 18.12.0-20181209115304-b197206

      ---builder-port
          The port to listen on when serving entitlement and CA certificates to the images that are being built.
          Changing this between builds will prevent Docker layer caching.
            default: 1976

      -h|--help
          Prints out this message. Other resources:
            GitHub Issues for questions, features, and bug reports:
                https://github.com/sassoftware/sas-container-recipes/issues
            GitHub Wiki for FAQs, troubleshooting, and tips.
                https://github.com/sassoftware/sas-container-recipes/wiki
    "
}

trap sas_container_recipes_shutdown SIGTERM
trap sas_container_recipes_shutdown SIGINT

#
# Set some defaults
#

sas_datetime=$(date "+%Y%m%d%H%M%S")
SAS_RECIPE_VERSION=$(cat docs/VERSION)
sas_sha1=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git-sha")
run_args=""

[[ -z ${OPERATING_SYSTEM+x} ]]              && OPERATING_SYSTEM=linux
[[ -z ${SAS_RECIPE_TYPE+x} ]]               && SAS_RECIPE_TYPE=single
[[ -z ${BASEIMAGE+x} ]]                     && BASEIMAGE=centos
[[ -z ${BASETAG+x} ]]                       && BASETAG=7
[[ -z ${PLATFORM+x} ]]                      && PLATFORM=redhat
[[ -z ${SAS_VIYA_CONTAINER+x} ]]            && SAS_VIYA_CONTAINER="viya-single-container"
[[ -z ${SAS_RPM_REPO_URL+x} ]]              && SAS_RPM_REPO_URL=https://ses.sas.download/ses/
[[ -z ${PROJECT_NAME+x} ]]                  && PROJECT_NAME=sas-viya
[[ -z ${SAS_VIYA_DEPLOYMENT_DATA_ZIP+x} ]]  && SAS_VIYA_DEPLOYMENT_DATA_ZIP="SAS_Viya_deployment_data.zip"
[[ -z ${SAS_DOCKER_TAG+x} ]]                && SAS_DOCKER_TAG=${SAS_RECIPE_VERSION}-${sas_datetime}-${sas_sha1}

CHECK_DOCKER_URL=true
CHECK_MIRROR_URL=true
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
        -s|--sas-docker-tag)
            shift # past argument
            export SAS_DOCKER_TAG="$1"
            shift # past value
            ;;
        --builder-port)
            shift # past argument
            export BUILDER_PORT="$1"
            shift # past value
            ;;
        *) # Ignore everything that isn't a valid arg
            shift
    ;;
    esac
done

run_args="${run_args} --mirror-url ${SAS_RPM_REPO_URL}"
run_args="${run_args} --zip /$(basename ${SAS_VIYA_DEPLOYMENT_DATA_ZIP})"
run_args="${run_args} --type ${SAS_RECIPE_TYPE}"
run_args="${run_args} --docker-registry-url ${DOCKER_REGISTRY_URL}"
run_args="${run_args} --docker-namespace ${DOCKER_REGISTRY_NAMESPACE}"
run_args="${run_args} --tag ${SAS_DOCKER_TAG}"
run_args="${run_args} --base-image ${BASEIMAGE}:${BASETAG}"

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

if [[ ${CHECK_MIRROR_URL} == false ]]; then
    run_args="${run_args} --skip-mirror-url-validation"
fi

if [[ -n ${BUILDER_PORT} ]]; then
    run_args="${run_args} --builder-port ${BUILDER_PORT}"
fi

#
# Run
#

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
echo "  Addons                          = ${ADDONS## }"
echo "  Docker registry URL             = ${DOCKER_REGISTRY_URL}"
echo "  Docker registry namespace       = ${DOCKER_REGISTRY_NAMESPACE}"
echo "  Validate Docker registry URL    = ${CHECK_DOCKER_URL}"
echo "  HTTP Ingress endpoint           = ${CAS_VIRTUAL_HOST}"
echo "  Tag SAS will apply              = ${SAS_DOCKER_TAG}"
echo "  Build run args                  = ${run_args## }"
echo

SAS_BUILD_CONTAINER_NAME="sas-container-recipes-builder-${SAS_DOCKER_TAG}"
echo
echo "==============================="
echo "Building Docker Build Container"
echo "==============================="
echo

mkdir -p ${PWD}/builds

DOCKER_GID=$(getent group docker|awk -F: '{print $3}')
USER_GID=$(id -g)

docker build  \
    --label sas.recipe=true \
    --label sas.recipe.builder.version=${SAS_DOCKER_TAG} \
    --build-arg USER_UID=${UID} \
    --build-arg DOCKER_GID=${DOCKER_GID} \
    --tag sas-container-recipes-builder:${SAS_DOCKER_TAG} \
    --file Dockerfile \
    .
echo
echo "=============================="
echo "Running Docker Build Container"
echo "=============================="
echo

docker run -d \
    --name ${SAS_BUILD_CONTAINER_NAME} \
    -u ${UID}:${DOCKER_GID} \
    -v $(realpath ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}):/$(basename ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}) \
    -v ${PWD}/builds:/sas-container-recipes/builds \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v ${HOME}/.docker/config.json:/home/sas/.docker/config.json \
    sas-container-recipes-builder:${SAS_DOCKER_TAG} ${run_args}

docker logs -f ${SAS_BUILD_CONTAINER_NAME}

# find exit status
build_container_exit_status=$(docker inspect ${SAS_BUILD_CONTAINER_NAME} --format='{{.State.ExitCode}}')

docker rm ${SAS_BUILD_CONTAINER_NAME}
exit ${build_container_exit_status}
