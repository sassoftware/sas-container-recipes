#!/bin/bash

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

# name: start.sh
# thanks jozwal for the ideas


#
# if given a command, run that
#
if [[ "$#" -gt 1 ]]
then
  echo Arguments to run are: "$@"
  exec "$@"
  exit
fi


#
# Start Viya
#	Remove unnecessary services and start remaining (in order)
#
rm -f /etc/init.d/sas-viya-alert-track-default
rm -f /etc/init.d/sas-viya-backup-agent-default
rm -f /etc/init.d/sas-viya-ops-agent-default
rm -f /etc/init.d/sas-viya-watch-log-default

/etc/init.d/sas-viya-all-services start



#
# Set servername to match container name
# Start httpd
#
echo "ServerName $(hostname -i):80" >> /etc/httpd/conf/httpd.conf
httpd

# Start RStudio Server
# /usr/lib/rstudio-server/bin/rserver --server-daemonize 0 &

#
# Start Jupyter
#
su -c '/opt/anaconda3/bin/jupyter-notebook --ip="*" --no-browser --notebook-dir=/home/sasdemo --NotebookApp.base_url=/Jupyter' sasdemo &
sleep 5


#
# Print out the help message without the HTML tags
#
sed 's/<[^>]*>//g' /var/www/html/index.html

while true
do
  tail -f /dev/null & wait ${!}
done

