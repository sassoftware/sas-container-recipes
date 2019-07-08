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
#   docker build --file Dockerfile . --tag viya-single-container
#
# RUN:
#   docker run --detach --rm --publish-all --name viya-single-container --hostname viya-single-container viya-single-container
#

FROM centos:7

ARG PLATFORM=redhat
ENV PLATFORM=$PLATFORM
ARG ANSIBLE_VERSION=2.7
ARG TINI_RPM_NAME=tini_0.18.0.rpm
ARG TINI_URL=https://github.com/krallin/tini/releases/download/v0.18.0
ARG SAS_RPM_REPO_URL=https://ses.sas.download/ses/

USER root
WORKDIR /tmp/sas
COPY SAS_Viya_deployment_data.zip ./

EXPOSE 80 \
       443 \
       5570

ENTRYPOINT ["/usr/bin/tini", "--", "/opt/sas/viya/home/bin/entrypoint"]

#
# Install some of the expected packages in their own layer
#

RUN set -e; \
    echo; echo "####### Go ahead and add the packages that the Ansible playbook will look for"; echo; \
	rpm --rebuilddb; \
	yum install --assumeyes java-1.8.0-openjdk libselinux-python which; \
	yum clean all; \
	rm --verbose --recursive --force /root/.cache /var/cache/yum; \
	rm --verbose /etc/security/limits.d/20-nproc.conf;

#
# Install tini to manage the processes
#

RUN set -e; \
	rpm --rebuilddb; \
	curl --silent --output ${TINI_RPM_NAME} --location ${TINI_URL}/${TINI_RPM_NAME}; \
	yum install --assumeyes ${TINI_RPM_NAME}; \
	rm --verbose ${TINI_RPM_NAME}; \
	yum clean all; \
	rm --verbose --recursive --force /root/.cache /var/cache/yum;

#
# Install Ansible and other required packages in their own layer
#

# To get the playbook to run it requires
# + iproute
# + openssh-clients
# + sudo
# + initscripts

RUN set -e; \
    echo; echo "####### Run the Ansible playbook to create the main layer"; echo; \
	rpm --rebuilddb; \
	echo; echo "####### Add the packages to support running the Ansible playbook"; echo; \
	yum install --assumeyes  https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm ; \
	yum install --assumeyes python-setuptools python-devel openssl-devel; \
	yum install --assumeyes python-pip gcc wget tree automake python-six; \
	pip install --upgrade pip setuptools; \
	pip install ansible==${ANSIBLE_VERSION}; \
	yum install --assumeyes python iproute openssh-clients initscripts sudo;

#
# Get the SAS orchestrationCLI to generate the playbook then modify it so it will run
#

RUN set -e; \
    if [ ! -d sas_viya_playbook ]; then \
            echo; echo "####### Get the orchestrationCLI and generate the playbook"; echo; \
            curl --silent --remote-name https://support.sas.com/installation/viya/34/sas-orchestration-cli/lax/sas-orchestration-linux.tgz ; \
            tar xvf sas-orchestration-linux.tgz; \
            ./sas-orchestration build --input SAS_Viya_deployment_data.zip --deployment-type programming --repository-warehouse $SAS_RPM_REPO_URL --platform redhat; \
            tar xvf SAS_Viya_playbook.tgz; \
    else \
        echo; echo "####### Using playbook provided by user"; \
    fi; \
    if [ -f vars.yml ]; then \
        echo; echo "####### Copying over user provided vars.yml file"; \
        cp --verbose vars.yml sas_viya_playbook/; \
    fi; \
    echo; echo "####### Viya installer checks for /root/.ssh/known_hosts"; echo; \
    mkdir --verbose ~/.ssh ; \
    touch ~/.ssh/known_hosts ; \
    chmod --verbose 644 ~/.ssh/known_hosts ; \
    echo; echo "####### Remove ansible directory /tmp/..ansible"; echo; \
    rm -rf /tmp/..ansible ; \
    echo; echo "####### Create the sas group and the cas user"; echo; \
    groupadd -g 1001 sas; \
    useradd -c "SAS User" -g 1001 -u 1001 sas; \  
    useradd -c "CAS User" -g 1001 -m -u 1002 cas; \
    pushd sas_viya_playbook ; \
    echo; echo "####### Modify the input to ignore verification failures"; echo; \
    sed -i 's|VERIFY_DEPLOYMENT: true|VERIFY_DEPLOYMENT: false|' vars.yml ; \
    echo; echo "####### Get the right inventory file"; echo; \
    cp --verbose samples/inventory_local.ini . ; \
    echo; echo "####### Disable starting httpd"; echo; \
	sed -i "/ notify/,+9d" roles/httpd-x64_redhat_linux_6-yum/tasks/configure-and-start.yml; \
    popd

#
# Run the playbook and adjust the result
#

# Make sure to get the vars_usermods file over.
COPY vars_usermods.yml ./sas_viya_playbook/vars_usermods.yml

RUN set -e; \
    pushd sas_viya_playbook ; \
    echo; echo "####### Run the playbook"; echo; \
    ansible-playbook -i inventory_local.ini site.yml -e '@vars_usermods.yml' -vvv ; \
    echo; echo "####### Stop the running services"; echo; \
    /etc/init.d/sas-viya-all-services stop; \
    popd; \
    echo; echo "####### Reset host variables to localhost"; echo; \
    sed -i 's|^options cashost=".*" casport|options cashost="localhost" casport|' /opt/sas/viya/config/etc/batchserver/default/autoexec_deployment.sas; \
    sed -i 's|^env.CAS_VIRTUAL_HOST = '.*'|env.CAS_VIRTUAL_HOST = 'localhost'|' /opt/sas/viya/config/etc/cas/default/casconfig_deployment.lua; \
    sed -i 's|^SASCONTROLLERHOST=.*|SASCONTROLLERHOST=localhost|' /opt/sas/viya/config/etc/sysconfig/cas/default/sas-cas-deployment; \
    sed -i 's|^SAS_CURRENT_HOST=.*|SAS_CURRENT_HOST=localhost|' /opt/sas/viya/config/etc/sysconfig/cas/default/sas-cas-deployment; \
    sed -i 's|^options cashost=".*" casport|options cashost="localhost" casport|' /opt/sas/viya/config/etc/workspaceserver/default/autoexec_deployment.sas; \
	sed -i 's|http://.*:|http://localhost:|' /etc/httpd/conf.d/proxy.conf; \
	echo "ServerName localhost" >> /etc/httpd/conf/httpd.conf; \
    echo; echo "####### Remove permstore"; echo; \
    rm --verbose --recursive --force /opt/sas/viya/config/etc/cas/default/permstore/*; \
    echo; echo "####### Remove created logs"; echo; \
    rm --verbose --recursive --force /opt/sas/viya/config/var/log/all-services/default/*; \
    rm --verbose --recursive --force /opt/sas/viya/config/var/log/cas/default/*; \
    rm --verbose --recursive --force /opt/sas/viya/config/var/log/sasstudio/default/*; \
    rm --verbose --recursive --force /opt/sas/viya/config/var/log/spawner/default/*; \
    echo; \
	echo; echo "####### Remove Text Analytic languages; we will add them back in their own layer"; echo; \
	for txtmin in $(rpm -qa | grep sas-txtmin); do \
		if [[ "${txtmin}" != "sas-txtmineng"* ]] && [[ "${txtmin}" != *"yum"* ]]; then \
			echo "####### Uninstalling ${txtmin}"; \
			rpm --verbose -e ${txtmin}; \
		fi; \
	done; \
	#yum groupremove --assumeyes "sas-ygtxtmin*"; \
	echo; echo "####### Remove some of the bigger packages that have bloated the layer"; echo; \
	for bigpackage in "sas-mapsgfka1" "sas-mapsgfkb1" "sas-nvidiacuda1" "sas-nvidiacuda" "sas-mapsvahdat" "sas-reportvahdat"; do \
		if rpm -q --quiet ${bigpackage}; then \
			yum erase --assumeyes ${bigpackage}; \
		fi; \
	done; \
	echo; echo "####### Remove the repos"; echo; \
	yum erase --assumeyes "sas-meta-repo*"; \
	if [ -e "/etc/yum.repos.d/sas.repo" ]; then \
		rm --verbose /etc/yum.repos.d/sas.repo; \
	fi; \
	echo; echo "####### Clean up yum"; echo; \
	yum clean all; \
	rm --verbose --recursive --force /root/.cache /var/cache/yum; \
	rm --verbose --recursive --force /var/cache/zypp; \
    echo; echo "####### Remove the entitlement certificate"; echo; \
    rm --verbose --recursive --force /etc/pki/sas; \
    echo; echo "####### Remove the content in the WORKDIR"; echo; \
    rm --verbose --recursive --force sas-orchestration sas-orchestration-linux.tgz;

#
# Add text analytic languages back in
#

RUN set -e; \
    echo; echo "####### Create the Text Analytics languages layer"; echo; \
    pushd sas_viya_playbook ; \
    echo; echo "####### Run the playbook"; echo; \
    ansible-playbook -i inventory_local.ini install-only.yml -vvv ; \
    echo; echo "####### Stop the running services"; echo; \
    /etc/init.d/sas-viya-all-services stop; \
    popd; \
	echo; echo "####### Make sure the Text Analytics Languages are installed"; echo; \
	if [ -e "/etc/yum.repos.d/sas.repo" ]; then \
		yum install --assumeyes "sas-txtmin*"; \
	else \
		yum install --assumeyes --disablerepo sas-meta-repo "sas-txtmin*"; \
	fi; \
	echo; echo "####### Remove the repos"; echo; \
	yum erase --assumeyes "sas-meta-repo*"; \
	if [ -e "/etc/yum.repos.d/sas.repo" ]; then \
		rm --verbose /etc/yum.repos.d/sas.repo; \
	fi; \
	echo; echo "####### Clean up yum"; echo; \
	yum clean all; \
	rm --verbose --recursive --force /root/.cache /var/cache/yum; \
    echo; echo "####### Remove the entitlement certificate"; echo; \
    rm --verbose --recursive --force /etc/pki/sas; \
    echo; echo "####### Remove the content in the WORKDIR"; echo; \
    rm --verbose --recursive --force sas-orchestration sas-orchestration-linux.tgz;

#
# Add those packages that are hefty in size back into their own layer
#

RUN set -e; \
    echo; echo "####### Create the layer for some of the bigger packages"; echo; \
    pushd sas_viya_playbook; \
    echo; echo "####### Run the playbook"; echo; \
    ansible-playbook -i inventory_local.ini install-only.yml -vvv; \
    echo; echo "####### Stop the running services"; echo; \
    /etc/init.d/sas-viya-all-services stop; \
    popd; \
	echo; echo "####### Make sure the bigger packages are back in"; echo; \
	for bigpackage in "sas-mapsgfka1" "sas-mapsgfkb1" "sas-nvidiacuda1" "sas-nvidiacuda" "sas-mapsvahdat" "sas-reportvahdat"; do \
		if yum info --quiet ${bigpackage} 2>/dev/null; then \
			yum install --assumeyes ${bigpackage}; \
		fi; \
	done; \
	echo; echo "####### Remove the repos"; echo; \
	yum erase --assumeyes "sas-meta-repo*"; \
	if [ -e "/etc/yum.repos.d/sas.repo" ]; then \
		rm --verbose /etc/yum.repos.d/sas.repo; \
	fi; \
	echo; echo "####### Clean up yum"; echo; \
	yum clean all; \
	rm --verbose --recursive --force /root/.cache /var/cache/yum; \
    echo; echo "####### Remove the entitlement certificate"; echo; \
    rm --verbose --recursive --force /etc/pki/sas; \
    echo; echo "####### Remove the content in the WORKDIR"; echo; \
    rm --verbose --recursive --force SAS_Viya_deployment_data.zip SAS_Viya_playbook.tgz sas_viya_playbook;

COPY replace_httpd_default_cert.sh /opt/sas/viya/home/bin/replace_httpd_default_cert.sh
RUN chmod +x /opt/sas/viya/home/bin/replace_httpd_default_cert.sh

COPY entrypoint /opt/sas/viya/home/bin/entrypoint
RUN chmod +x /opt/sas/viya/home/bin/entrypoint

RUN usermod -aG apache sas

RUN echo "sas        ALL=(ALL)       NOPASSWD: ALL" >>/etc/sudoers
