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
# build.sh 
#    --type [single | multiple | visuals]   Default=single
#    --baseimage                            Default=centos
#    --basetag                              Default=latest
#    --platform [redhat | suse ]            Default=suse
#    --addons "auth-demo,access-odbc"       Default=empty
#    --mirror                               Default=empty
#    --docker-url                           Default=empty
#    --docker-namespace                     Default=sas
#    --deploy-target [compose | kubernetes] Default=kubernetes

if [ "$type" = "single" ]; then
    cp zip file to viya-programming/viya-multi-container
    current steps
elif [ "$type" = "multiple" ]; then
    cp zip file to viya-programming/viya-multi-container
    pushd viya-programming/viya-multi-container
    ./setup_ac.sh
    ./build_images.sh
    if [ -n "${docker-url}" ]; then
        ./push_images.sh
    fi
elif [ "$type" = "visuals" ]; then
    cp zip file to viya-visuals/viya-multi-container
    pushd viya-visuals/viya-multi-container
    ./setup_ac.sh
    ./build_images.sh
    if [ -n "${docker-url}" ]; then
        ./push_images.sh
    fi
else
    echo unknown
fi

exit 0

