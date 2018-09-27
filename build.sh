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

# How to use 
# build.sh addons/auth-demo addons/ide-jupyter-python3

[[ -z ${SAS_VIYA_CONTAINER+x} ]] && SAS_VIYA_CONTAINER="viya-single-container"
str_now=$(date +"%Y%m%d%H%M")

#
# Setup logging
#

if [ -f "${PWD}/build_sas_container.log" ]; then
    mv --verbose ${PWD}/build_sas_container.log ${PWD}/build_sas_container_$(date +"%Y%m%d%H%M").log
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

for str_image in ${SAS_VIYA_CONTAINER} $@; do
    if [ "${str_image}" = "${SAS_VIYA_CONTAINER}" ]; then
        pushd viya-programming/${str_image}
        echo "[INFO]  : Building the base image"
        echo
        set +e
        set -x
        docker build --file Dockerfile ${BUILD_ARG_BASEIMAGE} ${BUILD_ARG_BASETAG} . --tag ${str_image}
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
            #str_image_tag="svp_${str_image}"
            str_image_tag="svc-$(basename $(echo ${str_image}))"
            echo
            echo "[INFO]  : Building image '${str_image_tag}'"
            echo
            set +e
            set -x
            docker build --file Dockerfile --build-arg BASEIMAGE=${str_previous_image} . --tag ${str_image_tag}
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

echo "[INFO]  : Listing Docker images:"
echo
docker images
echo
echo "For any of the docker images beginning with 'svc-', you can do run the following command to create and start the container:"
echo "docker run --detach --rm --env CASENV_CAS_VIRTUAL_HOST=$(hostname -f) --env CASENV_CAS_VIRTUAL_PORT=8081 --publish-all --publish 8081:80 --name sas-viya-programming --hostname sas.viya.programming <docker image>"
echo
exit 0

