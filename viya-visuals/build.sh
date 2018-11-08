#!/bin/bash -e
#
# build.sh
# Creates Docker images and a docker-compose file from a Sofware Order Email (SOE) zip file.
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

# Define where the zip file is received in your software order email (SOE)
if [ -z ${ORDER_LOCATION} ]; then
    echo -e "Usage: ORDER_LOCATION=/path/to/SAS_Viya_deployment_data.zip ./build.sh"
    exit 2
fi

[[ -z ${PROJECT_NAME+x} ]]     && PROJECT_NAME=sas-viya
[[ -z ${BASEIMAGE+x} ]]        && BASEIMAGE=centos
[[ -z ${BASETAG+x} ]]          && BASETAG=latest
[[ -z ${PLATFORM+x} ]]         && PLATFORM=redhat
[[ -z ${SAS_RPM_REPO_URL+x} ]] && SAS_RPM_REPO_URL=https://ses.sas.download/ses/

# Download the orchestration tool if it's not in /usr/bin
if [ ! -f /usr/bin/sas-orchestration ]; then
    echo -e "[INFO]  : Installing SAS orchestration CLI";
    curl --silent --remote-name https://support.sas.com/installation/viya/34/sas-orchestration-cli/lax/sas-orchestration-linux.tgz
    if [ 0 -eq $? ]; then
        echo -e "Failed to download the sas-orchestration-cli."
        exit 3
    fi;
    tar xvf sas-orchestration-linux.tgz
    rm sas-orchestration-linux.tgz
    sudo mv sas-orchestration /usr/bin
fi

# All steps happen inside of the debug directory
# Grab a fresh container.yml template and override it in the debug directory
if [[ -d debug/ ]]; then
    rm -rf debug/
fi
mkdir -p debug/roles/
mkdir debug/deploy/
cp templates/container.yml debug/
cp templates/generate-manifests.yml debug/
cd debug/

# Use the orchestration tool to convert the SOE zip into a playbook
echo -e "[INFO]  : Generating playbook"
sas-orchestration build --input ${ORDER_LOCATION}
tar xvf SAS_Viya_playbook.tgz
rm SAS_Viya_playbook.tgz

export SAS_VIYA_PLAYBOOK_DIR=${PWD}/sas_viya_playbook
static_files=$(ls ../templates/static-services/)
for file in $(ls -1 ${SAS_VIYA_PLAYBOOK_DIR}/group_vars); do
    echo -e "*** Create the roles directory for the host groups"
    if [ "${file}" != "all" ] && \
       [ "${file}" != "CommandLine" ] && \
       [ "${file}" != "sas-all" ] && \
       [ "${file}" != "sas-casserver-secondary" ] && \
       [ "${file}" != "sas-casserver-worker" ]; then

        # Lets check to see if the file actually has packages for us to install
        # An ESP order is an example of this
        set +e
        grep --quiet "SERVICE_YUM_PACKAGE" ${SAS_VIYA_PLAYBOOK_DIR}/group_vars/${file}
        pkg_grep_rc=$?
        grep --quiet "SERVICE_YUM_GROUP" ${SAS_VIYA_PLAYBOOK_DIR}/group_vars/${file}
        grp_grep_rc=$?
        set -e
        
        if (( ${pkg_grep_rc} == 0 )) || (( ${grp_grep_rc} == 0 )); then
        
            echo "***   Create the roles directory for service '${file}'"; echo
            mkdir --parents roles/${file}/tasks
            mkdir --parents roles/${file}/templates
            mkdir --parents roles/${file}/vars
           
            if [ ! -f "roles/${file}/tasks/main.yml" ]; then
                echo; echo "***     Copy the tasks file for service '${file}'"; echo
                cp ../templates/task.yml roles/${file}/tasks/main.yml
            else
                echo; echo "***     Tasks file for service '${file}' already exists"; echo
            fi

            if [ ! -f "roles/${file}/templates/entrypoint" ]; then
                echo; echo "***     Copy the entrypoint file for service '${file}'"; echo
                cp ../templates/entrypoint roles/${file}/templates/entrypoint
            else
                echo; echo "***     entrypoint file for service '${file}' already exists"; echo
            fi

            # Each file in the static-service directory has the same file name as its service name
            # If the file name is the same as the service then the service exists in the order
            file_is_static='false'
            for service in ${static_files}; do
                if [ "${file,,}" = ${service} ]; then
                    # Append static service definition to the debug/container.yml
                    cat ../templates/static-services/${item} >> container.yml 
                    echo -e "" >> container.yml
                    $file_is_static = 'true'
                    echo -e "FOUND STATIC FILE: -------------------------------------- ${service}"
                fi
            done
            
            # If the current file is not in the static_services list then add it to container.yml from the following standard format
            if [ ${file_is_static} = 'false' ]; then
                cat >> container.yml <<EOL

  ${file,,}:
    from: "centos:7"
    roles:
    - sas-java
    - ${file}
    ports: {}
    entrypoint: ["/opt/sas/viya/home/bin/${file,,}-entrypoint.sh"]
    dev_overrides:
      environment:
        - "SAS_DEBUG=1"
    deployment_overrides:
      volumes:
        - "log=/opt/sas/viya/config/var/log"
      resources:
        limits:
        - "memory=10Gi"
        requests:
        - "memory=2Gi"

EOL
            fi
        fi
    fi
done

# Configure ansible-container to pull from an internal registry
cat >> container.yml <<EOL

registries: 
  internal-sas:
    url: https://docker.sas.com
    namespace: atc

volumes:
  static-content:
    docker: {}
EOL

# Copy over static roles, override others already added in the generated roles
cp -rf ../templates/static-roles/* roles/

# For all roles in the playbook's list that are also in in the group_vars directory...
for role in $(ls -1 roles); do
    if [ -f ${SAS_VIYA_PLAYBOOK_DIR}/group_vars/${role} ]; then
        
        # Remove previous roles files if they exist
        if [ -f roles/${role}/vars/${role} ]; then
            sudo rm -v roles/${role}/vars/${role}
        fi
        
        # Copy the role's vars directory if it exists
        if [ -d roles/${role}/vars ]; then
            cp -v ${SAS_VIYA_PLAYBOOK_DIR}/group_vars/${role} roles/${role}/vars/
        fi
    fi
done

# When first starting with Ansible-Container, it would not take multiple
# var files. This section here dumps everything into one file and then
# adjusts the 'everything' yml file to make sure variables are in the correct order
echo
echo "PROJECT_NAME: ${PROJECT_NAME}" > everything.yml
echo "BASEIMAGE: ${BASEIMAGE}" >> everything.yml
echo "BASETAG: ${BASETAG}" >> everything.yml
echo "PLATFORM: ${PLATFORM}" >> everything.yml
echo "DOCKER_REGISTRY_URL: ${DOCKER_REGISTRY_URL}" >> everything.yml
echo "DOCKER_REGISTRY_NAMESPACE: ${DOCKER_REGISTRY_NAMESPACE}" >> everything.yml
echo "" >> everything.yml
echo "DEPLOYMENT_ID: viya" >> everything.yml
echo "SPRE_DEPLOYMENT_ID: spre" >> everything.yml

if [[ ! -z ${INCLUDE_DEMOUSER+x} ]]; then
    echo "INCLUDE_DEMOUSER: yes"
    exit 0
fi

cp ${SAS_VIYA_PLAYBOOK_DIR}/group_vars/all temp_all
sed -i 's|^DEPLOYMENT_ID:.*||' temp_all
sed -i 's|^SPRE_DEPLOYMENT_ID:.*||' temp_all
cat temp_all >> everything.yml
sudo rm -v temp_all

cat ${SAS_VIYA_PLAYBOOK_DIR}/vars.yml >> everything.yml
cat ${SAS_VIYA_PLAYBOOK_DIR}/internal/soe_defaults.yml >> everything.yml
sed -i 's|---||g' everything.yml
sed -i 's|^SERVICE_NAME_DEFAULT|#SERVICE_NAME_DEFAULT|' everything.yml
sed -i 's|^CONSUL_EXTERNAL_ADDRESS|#CONSUL_EXTERNAL_ADDRESS|' everything.yml
sed -i 's|^YUM_INSTALL_BATCH_SIZE|#YUM_INSTALL_BATCH_SIZE|' everything.yml
sed -i 's|^sasenv_license|#sasenv_license|' everything.yml
sed -i 's|^sasenv_composite_license|#sasenv_composite_license|' everything.yml
sed -i 's|^METAREPO_CERT_SOURCE|#METAREPO_CERT_SOURCE|' everything.yml
sed -i 's|^ENTITLEMENT_PATH|#ENTITLEMENT_PATH|' everything.yml
sed -i 's|^SAS_CERT_PATH|#SAS_CERT_PATH|' everything.yml
sed -i 's|^SECURE_CONSUL:.*|SECURE_CONSUL: false|' everything.yml

# Copy over the certificates that will be needed to do the install
cp ${SAS_VIYA_PLAYBOOK_DIR}/*.pem .

# Fix for casserver-config role not being copied in a programming deployment
if [ -d "${SAS_VIYA_PLAYBOOK_DIR}/roles/casserver-config" ]; then
    cp --archive --force ${SAS_VIYA_PLAYBOOK_DIR}/roles/casserver-config roles/
fi

# Add the encoded key value data to the container.yml
if [ -f roles/manifests/files/consul.data ]; then
    consul_data_enc=$(cat roles/manifests/files/consul.data | base64 --wrap=0 )
    sed -i "s|CONSUL_KEY_VALUE_DATA_ENC=|CONSUL_KEY_VALUE_DATA_ENC=${consul_data_enc}|g" container.yml
fi

# Write any license secrets to the container.yml instead of baking it 
# into the image so it's only seen at run-time.
license=$(cat ${SAS_VIYA_PLAYBOOK_DIR}/SASViyaV0300*.txt | base64 --wrap=0 )
sed -i "s|SETINIT_TEXT_ENC=|SETINIT_TEXT_ENC=${license}|g" container.yml


echo
echo "===================================="
echo "[INFO]  : Building SAS Docker images"
echo "===================================="
echo

set +e
if [[ ! -z ${REBUILDS} ]]; then
    echo -e "Rebuilding services ${REBUILDS}"
    ansible-container build --services $REBUILDS
else
    ansible-container build 
fi
build_rc=$?
set -e

if (( ${build_rc} != 0 )); then
    echo "[ERROR] : Unable to build Docker images"; echo
    exit 20
fi

echo
echo "=========================================="
echo "[INFO]: Generating Kubernetes Configs"
echo "=========================================="
echo

set +e
# Ansible requires access to the host's libselinux-python lib. Setting ansible_python_interpreter.
ansible-playbook -vvv generate-manifests.yml
rm -r ../deploy/
mv deploy/ ../
apgen_rc=$?
set -e

if (( ${apgen_rc} != 0 )); then
    echo "[ERROR] : Unable to generate the deployment"; echo
    exit 30
fi
echo -e "SUCCESS."
echo -e "The deployment files are now in the 'deploy' directory."

exit 0

