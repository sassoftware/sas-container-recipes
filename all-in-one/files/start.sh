#!/bin/bash

#
# Copyright 2018 SAS Institute Inc.
#
# This work is licensed under a Creative Commons Attribution 4.0 International License.
# You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/ 
#

# name: start.sh
# thanks jozwal for the ideas

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
# Write out a help page to be displayed when browsing port 80
#
cat > /var/www/html/index.html <<'EOF'
<html>
 <h1> SAS Viya 3.3 Docker Container </h1>
 <p> Access the software by browsing to:
 <ul>
  <li> <b><a href="/SASStudio">/SASStudio</a></b>
  <li> <b><a href="/RStudio/auth-sign-in">/RStudio</a></b> (Not installed by default)
  <li> <b><a href="/Jupyter">/Jupyter</a></b>
 </ul> using HTTP on port 80.

 <p> If port 80 is forwarded to a different port on the host machine, use the host port instead.

 <p> Use the <b>sasdemo</b> / <b>sasDEMO</b> login to access SAS Studio, CAS, and Jupyter.
</html>
EOF

#
# Print out the help message without the HTML tags
#
sed 's/<[^>]*>//g' /var/www/html/index.html

while true
do
  tail -f /dev/null & wait ${!}
done

