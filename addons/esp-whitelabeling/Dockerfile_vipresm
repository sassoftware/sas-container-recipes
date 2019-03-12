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

ARG BASEIMAGE=sas-viya-espstudio
ARG BASETAG=latest

FROM $BASEIMAGE:$BASETAG

ARG PLATFORM=redhat
ARG PROJECT_NAME=sas-viya

USER root

COPY override/ /opt/sas/viya/config/data/esp/whitelabel/override/
COPY whitelabel.conf /opt/sas/viya/config/etc/sysconfig/esm-webui.conf
COPY config.yml /opt/sas/viya/home/share/esp/whitelabel/config.yml
