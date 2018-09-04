#
# Copyright 2018 SAS Institute Inc.
#
# This work is licensed under a Creative Commons Attribution 4.0 International License.
# You may obtain a copy of the License at https://creativecommons.org/licenses/by/4.0/ 
#


FROM centos:7
MAINTAINER Paul Kent "paul.kent@sas.com"

#
# see https://hub.docker.com/_/centos/
# these entries from "Dockerfile for a systemd base image" Section
#
ENV container docker
RUN (cd /lib/systemd/system/sysinit.target.wants/; for i in *; do [ $i == systemd-tmpfiles-setup.service ] || rm -f $i; done); \
rm -f /lib/systemd/system/multi-user.target.wants/*;\
rm -f /etc/systemd/system/*.wants/*;\
rm -f /lib/systemd/system/local-fs.target.wants/*; \
rm -f /lib/systemd/system/sockets.target.wants/*udev*; \
rm -f /lib/systemd/system/sockets.target.wants/*initctl*; \
rm -f /lib/systemd/system/basic.target.wants/*;\
rm -f /lib/systemd/system/anaconda.target.wants/*;\
yum -y install yum-plugin-ovl 

VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]

# users for SAS
# TODO -- use real users, and LDAP/AD for auth/passwords
RUN groupadd -g 1001 sas; \
    useradd -u 1001 -g sas sas; \
    useradd -u 1002 -g sas cas; \
    useradd -u 1003 -g sas sasdemo; \
    sh -c 'echo "sasSAS" | passwd "sas" --stdin'; \
    sh -c 'echo "sasCAS" | passwd "cas" --stdin'; \
    sh -c 'echo "sasDEMO" | passwd "sasdemo" --stdin'


# install prerequisite packages
RUN rpmdb --rebuilddb; \
    yum -y install epel-release; \
    yum -y install \
       ansible \
       bzip2 \
       deltarpm \
       git \
       httpd \
       initscripts \
       iproute \
       java-1.8.0-openjdk \
       libpng12 \
       libXp \
       libXmu \
       lsof \
       mod_ssl \
       net-tools \
       numactl \
       openssh-clients \
       openssh-server \
       openssl \
       sudo \
       zip unzip \
       which \
       wget \
       ; \
    yum clean all


# prerequisites and get systemd going
RUN sed -i "/keepcache=/c\keepcache=1" /etc/yum.conf; \
    sh -c 'echo "*     -     nofile     50000" >> /etc/security/limits.conf'; \
    sed -i.bak -e 's/4096/65536/g' /etc/security/limits.d/20-nproc.conf; \
    ssh-keygen -q -t rsa -N '' -f ~/.ssh/id_rsa; \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys; \
    chmod 600 ~/.ssh/authorized_keys ; \
    echo "host localhost user sasdemo password sasDEMO" > ~/.authinfo ; \
    chmod 0600 ~/.authinfo; \
    cp ~/.authinfo /home/sasdemo/.authinfo; \
    chown sasdemo /home/sasdemo/.authinfo; \
    chmod 0600 /home/sasdemo/.authinfo; \
    systemctl enable systemd-user-sessions


# install anaconda/python
ENV anaREPO="https://repo.continuum.io/archive" \
    anaVERSION="3-5.2.0" \
    swatRELEASE="https://github.com/sassoftware/python-swat/releases" \
    swatVERSION="1.4.0"

RUN wget -q -O /tmp/anaconda.shar ${anaREPO}/Anaconda${anaVERSION}-Linux-x86_64.sh; \
   bash /tmp/anaconda.shar -p /opt/anaconda3 -b; \
   /opt/anaconda3/bin/pip install --upgrade pip; \
   /opt/anaconda3/bin/conda update conda; \
   /opt/anaconda3/bin/pip install jupyterlab; \
   /opt/anaconda3/bin/pip install sas_kernel; \
   /opt/anaconda3/bin/pip install msgpack; \
   /opt/anaconda3/bin/pip install sas-dlpy; \
   /opt/anaconda3/bin/pip install ${swatRELEASE}/download/v${swatVERSION}/python-swat-${swatVERSION}-linux64.tar.gz; \
   rm /tmp/anaconda.shar


#
# R too? - uncomment this next block
#

# R
# RUN /opt/anaconda3/bin/conda install r r-essentials

# ENV rstuVERSION=1.1.442 \
#     rswatRELEASE="https://github.com/sassoftware/R-swat/releases"
#     rswatVERSION=1.2.1

# RStudio
# RUN wget -q -O /tmp/rstudio.rpm https://download2.rstudio.org/rstudio-server-rhel-${rstuVERSION}-x86_64.rpm; \
#     yum -y install /tmp/rstudio.rpm; \
#     rm -rf /tmp/rstudio.rpm
#
# COPY files/rserver.conf /etc/rstudio/rserver.conf

# R-swat
# RUN yum -y install make; \
#    wget -q -O /tmp/r-swat-1.0.0-linux64.tar.gz https://github.com/sassoftware/R-swat/releases/download/v${rswatVERSION}/r-swat-${rswatVERSION}-linux64.tar.gz; \
#    /opt/anaconda3/bin/R CMD INSTALL /tmp/r-swat-${rswatVERSION}-linux64.tar.gz; \
#    rm -rf /tmp/r-swat-${rswatVERSION}-linux64.tar.gz





# ansible-based install of SAS
# we bury this inside the install_sas script to make it easier to run the same process on bare-metal
ENV sasORDER="09MXJC"
COPY download/$sasORDER/SAS_Viya_deployment_data.zip /opt/sas/install/SAS_Viya_deployment_data.zip
COPY files/install_sas /opt/sas/install
RUN /opt/sas/install/install_sas

#
# copy extra vendor files into the vendor folder,
# and with good luck, the install_vendor script will get them into the container
#
COPY vendor /opt/sas/vendor
COPY files/install_vendor /opt/sas/vendor/install_vendor
RUN /opt/sas/vendor/install_vendor

# samples
COPY files/notebooks  /home/sasdemo/notebooks
COPY files/samples    /home/sasdemo/samples
RUN chown -R sasdemo:sas /home/sasdemo

# shared folder
RUN mkdir /shared
RUN chmod 777 /shared
RUN ln -s /opt/sas/spre/home/SASFoundation/bin/sas_u8 /usr/local/bin/sas

WORKDIR /shared


# ask httpd to proxy our apps
COPY files/proxy.conf /etc/httpd/conf.d/proxy.conf

HEALTHCHECK CMD curl --fail http://localhost/SASStudio || exit 1

EXPOSE 80

COPY files/start.sh /start.sh

ENTRYPOINT ["/start.sh"]

