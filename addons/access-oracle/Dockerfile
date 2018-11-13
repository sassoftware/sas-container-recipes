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
#   docker build --file Dockerfile  --build-arg BASEIMAGE=viya-single-container --build-arg BASETAG=latest . --tag svc-access-oracle
# 
# RUN:
#   docker run --detach --rm --publish-all --name svc-access-oracle --hostname svc-access-oracle svc-access-oracle
#

ARG BASEIMAGE=viya-single-container
ARG BASETAG=latest

FROM $BASEIMAGE:$BASETAG

ARG PLATFORM=redhat

USER root

ADD *.rpm /tmp/oracle/
ADD oracle_cas.settings /tmp/
ADD oracle_sasserver.sh /tmp/
ADD tnsnames.ora /etc/

RUN set -e; \
    mkdir -p /tmp/oracle; \
    if [ "$PLATFORM" = "redhat" ]; then \
        rpm --rebuilddb; \
        yum install --assumeyes /tmp/oracle/*.rpm; \
        yum clean all; \
        rm --verbose --recursive --force /root/.cache /var/cache/yum; \
    elif [ "$PLATFORM" = "suse" ]; then \
        rpm --rebuilddb; \
        zypper --no-gpg-checks install --no-confirm /tmp/oracle/*.rpm; \
        zypper clean ; \
        rm --verbose --recursive --force /var/cache/zypp; \
    else \
        echo; echo "####### [ERROR] : Unknown platform of \"$PLATFORM\" passed in"; echo; \
        exit 1; \
    fi

# SAS needs v11.1 but symlinking to your installed version will work.
RUN source /tmp/oracle_cas.settings; \
    if [[ ! -f $ORACLE_HOME/lib/libclntsh.so.11.1 ]]; then \
        ln -s $ORACLE_HOME/lib/libclntsh.so.* $ORACLE_HOME/lib/libclntsh.so.11.1; \
    fi
