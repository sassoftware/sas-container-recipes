#! /bin/bash -e

#
# Functions
#

# Push built images to the specified docker registry
function push_images() {
    # Sort the services so they are in alphabetical order
    #https://stackoverflow.com/questions/7442417/how-to-sort-an-array-in-bash
    readarray -t sorted_services < <(printf '%s\0' "${all_services[@]}" | sort -z | xargs -0n1)
    for service in "${sorted_services[@]}"; do
        early_exit=false
        done=false
        while [[ "$done" != "true" && "${early_exit}" == "false" ]]; do
            if [[ "$(docker images -q ${PROJECT_NAME}-${service}:latest 2> /dev/null)" != "" ]]; then
                echo "[INFO]  : Pushing ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}"
                docker tag ${PROJECT_NAME}-${service}:latest ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}
                docker push ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}
                echo "[INFO]  : Completed push of ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}"
                done=true
            else
                echo "[INFO]  : Cannot find '${PROJECT_NAME}-${service}:latest'...pausing 30 seconds"
                sleep 30
                # Check a-c process to make sure it did not exit out
                if [[ "$(ps --no-headers ${SAS_ANSIBLE_CONTAINER_PID} | awk '{print $1}')" == "" ]]; then
                    # if a-c is no longer running, break
                    echo "[WARN]  : ansible-controller has stopped but not all images are built."
                    early_exit=true
                fi
            fi
        done
        # Check a-c process to make sure it did not exit out
        # if a-c is no longer running, break
        if [[ "${early_exit}" == "true" ]]; then
            break
        fi
    done

    # Run through it one more time and collect any services that do not have images
    # If we have any services with no images and a-c has exited, then we will assume
    # that a-c exited early and thus we are in a error state and need to return early.
    missing_images=()
    for service in "${sorted_services[@]}"; do
        if [[ "$(docker images -q ${PROJECT_NAME}-${service}:latest 2> /dev/null)" == "" ]]; then
            missing_images+=( ${service} )
        else
            echo "[INFO]  : Second attempt to push ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}"
            docker tag ${PROJECT_NAME}-${service}:latest ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}
            docker push ${DOCKER_REGISTRY_URL}/${DOCKER_REGISTRY_NAMESPACE}/${PROJECT_NAME}-${service}:${SAS_DOCKER_TAG}
        fi
    done

    # If we have any images that were not built, then we need to exit
    if (( ${#missing_images[@]} > 0 )); then
        echo "[ERROR] : Looks like ansible-container exited early and not all expected images are built...exiting"
        exit 22
    fi
}

#
# Set some defaults
#
sas_datetime=$(date "+%Y%m%d%H%M%S")
sas_sha1=$(git rev-parse --short HEAD 2>/dev/null || echo "no-git-sha")

unameSystem="$(uname -s)"
case "${unameSystem}" in
    Linux*)     OPERATING_SYSTEM=linux;;
    Darwin*)    OPERATING_SYSTEM=darwin;;
    *)          echo "Unsupported system: ${unameSystem}"
esac

[[ -z ${PROJECT_NAME+x} ]]                 && PROJECT_NAME=sas-viya
[[ -z ${BASEIMAGE+x} ]]                    && BASEIMAGE=centos
[[ -z ${BASETAG+x} ]]                      && BASETAG=latest
[[ -z ${SAS_VIYA_DEPLOYMENT_DATA_ZIP+x} ]] && SAS_VIYA_DEPLOYMENT_DATA_ZIP=${PWD}/SAS_Viya_deployment_data.zip
[[ -z ${PLATFORM+x} ]]                     && PLATFORM=redhat
[[ -z ${OPERATING_SYSTEM+x} ]]             && OPERATING_SYSTEM=linux
[[ -z ${SAS_RPM_REPO_URL+x} ]]             && SAS_RPM_REPO_URL=https://ses.sas.download/ses/
[[ -z ${DOCKER_REGISTRY_URL+x} ]]          && DOCKER_REGISTRY_URL=http://docker.company.com
[[ -z ${DOCKER_REGISTRY_NAMESPACE+x} ]]    && DOCKER_REGISTRY_NAMESPACE=sas
[[ -z ${DOCKER_REGISTRY_TYPE+x} ]]         && DOCKER_REGISTRY_TYPE=default
[[ -z ${SAS_RECIPE_VERSION+x} ]]           && SAS_RECIPE_VERSION=$(cat ${PWD}/../../docs/VERSION)

#
# Set options
#

# Use command line options if they have been provided. This overrides environment settings,
while [[ $# -gt 0 ]]; do
    key="$1"
    case ${key} in
        -i|--baseimage)
            shift # past argument
            BASEIMAGE="$1"
            shift # past value
            ;;
        -t|--basetag)
            shift # past argument
            BASETAG="$1"
            shift # past value
            ;;
        -r|--docker-registry-type)
            shift # past argument
            DOCKER_REGISTRY_TYPE="$1"
            shift # past value
            ;;
        -m|--mirror-url)
            shift # past argument
            SAS_RPM_REPO_URL="$1"
            shift # past value
            ;;
        -p|--platform)
            shift # past argument
            PLATFORM=$1
            shift # past value
            ;;
        -z|--zip)
            shift # past argument
            SAS_VIYA_DEPLOYMENT_DATA_ZIP="$1"
            shift # past value
            ;;
        -s|--sas-docker-tag)
            shift # past argument
            SAS_DOCKER_TAG="$1"
            shift # past value
            ;;
        -u|--docker-url)
            shift # past argument
            DOCKER_REGISTRY_URL="$1"
            shift # past value
            ;;
        -n|--docker-namespace)
            shift # past argument
            DOCKER_REGISTRY_NAMESPACE="$1"
            shift # past value
            ;;
        -v|--virtual-host)
            shift # past argument
            CAS_VIRTUAL_HOST="$1"
            shift # past value
            ;;
        *)
            # Not used
            extra_params="${extra_params} $1"
            shift # past argument
    ;;
    esac
done

echo
echo "=============="
echo "Variable check"
echo "=============="
echo ""
echo "  BASEIMAGE                       = ${BASEIMAGE}"
echo "  BASETAG                         = ${BASETAG}"
echo "  Platform                        = ${PLATFORM}"
echo "  Build System OS                 = ${OPERATING_SYSTEM}"
echo "  Mirror URL                      = ${SAS_RPM_REPO_URL}"
echo "  Deployment Data Zip             = ${SAS_VIYA_DEPLOYMENT_DATA_ZIP}"
echo "  Docker registry URL             = ${DOCKER_REGISTRY_URL}"
echo "  Docker registry namespace       = ${DOCKER_REGISTRY_NAMESPACE}"
echo "  Docker registry type            = ${DOCKER_REGISTRY_TYPE}"
echo "  HTTP Ingress endpoint           = ${CAS_VIRTUAL_HOST}"
echo "  Tag SAS will apply              = ${SAS_DOCKER_TAG}"
echo

#
# Build and push images and then generate manifests
#

echo
echo "=============================="
echo "Pull down SAS orchestrationCLI"
echo "=============================="
echo ""

# Default to indicate we will not run the orchestrationCLI
generate_playbook=false

if [[ -z ${SAS_VIYA_PLAYBOOK_DIR} ]]; then
    if [[ -n ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} ]]; then
        if [[ -f ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} ]]; then
            if [[ ! -f ${PWD}/sas-orchestration ]]; then
              if [[ "${OPERATING_SYSTEM}" == "darwin" ]]; then
                  echo "[INFO]  : Get orchestrationCLI Mac";echo
                  curl --silent --remote-name https://support.sas.com/installation/viya/34/sas-orchestration-cli/mac/sas-orchestration-osx.tgz
                  tar xvf sas-orchestration-osx.tgz
                  rm sas-orchestration-osx.tgz
              else
                echo "[INFO]  : Get orchestrationCLI";echo
                curl --silent --remote-name https://support.sas.com/installation/viya/34/sas-orchestration-cli/lax/sas-orchestration-linux.tgz
                tar xvf sas-orchestration-linux.tgz
                rm sas-orchestration-linux.tgz
              fi
            else
                echo "[INFO]  : Using available SAS Orchestration CLI version: $(./sas-orchestration --version)"
            fi

            # Used later to run the orchestrationCLI
            generate_playbook=true
        else
            echo;echo "[ERROR] : Could not find the zip file to use";echo
            exit 5
        fi
    else
        echo;echo "[ERROR] : Could not find a zip file to use";echo
        exit 5
    fi
else
    echo;echo "[WARN]  : Using deprecated method of providing the playbook directory";echo
fi

echo
echo "=================="
echo "Create directories"
echo "=================="
echo ""


# All steps happen inside of the debug directory
# Grab a fresh container.yml template and override it in the debug directory
[[ -z ${PROJECT_DIRECTORY+x} ]] && PROJECT_DIRECTORY=working
if [[ -d ${PROJECT_DIRECTORY}/ ]]; then
  mv "${PROJECT_DIRECTORY}" "${PROJECT_DIRECTORY}_${sas_datetime}"
fi
mkdir -p ${PROJECT_DIRECTORY}/roles/
# Copy over static roles, override others already added in the generated roles
cp -rf templates/static-roles/* ${PROJECT_DIRECTORY}/roles/
# Using -v instead of --verbose to support Mac OS
cp -v templates/container.yml ${PROJECT_DIRECTORY}/
cp -v templates/generate_manifests.yml ${PROJECT_DIRECTORY}/
cp -v templates/requirements.txt ${PROJECT_DIRECTORY}/

echo
echo "=============================="
echo "Create and activate virtualenv"
echo "=============================="
echo ""

[[ -z ${SAS_CREATE_AC_VIRTUAL_ENV+x} ]] && SAS_CREATE_AC_VIRTUAL_ENV="true"

# Python virtualenv configuration
if [[ "${SAS_CREATE_AC_VIRTUAL_ENV}" == "true" ]]; then
    # Detect virtualenv with $VIRTUAL_ENV
    if [[ -n $VIRTUAL_ENV ]]; then
        echo "Existing virtualenv detected..."
    # Create default env if none
    elif [[ -z $VIRTUAL_ENV ]] && [[ ! -d env/ ]]; then
        echo "Creating virtualenv env..."
        virtualenv --system-site-packages env
        . env/bin/activate
    # Activate existing env if available
    elif [[ -d env/ ]]; then
        echo "Activating virtualenv env..."
        . env/bin/activate
    fi
    # Ensure env active or die
    if [[ -z $VIRTUAL_ENV ]]; then
        echo "Failed to activate virtualenv....exiting."
        exit 1
    fi
    # Detect python 2+ or 3+
    PYTHON_MAJOR_VER="$(python -c 'import platform; print(platform.python_version()[0])')"
    if [[ $PYTHON_MAJOR_VER -eq "2" ]]; then
        # Install ansible-container
        pip install --upgrade pip==9.0.3
        pip install --no-deps ansible-container[docker]==0.9.2
        echo 'ENV DOCKER_CLIENT_TIMEOUT=600' >> "${VIRTUAL_ENV}"/lib/python2.7/site-packages/container/docker/templates/conductor-local-dockerfile.j2
    elif [[ $PYTHON_MAJOR_VER -eq "3" ]]; then
        echo "WARN: Python3 support is experimental in ansible-container."
        echo "Updating requirements file for python3 compatibility..."
        sed ${sed_i_option} '/ruamel.ordereddict==0.4.13/d' ./templates/requirements.txt
        pip install --upgrade pip==9.0.3
        pip install --no-deps -e git+https://github.com/ansible/ansible-container.git@release-0.9.2#egg=ansible-container[docker]
        echo "Updating the client timeout for the created virtual environment."
        echo 'ENV DOCKER_CLIENT_TIMEOUT=600' >> "${VIRTUAL_ENV}"/src/ansible-container/container/docker/templates/conductor-local-dockerfile.j2
    fi
    # Restore latest pip version
    pip install --upgrade pip setuptools
    pip install -r templates/requirements.txt
fi

# From here on out, everything is in the working directory
pushd ${PROJECT_DIRECTORY}

echo
echo "================="
echo "Generate Playbook"
echo "================="
echo ""

if [[ "${generate_playbook}" == "true" ]]; then
    echo;echo "[INFO]  : Generate programming playbook";echo
    ../sas-orchestration build \
      --input ${SAS_VIYA_DEPLOYMENT_DATA_ZIP} \
      --repository-warehouse ${SAS_RPM_REPO_URL} \
      --platform $PLATFORM \
      --deployment-type programming

    tar xvf ${PWD}/SAS_Viya_playbook.tgz
    SAS_VIYA_PLAYBOOK_DIR=${PWD}/sas_viya_playbook
fi

echo
echo "=========================================="
echo "Collect the services that need to be built"
echo "=========================================="
echo ""

all_services=() # Keep a list of the built services so they can be pushed a registry
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
            all_services+=( ${file,,} )

            echo "***   Create the roles directory for service '${file}'"; echo
            mkdir -p -v roles/${file}/tasks
            mkdir -p -v roles/${file}/templates
            mkdir -p -v roles/${file}/vars

            if [ ! -f "roles/${file}/tasks/main.yml" ]; then
                echo; echo "***     Copy the tasks file for service '${file}'"; echo
                cp -v ../templates/task.yml roles/${file}/tasks/main.yml
            else
                echo; echo "***     Tasks file for service '${file}' already exists"; echo
            fi

            # if [ ! -f "roles/${file}/templates/entrypoint" ]; then
            #     echo; echo "***     Copy the entrypoint file for service '${file}'"; echo
            #     cp -v ../templates/entrypoint roles/${file}/templates/entrypoint
            # else
            #     echo; echo "***     entrypoint file for service '${file}' already exists"; echo
            # fi

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
            rm -v roles/${role}/vars/${role}
        fi
        if [ -d roles/${role}/vars ]; then
            cp -v ${SAS_VIYA_PLAYBOOK_DIR}/group_vars/${role} roles/${role}/vars/
            chmod u+w roles/${role}/vars/${role}
        fi
    fi
done

echo
echo "================="
echo "Create input file"
echo "================="
echo ""

#
# When first starting with Ansible-Container, it would not take multiple
# var files. This section here dumps everything into one file and then
# adjusts the everything.yml file to make sure variables are in the correct order
#

echo
echo "PROJECT_NAME: ${PROJECT_NAME}" > everything.yml
echo "BASEIMAGE: ${BASEIMAGE}" >> everything.yml
echo "BASETAG: ${BASETAG}" >> everything.yml
echo "PLATFORM: ${PLATFORM}" >> everything.yml
echo "DOCKER_REGISTRY_URL: ${DOCKER_REGISTRY_URL}" >> everything.yml
echo "DOCKER_REGISTRY_NAMESPACE: ${DOCKER_REGISTRY_NAMESPACE}" >> everything.yml
echo "SAS_RECIPE_VERSION: ${SAS_RECIPE_VERSION}" >> everything.yml
echo "" >> everything.yml
echo "DEPLOYMENT_ID: viya" >> everything.yml
echo "SPRE_DEPLOYMENT_ID: spre" >> everything.yml

cp ${SAS_VIYA_PLAYBOOK_DIR}/group_vars/all temp_all
chmod u+w temp_all

# MAC sed works different than linux
# https://stackoverflow.com/a/22084103/1212443
if [[ "$OPERATING_SYSTEM" == "darwin" ]]; then
    sed_i_option="-i ''"
else
    sed_i_option='-i '
fi

sed ${sed_i_option} 's|^DEPLOYMENT_ID:.*||' temp_all
sed ${sed_i_option} 's|^SPRE_DEPLOYMENT_ID:.*||' temp_all

cat temp_all >> everything.yml

rm -v temp_all

cat ${SAS_VIYA_PLAYBOOK_DIR}/vars.yml >> everything.yml
cat ${SAS_VIYA_PLAYBOOK_DIR}/internal/soe_defaults.yml >> everything.yml

sed ${sed_i_option} 's|---||g' everything.yml
sed ${sed_i_option} 's|^SERVICE_NAME_DEFAULT|#SERVICE_NAME_DEFAULT|' everything.yml
sed ${sed_i_option} 's|^CONSUL_EXTERNAL_ADDRESS|#CONSUL_EXTERNAL_ADDRESS|' everything.yml
sed ${sed_i_option} 's|^YUM_INSTALL_BATCH_SIZE|#YUM_INSTALL_BATCH_SIZE|' everything.yml
sed ${sed_i_option} 's|^sasenv_license|#sasenv_license|' everything.yml
sed ${sed_i_option} 's|^sasenv_composite_license|#sasenv_composite_license|' everything.yml
sed ${sed_i_option} 's|^METAREPO_CERT_SOURCE|#METAREPO_CERT_SOURCE|' everything.yml
sed ${sed_i_option} 's|^ENTITLEMENT_PATH|#ENTITLEMENT_PATH|' everything.yml
sed ${sed_i_option} 's|^SAS_CERT_PATH|#SAS_CERT_PATH|' everything.yml
sed ${sed_i_option} 's|^SECURE_CONSUL:.*|SECURE_CONSUL: false|' everything.yml

#
# Copy over the certificates that will be needed to do the install
#

if [ -f ${PWD}/entitlement_certificate.pem ]; then
    rm ${PWD}/entitlement_certificate.pem
fi
cp -v ${SAS_VIYA_PLAYBOOK_DIR}/entitlement_certificate.pem .
chmod u+w entitlement_certificate.pem

if [ -f ${PWD}/SAS_CA_Certificate.pem ]; then
    rm ${PWD}/SAS_CA_Certificate.pem
fi
cp -v ${SAS_VIYA_PLAYBOOK_DIR}/SAS_CA_Certificate.pem .
chmod u+w SAS_CA_Certificate.pem

#
# Update Container yaml
#

if [ -f ${PWD}/consul.data ]; then
    # This is the default on MAC.
    # https://stackoverflow.com/a/46464081/1212443
    if [[ "${OPERATING_SYSTEM}" == "darwin" ]]; then
      consul_data_enc=$(cat ${PWD}/consul.data | base64 )
    else
      consul_data_enc=$(cat ${PWD}/consul.data | base64 --wrap=0 )
    fi
    sed ${sed_i_option} "s|CONSUL_KEY_VALUE_DATA_ENC=|CONSUL_KEY_VALUE_DATA_ENC=${consul_data_enc}|g" container.yml
fi

# This is the default on MAC.
# https://stackoverflow.com/a/46464081/1212443
if [[ "${OPERATING_SYSTEM}" == "darwin" ]]; then
  setinit_enc=$(cat ${SAS_VIYA_PLAYBOOK_DIR}/SASViyaV0300*.txt | base64 )
else
  setinit_enc=$(cat ${SAS_VIYA_PLAYBOOK_DIR}/SASViyaV0300*.txt | base64 --wrap=0 )
fi
sed ${sed_i_option} "s|SETINIT_TEXT_ENC=|SETINIT_TEXT_ENC=${setinit_enc}|g" container.yml
sed ${sed_i_option} "s|{{ DOCKER_REGISTRY_URL }}|${DOCKER_REGISTRY_URL}|" container.yml
sed ${sed_i_option} "s|{{ DOCKER_REGISTRY_NAMESPACE }}|${DOCKER_REGISTRY_NAMESPACE}|" container.yml
sed ${sed_i_option} "s|{{ PROJECT_NAME }}|${PROJECT_NAME}|" container.yml
if [[ -n ${CAS_VIRTUAL_HOST} ]]; then
    sed ${sed_i_option} "s|{{ CAS_VIRTUAL_HOST }}|${CAS_VIRTUAL_HOST}|" container.yml
else
    sed ${sed_i_option} "s|{{ CAS_VIRTUAL_HOST }}|sas-viya|" container.yml
fi

#
# Remove the playbook directory
#

#rm -rf ${SAS_VIYA_PLAYBOOK_DIR}

#
# Run ansible-container
#

echo; # Formatting
echo; # Formatting
echo; # Formatting

if [[ ! -z ${SKIP_BUILD+x} ]]; then
    echo "[INFO]  : Skipping build "
else
    echo
    echo "===================================="
    echo "Building SAS Docker images"
    echo "===================================="
    echo

    # Need to remove the latest tag as the push process is looking for the latest tag.
    # If we are running the build process a second time, the latest tag will be found
    # and pushed which may not be want we want. We will remove the latest tag
    # and then kick off ansible-container. ansible-container always tags the image
    # as latest and with a date-time stamp. Removing the latest tag does not remove
    # the image.
    echo -e "[INFO]  : Remove the latest tag from images if they already exist."
    readarray -t sorted_services < <(printf '%s\0' "${all_services[@]}" | sort -z | xargs -0n1)
    for service in "${sorted_services[@]}"; do
        set +e
        docker rmi ${PROJECT_NAME}-${service}:latest 2> /dev/null
        set -e
    done

    set +e
    ansible-container build &
    SAS_ANSIBLE_CONTAINER_PID=$!
    echo ${SAS_ANSIBLE_CONTAINER_PID} > ${PWD}/sas_ansible_container.pid
    set -e
fi

if [[ ! -z ${SKIP_PUSH+x} ]]; then
    echo "[INFO]  : Skipping push of images"
else
    [[ -z ${SAS_DOCKER_TAG+x} ]] && export SAS_DOCKER_TAG=${SAS_RECIPE_VERSION}-${sas_datetime}-${sas_sha1}

    echo
    echo "==================================="
    echo "Pushing SAS Docker images"
    echo "==================================="
    echo

    set +e

    if [[ "${DOCKER_REGISTRY_TYPE}" == "ecr" ]]; then
      ARG_DOCKER_REG_USERNAME=AWS

      PREFIX=' -p '
      SUFFIX=' -e none '

      aws_login=$(aws ecr get-login);
      ARG_DOCKER_REG_PASSWORD=`echo $aws_login | sed -e "s/.*${PREFIX}//;s/${SUFFIX}.*//"`

      set -x
      ansible-container push --push-to docker-registry --tag ${SAS_DOCKER_TAG} --username ${ARG_DOCKER_REG_USERNAME} --password ${ARG_DOCKER_REG_PASSWORD}
      set +x
    else
      push_images
    fi
    set -e
fi

if [[ ! -z ${SKIP_MANIFESTSx} ]]; then
    echo "[INFO]  : Skipping manifest building "
else
    echo
    echo "========================================="
    echo "Generating Kubernetes Manifests"
    echo "========================================="
    echo

    set +e
    # Ansible requires access to the host's libselinux-python lib. Setting ansible_python_interpreter.
    pip install ansible==2.7
    set -x
    ansible-playbook generate_manifests.yml -e "docker_tag=${SAS_DOCKER_TAG}" -e 'ansible_python_interpreter=/usr/bin/python'
    apgen_rc=$?
    set +x
    set -e

    if (( ${apgen_rc} != 0 )); then
        echo "[ERROR] : Unable to generate manifests"; echo
        exit 30
    fi
fi

popd # Takes us back to viya-multi-containers

exit 0
