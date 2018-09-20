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

# Enable debugging if SAS_DEBUG is set
[[ -z ${SAS_DEBUG+x} ]] && export SAS_DEBUG=0
if [ ${SAS_DEBUG} -gt 0 ]; then
    set -x
fi

[[ -z ${CASENV_ADMIN_USER+x} ]] && CASENV_ADMIN_USER=sasdemo
[[ -z ${ADMIN_USER_PWD+x} ]]    && ADMIN_USER_PWD=sasdemo
[[ -z ${ADMIN_USER_HOME+x} ]]   && ADMIN_USER_HOME="/home/${CASENV_ADMIN_USER}"
[[ -z ${ADMIN_USER_UID+x} ]]    && ADMIN_USER_UID=1003
[[ -z ${ADMIN_USER_GROUP+x} ]]  && ADMIN_USER_GROUP=sas
[[ -z ${ADMIN_USER_GID+x} ]]    && ADMIN_USER_GID=1001

if [ $(/usr/bin/getent group ${ADMIN_USER_GROUP}) ]; then
    echo; echo "####### Group '${ADMIN_USER_GROUP}' already exists"; echo;
else
    echo; echo "####### Create the '${ADMIN_USER_GROUP}' group"; echo;
    groupadd --gid ${ADMIN_USER_GID} ${ADMIN_USER_GROUP};
fi;
if [ $(/usr/bin/getent passwd ${CASENV_ADMIN_USER} 2>&1 > /dev/null) ]; then
    echo; echo "####### [WARN] : User '${CASENV_ADMIN_USER}' already exists"; echo;
else
    echo; echo "####### Create the '${CASENV_ADMIN_USER}' user"; echo;
    /usr/sbin/useradd --uid ${ADMIN_USER_UID} --gid ${ADMIN_USER_GID} --home-dir ${ADMIN_USER_HOME} ${CASENV_ADMIN_USER};
    echo "${CASENV_ADMIN_USER}:${ADMIN_USER_PWD}" | chpasswd &&
    echo "default user ${CASENV_ADMIN_USER} password ${ADMIN_USER_PWD}" > ${ADMIN_USER_HOME}/authinfo.txt;
    chown --verbose ${ADMIN_USER_UID}:${ADMIN_USER_GID} ${ADMIN_USER_HOME}/authinfo.txt;
    chmod --verbose 0600 ${ADMIN_USER_HOME}/authinfo.txt;
    cp --verbose ${ADMIN_USER_HOME}/authinfo.txt ${ADMIN_USER_HOME}/.authinfo;
    chown --verbose ${ADMIN_USER_UID}:${ADMIN_USER_GID} ${ADMIN_USER_HOME}/.authinfo;
fi
