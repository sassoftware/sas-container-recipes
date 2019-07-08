#! /bin/bash -e
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

sssd_pid_file="/var/run/sssd.pid"
if [[ -f $sssd_pid_file ]];then
    echo "[INFO] sssd already running."
    sssd_pid=$(cat $sssd_pid_file)
    rm -f $sssd_pid
    set +e;/usr/sbin/sssd -g --config /etc/sssd/sssd.conf;set -e
else
    sudo /usr/sbin/sssd --config /etc/sssd/sssd.conf
fi
