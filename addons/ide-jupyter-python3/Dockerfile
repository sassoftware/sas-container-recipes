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
#   docker build --file Dockerfile_jpy3 --build-arg BASEIMAGE=viya-single-container --build-arg BASETAG=latest --build-arg PLATFORM=redhat . --tag svc-ide-jupyter-python3
#   docker build --file Dockerfile_jpy3 --build-arg BASEIMAGE=viya-single-container --build-arg BASETAG=latest --build-arg PLATFORM=suse . --tag svc-ide-jupyter-python3
#
# RUN:
#   docker run --detach --rm --publish-all --name svc-ide-jupyter-python3 --hostname svc-ide-jupyter-python3 svc-ide-jupyter-python3
#

ARG BASEIMAGE=viya-single-container
ARG BASETAG=latest

FROM $BASEIMAGE:$BASETAG

ARG PLATFORM=redhat
ARG SASPYTHONSWAT=1.4.0
ARG JUPYTER_TOKEN=''
ARG ENABLE_TERMINAL='True'
ARG ENABLE_NATIVE_KERNEL='True'

ENV JUPYTER_TOKEN=$JUPYTER_TOKEN
ENV ENABLE_TERMINAL=${ENABLE_TERMINAL}
ENV ENABLE_NATIVE_KERNEL=${ENABLE_NATIVE_KERNEL}

USER root

#
# Setup Jupyter Notebook
#

COPY post_deploy.sh /tmp/jpy3_post_deploy.sh
COPY *requirements.txt /tmp/

RUN set -e; \
    if [ "$PLATFORM" = "redhat" ]; then \
        PYTHON_REQUIREMENTS="redhat_requirements.txt"; \
        rpm --rebuilddb; \
        echo; echo "####### Add the packages to support running Jupyter Notebook"; echo; \
        if [ ! -f "/etc/yum.repos.d/epel.repo" ]; then \
            yum install --assumeyes https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm ; \
        fi; \
        yum install --assumeyes python36-devel gcc-c++; \
        curl --silent --remote-name https://bootstrap.pypa.io/get-pip.py; \
        python3.6 get-pip.py; \
        rm --verbose --force get-pip.py; \
        yum erase --assumeyes epel-release; \
    elif [ "$PLATFORM" = "suse" ]; then \
        PYTHON_REQUIREMENTS="suse_requirements.txt"; \
        rpm --rebuilddb; \
        export LD_LIBRARY_PATH='/usr/lib:/usr/local/lib'; \
        set +e; zypper install --no-confirm curl gcc gcc-c++ gcc-fortran make automake cpp48 gcc48 gcc48-c++ gcc48-fortran python3-base python3-devel; set -e; \
        rm --verbose --recursive --force /var/cache/zypp; \
        curl --silent --remote-name https://bootstrap.pypa.io/get-pip.py; \
        python3 get-pip.py; \
        rm --verbose --force get-pip.py; \
        pip3 install --upgrade pip; \
        zypper clean; \
    else \
        echo; echo "####### [ERROR] : Unknown platform of \"$PLATFORM\" passed in"; echo; \
        exit 1; \
    fi; \
    sed -i "s/@PLATFORM@/$PLATFORM/" /tmp/jpy3_post_deploy.sh; \
    pip3 --no-cache-dir install -r /tmp/${PYTHON_REQUIREMENTS}; \
    pip3 --no-cache-dir install https://github.com/sassoftware/python-swat/releases/download/v${SASPYTHONSWAT}/python-swat-${SASPYTHONSWAT}-linux64.tar.gz; \
    # Log current pip pkg versions \
    pip3 freeze; \
    jupyter nbextension install --py sas_kernel.showSASLog; \
    jupyter nbextension enable sas_kernel.showSASLog --py; \
    jupyter nbextension install --py sas_kernel.theme; \
    jupyter nbextension enable sas_kernel.theme --py; \
    # Disable the terminal kernel; \
    if [ "${ENABLE_TERMINAL}" = "False" ]; then \
        pip3 uninstall -y terminado; \
    fi; \
    # Disable the python kernel; \
    if [ "${ENABLE_NATIVE_KERNEL}" = "False" ]; then \
        jupyter kernelspec remove python3 -f; \
    fi
