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
#   docker build --file Dockerfile --build-arg BASEIMAGE=viya-single-container --build-arg BASETAG=latest --build-arg PLATFORM=redhat . --tag svc-auth-sssd
#   docker build --file Dockerfile --build-arg BASEIMAGE=viya-single-container --build-arg BASETAG=latest --build-arg PLATFORM=suse . --tag svc-auth-sssd
#
# RUN:
#   docker run --detach --rm --publish-all --name svc-auth-sssd --hostname svc-auth-sssd svc-auth-sssd
#

ARG BASEIMAGE=viya-single-container
ARG BASETAG=latest

FROM $BASEIMAGE:$BASETAG

ARG PLATFORM=redhat
ARG SSSD_CONF=sssd.conf

USER root

WORKDIR /tmp/host_auth

COPY ${SSSD_CONF} sssd* ./
COPY sssd_mkhomedir_helper.sh /usr/local/bin/mkhomedir_helper.sh

#
# Setup LDAP
#

RUN set -e; \
    if [ "$PLATFORM" = "redhat" ]; then \rpm --rebuilddb && \
        echo; echo "####### Add sssd and supporting cast"; echo; \
        yum install --assumeyes  authconfig sssd openldap-clients; \
        cp --verbose ${SSSD_CONF} /etc/sssd/sssd.conf; \
        chmod --verbose 600 /etc/sssd/sssd.conf; \
        if [ -f sssd.cert ]; then cp --verbose sssd.cert /etc/ssl/certs/sssd; fi; \
        /usr/sbin/authconfig --enablesssd \
            --enablesssdauth \
            --enablelocauthorize \
            --enablesysnetauth \
            --update; \
        sed -i '/^account.*required.*pam_unix.so$/a account     required      pam_exec.so \/usr\/local\/bin\/mkhomedir_helper.sh' /etc/pam.d/password-auth; \
        sed -i '/^session.*optional.*pam_sss.so$/a session     optional      pam_mkhomedir.so' /etc/pam.d/system-auth; \
        yum clean all; \
        rm --verbose --recursive --force /root/.cache /var/cache/yum; \
    elif [ "$PLATFORM" = "suse" ]; then \
        rpm --rebuilddb; \
        zypper install --no-confirm sssd openldap2-client; \
        cp --verbose ${SSSD_CONF} /etc/sssd/sssd.conf; \
        chmod --verbose 600 /etc/sssd/sssd.conf; \
        if [ -f sssd.cert ]; then cp --verbose sssd.cert /etc/ssl/certs/sssd; fi; \
        pam-config --add --sss && pam-config --add --mkhomedir --mkhomedir-umask=0077; \
        sed -i 's|compat$|compat sss|g' /etc/nsswitch.conf; \
        sed -i '/^account.*required.*pam_sss.so.*use_first_pass.*$/a account required         pam_exec.so    \/usr\/local\/bin\/mkhomedir_helper.sh' /etc/pam.d/common-account; \
        zypper clean ; \
        rm --verbose --recursive --force /var/cache/zypp; \
    else \
        echo; echo "####### [ERROR] : Unknown platform of \"$PLATFORM\" passed in"; echo; \
        exit 1; \
    fi && rm --verbose --recursive --force sssd*


COPY sssd_pre_deploy.sh /tmp/000_sssd_pre_deploy.sh
