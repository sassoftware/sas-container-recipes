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

sas_version=$(cat VERSION)
sas_datetime=$(date "+%Y%m%d%H%M%S")
sas_sha1=$(git rev-parse --short HEAD)

# How to use 
# build.sh addons/auth-demo addons/ide-jupyter-python3

[[ -z ${SAS_VIYA_CONTAINER+x} ]] && SAS_VIYA_CONTAINER="viya-single-container"

#
# Setup logging
#

if [ -f "${PWD}/build_sas_container.log" ]; then
    echo
    mv -v ${PWD}/build_sas_container.log ${PWD}/build_sas_container_${sas_datetime}.log
    echo
fi

exec > >(tee -a ${PWD}/build_sas_container.log) 2>&1

#
# Start the process
#

str_previous_image=${SAS_VIYA_CONTAINER}

if [ -n "${BASEIMAGE}" ]; then
    BUILD_ARG_BASEIMAGE="--build-arg BASEIMAGE=${BASEIMAGE}"
fi

if [ -n "${BASETAG}" ]; then
    BUILD_ARG_BASETAG="--build-arg BASETAG=${BASETAG}"
fi

if [ -n "${SAS_RPM_REPO_URL}" ]; then
    if [[ "${SAS_RPM_REPO_URL}" != "http://"* ]]; then
        echo "[ERROR] : The mirror URL of '${SAS_RPM_REPO_URL}' is not using an http based mirror."
        echo "[INFO]  : For more information, see https://github.com/sassoftware/sas-container-recipes/blob/master/README.md#use-buildsh-to-build-the-images"
        exit 30
    fi
    BUILD_ARG_SAS_RPM_REPO_URL="--build-arg SAS_RPM_REPO_URL=${SAS_RPM_REPO_URL}"
fi

if [ -n "${PLATFORM}" ]; then
    BUILD_ARG_PLATFORM="--build-arg PLATFORM=${PLATFORM}"
fi

for str_image in ${SAS_VIYA_CONTAINER} $@; do
    if [ "${str_image}" = "${SAS_VIYA_CONTAINER}" ]; then
        pushd viya-programming/${str_image}
        echo
        echo "[INFO]  : Building the base image"
        echo
        set +e
        set -x
        docker build \
            --file Dockerfile \
            --label "sas.recipe.version=${sas_version}" \
            --label "sas.layer.${str_image}=true" \
            ${BUILD_ARG_BASEIMAGE} \
            ${BUILD_ARG_BASETAG} \
            ${BUILD_ARG_SAS_RPM_REPO_URL} \
            ${BUILD_ARG_PLATFORM} \
            . \
            --tag ${str_image}
        n_docker_build_rc=$?
        set +x
        set -e
        if (( ${n_docker_build_rc} != 0 )); then
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
        pushd ${str_image}
        if [ -f "Dockerfile" ]; then
            str_image_tag="svc-$(basename $(echo ${str_image}))"
            echo
            echo "[INFO]  : Building image '${str_image_tag}'"
            echo
            set +e
            set -x
            docker build \
                --file Dockerfile \
                --label "sas.layer.$(basename $(echo ${str_image}))=true" \
                --build-arg BASEIMAGE=${str_previous_image} \
                ${BUILD_ARG_PLATFORM} \
                . \
                --tag ${str_image_tag}
            n_docker_build_rc=$?
            set +x
            set -e
            if (( ${n_docker_build_rc} != 0 )); then
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
    fi
done

set -x
docker tag ${str_previous_image}:latest sas-viya-programming:${sas_version}-${sas_datetime}-${sas_sha1}
set +x

echo "[INFO]  : Listing Docker images:"
echo
docker images
echo
echo "For the 'sas-viya-programming' docker image, you can run the following command to create and start the container:"
echo "docker run --detach --rm --env CASENV_CAS_VIRTUAL_HOST=$(hostname -f) --env CASENV_CAS_VIRTUAL_PORT=8081 --publish-all --publish 8081:80 --name <docker container name> --hostname <docker hostname> sas-viya-programming:${sas_version}-${sas_datetime}-${sas_sha1}"
echo
echo "To create and start a container with the 'viya-single-container' image and no addons, submit:"
echo "docker run --detach --rm --env CASENV_CAS_VIRTUAL_HOST=$(hostname -f) --env CASENV_CAS_VIRTUAL_PORT=8081 --publish-all --publish 8081:80 --name sas-viya-programming --hostname sas.viya.programming viya-single-container"
echo

exit 0

