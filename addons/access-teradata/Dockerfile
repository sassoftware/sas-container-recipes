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
#   docker build --file Dockerfile  --build-arg BASEIMAGE=viya-single-container --build-arg BASETAG=latest . --tag svc-access-teradata
# 
# RUN:
#   docker run --detach --rm --publish-all --name svc-access-teradata --hostname svc-access-teradata svc-access-teradata
#

ARG BASEIMAGE=viya-single-container
ARG BASETAG=latest

FROM $BASEIMAGE:$BASETAG

ARG PLATFORM=redhat

USER root
RUN set -e; \
    mkdir /tmp/teradata_tools; \
    if [ "$PLATFORM" = "redhat" ]; then \
        rpm --rebuilddb; \
        yum install --assumeyes ksh; \
        yum clean all; \
        rm --verbose --recursive --force /root/.cache /var/cache/yum; \
    elif [ "$PLATFORM" = "suse" ]; then \
        rpm --rebuilddb; \
        zypper install --no-confirm ksh; \
        zypper clean ; \
        rm --verbose --recursive --force /var/cache/zypp; \
    else \
        echo; echo "####### [ERROR] : Unknown platform of \"$PLATFORM\" passed in"; echo; \
        exit 1; \
    fi

ADD teradata.tgz /tmp/teradata_tools/
RUN cd /tmp/teradata_tools/TeradataToolsAndUtilitiesBase && echo a|./setup.bat

ADD teradata_cas.settings /tmp/
ADD teradata_sasserver.sh /tmp/
