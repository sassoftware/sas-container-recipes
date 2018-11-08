#! /bin/bash -e

[[ -z ${SAS_VIYA_DEPLOYMENT_DATA_ZIP+x} ]] && SAS_VIYA_DEPLOYMENT_DATA_ZIP=${PWD}/SAS_Viya_deployment_data.zip
[[ -z ${SAS_VIYA_PLAYBOOK_DIR+x} ]]        && SAS_VIYA_PLAYBOOK_DIR=${PWD}/sas_viya_playbook
[[ -z ${BASEIMAGE+x} ]]                    && BASEIMAGE=centos
[[ -z ${BASETAG+x} ]]                      && BASETAG=latest
[[ -z ${PLATFORM+x} ]]                     && PLATFORM=redhat
[[ -z ${SAS_RPM_REPO_URL+x} ]]             && SAS_RPM_REPO_URL=https://ses.sas.download/ses/

if [ -f ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} ]; then
    # Get orchestratioCLI and generate playbook
    if [ ! -f ${PWD}/sas-orchestration ]; then
        curl --silent --remote-name https://support.sas.com/installation/viya/34/sas-orchestration-cli/lax/sas-orchestration-linux.tgz
        tar xvf sas-orchestration-linux.tgz
        rm sas-orchestration-linux.tgz
    fi

    ./sas-orchestration build \
      --input ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} \
      --repository-warehouse ${SAS_RPM_REPO_URL} \
      --deployment-type programming \
      --platform $PLATFORM

    tar xvf ${PWD}/SAS_Viya_playbook.tgz
else
    if [ ! -d ${SAS_VIYA_PLAYBOOK_DIR} ]; then
        echo "[ERROR] : Could not find a playbook to use"; echo
        exit 5
    fi
fi

if [ -f "${PWD}/container.yml" ]; then
    mv ${PWD}/container.yml ${PWD}/container_$(date +"%Y%m%d%H%M").yml
fi

cp --verbose templates/container.yml container.yml

for file in $(ls -1 ${SAS_VIYA_PLAYBOOK_DIR}/group_vars); do
    echo; echo "*** Create the roles directory for the host groups"
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
            mkdir --parents --verbose roles/${file}/tasks
            mkdir --parents --verbose roles/${file}/templates
            mkdir --parents --verbose roles/${file}/vars
           
            if [ ! -f "roles/${file}/tasks/main.yml" ]; then
                echo; echo "***     Copy the tasks file for service '${file}'"; echo
                cp --verbose templates/task.yml roles/${file}/tasks/main.yml
            else
                echo; echo "***     Tasks file for service '${file}' already exists"; echo
            fi

            if [ ! -f "roles/${file}/templates/entrypoint" ]; then
                echo; echo "***     Copy the entrypoint file for service '${file}'"; echo
                cp --verbose templates/entrypoint roles/${file}/templates/entrypoint
            else
                echo; echo "***     entrypoint file for service '${file}' already exists"; echo
            fi

        else
            echo
            echo "*** There are no packages or yum groups in '${file}'"
            echo "*** Skipping adding service '${file}' to Docker list"
            echo
        fi
    else
        echo; echo "*** Skipping creating the roles directory for service '${file}'"; echo
    fi
done

echo

for role in $(ls -1 roles); do
    if [ -f ${SAS_VIYA_PLAYBOOK_DIR}/group_vars/${role} ]; then
        if [ -f roles/${role}/vars/${role} ]; then
            sudo rm -v roles/${role}/vars/${role}
        fi
        if [ -d roles/${role}/vars ]; then
            cp -v ${SAS_VIYA_PLAYBOOK_DIR}/group_vars/${role} roles/${role}/vars/
        fi
    fi
done

#
# When first starting with Ansible-Container, it would not take multiple
# var files. This section here dumps everything into one file and then
# adjusts the everything.yml file to make sure variables are in the correct order
#

echo
echo "BASEIMAGE: ${BASEIMAGE}" > everything.yml
echo "BASETAG: ${BASETAG}" >> everything.yml
echo "PLATFORM: ${PLATFORM}" >> everything.yml
echo "" >> everything.yml
echo "DEPLOYMENT_ID: viya" >> everything.yml
echo "SPRE_DEPLOYMENT_ID: spre" >> everything.yml
echo "PROGRAMMING_ONLY: true" >> everything.yml


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

sed -i "s|REPOSITORY_WAREHOUSE: \x22https://ses.sas.download/ses/\x22|REPOSITORY_WAREHOUSE: \x22${SAS_RPM_REPO_URL}\x22|" everything.yml

#
# Copy over the certificates that will be needed to do the install
#

if [ -f ${PWD}/entitlement_certificate.pem ]; then
    sudo rm ${PWD}/entitlement_certificate.pem
fi
cp -v ${SAS_VIYA_PLAYBOOK_DIR}/entitlement_certificate.pem .

if [ -f ${PWD}/SAS_CA_Certificate.pem ]; then
    sudo rm ${PWD}/SAS_CA_Certificate.pem
fi
cp -v ${SAS_VIYA_PLAYBOOK_DIR}/SAS_CA_Certificate.pem .

#
# Copy over some roles that are needed
#

if [ -d "${SAS_VIYA_PLAYBOOK_DIR}/roles/casserver-config" ]; then
    cp --verbose --archive --force ${SAS_VIYA_PLAYBOOK_DIR}/roles/casserver-config roles/
fi

#
# Update Container yaml
#

setinit_enc=$(cat ${SAS_VIYA_PLAYBOOK_DIR}/SASViyaV0300*.txt | base64 --wrap=0 )
sed -i "s|SETINIT_TEXT_ENC=|SETINIT_TEXT_ENC=${setinit_enc}|g" container.yml

exit 0
