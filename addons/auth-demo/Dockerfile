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
#   docker build --file Dockerfile --build-arg BASEIMAGE=viya-single-container --build-arg BASETAG=latest . --tag svc-auth-demo
#
# RUN:
#   docker run --detach --rm --publish-all --name svc-auth-demo --hostname svc-auth-demo svc-auth-demo
#

ARG BASEIMAGE=viya-single-container
ARG BASETAG=latest

FROM $BASEIMAGE:$BASETAG

USER root

WORKDIR /tmp
RUN set -e; \
    yum install --assumeyes  sudo; \
    yum clean all; \
    rm --verbose --recursive --force /root/.cache /var/cache/yum; 
RUN echo "%sas        ALL=(ALL)       NOPASSWD: /usr/sbin/useradd" >> /etc/sudoers
RUN echo "%sas        ALL=(ALL)       NOPASSWD: /usr/sbin/chpasswd" >> /etc/sudoers
RUN echo "%sas        ALL=(ALL)       NOPASSWD: /usr/bin/chown" >> /etc/sudoers
RUN echo "%sas        ALL=(ALL)       NOPASSWD: /usr/bin/chmod" >> /etc/sudoers

#
# Creation of the user is delayed until startup
#
COPY demo_pre_deploy.sh ./010_demo_pre_deploy.sh

USER sas 
