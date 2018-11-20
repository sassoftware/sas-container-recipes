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

[[ -z ${DEMO_USER+x} ]]        && DEMO_USER=sasdemo
[[ -z ${DEMO_USER_PASSWD+x} ]] && DEMO_USER_PASSWD=sasdemo
[[ -z ${DEMO_USER_UID+x} ]]    && DEMO_USER_UID=1004
[[ -z ${DEMO_USER_HOME+x} ]]   && DEMO_USER_HOME="/home/${DEMO_USER}"
[[ -z ${DEMO_USER_GROUP+x} ]]  && DEMO_USER_GROUP=sas
[[ -z ${DEMO_USER_GID+x} ]]    && DEMO_USER_GID=1001

[[ -z ${CASENV_ADMIN_USER+x} ]] && CASENV_ADMIN_USER=${DEMO_USER}
[[ -z ${ADMIN_USER_PASSWD+x} ]] && ADMIN_USER_PASSWD=sasdemo
[[ -z ${ADMIN_USER_UID+x} ]]    && ADMIN_USER_UID=1003
[[ -z ${ADMIN_USER_HOME+x} ]]   && ADMIN_USER_HOME="/home/${CASENV_ADMIN_USER}"
[[ -z ${ADMIN_USER_GROUP+x} ]]  && ADMIN_USER_GROUP=sas
[[ -z ${ADMIN_USER_GID+x} ]]    && ADMIN_USER_GID=1001

function create_user()
{
    local user_name=$1
    local user_passwd=$2
    local user_id=$3
    local user_home=$4
    local user_group=$5
    local user_gid=$6
    
    if [ $(/usr/bin/getent group ${user_group}) ]; then
        echo; echo "####### Group '${user_group}' already exists"; echo;
    else
        echo; echo "####### Create the '${user_group}' group"; echo;
        groupadd --gid ${user_gid} ${user_group};
    fi;
    if [[ $(/usr/bin/getent passwd ${user_name} 2>&1) ]]; then
        echo; echo "####### [WARN] : User '${user_name}' already exists"; echo;
    else
        echo; echo "####### Create the '${user_name}' user"; echo;
        /usr/sbin/useradd --uid ${user_id} --gid ${user_gid} --home-dir ${user_home} --create-home ${user_name};
        echo "${user_name}:${user_passwd}" | chpasswd &&
        echo "default user ${user_name} password ${user_passwd}" > ${user_home}/authinfo.txt;
        chown --verbose ${user_id}:${user_gid} ${user_home}/authinfo.txt;
        chmod --verbose 0600 ${user_home}/authinfo.txt;
        cp --verbose ${user_home}/authinfo.txt ${user_home}/.authinfo;
        chown --verbose ${user_id}:${user_gid} ${user_home}/.authinfo;
    fi
}

create_user ${DEMO_USER} ${DEMO_USER_PASSWD} ${DEMO_USER_UID} ${DEMO_USER_HOME} ${DEMO_USER_GROUP} ${DEMO_USER_GID}
create_user ${CASENV_ADMIN_USER} ${ADMIN_USER_PASSWD} ${ADMIN_USER_UID} ${ADMIN_USER_HOME} ${ADMIN_USER_GROUP} ${ADMIN_USER_GID}

