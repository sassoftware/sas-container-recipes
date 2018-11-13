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
#
# BUILD:
#   docker build --file Dockerfile_jpy3 --build-arg BASEIMAGE=viya-single-container --build-arg BASETAG=latest --build-arg PLATFORM=redhat . --tag svc-ide-jupyter-python3
#   docker build --file Dockerfile_jpy3 --build-arg BASEIMAGE=viya-single-container --build-arg BASETAG=latest --build-arg PLATFORM=suse . --tag svc-ide-jupyter-python3
# 
# RUN:
#   docker run --detach --rm --publish-all --name svc-ide-jupyter-python3 --hostname svc-ide-jupyter-python3 svc-ide-jupyter-python3
#

ARG BASEIMAGE=viya-single-container
ARG BASETAG=latest

FROM $BASEIMAGE:$BASETAG

ARG PLATFORM=redhat
ARG PROJECT_NAME=sas-viya

USER root
COPY proxy.conf ./jpy3_proxy.conf

RUN set -e; \
     if [ "$PLATFORM" = "redhat" ]; then \
        if [ "$BASEIMAGE" != "viya-single-container" ]; then \
            sed "s/localhost/$PROJECT_NAME-programming/g" ./jpy3_proxy.conf > /etc/httpd/conf.d/jpy3_proxy.conf; \
        else \
            cp ./jpy3_proxy.conf /etc/httpd/conf.d/jpy3_proxy.conf; \
        fi; \
     elif [ "$PLATFORM" = "suse" ]; then \
        if [ "$BASEIMAGE" != "viya-single-container" ]; then \
            sed "s/localhost/$PROJECT_NAME-programming/g" ./jpy3_proxy.conf > /etc/apache2/conf.d/jpy3_proxy.conf; \
        else \
            cp ./jpy3_proxy.conf /etc/apache2/conf.d/jpy3_proxy.conf; \
        fi; \
     else \
         echo; echo "####### [ERROR] : Unknown platform of \"$PLATFORM\" passed in"; echo; \
         exit 1; \
    fi;
