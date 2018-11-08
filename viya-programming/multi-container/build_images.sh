#! /bin/bash -e
#
# Install and run ansible-container 
#
#if [[ -z ${DOCKER_URL+x} ]]; then
    # Need the URL in order to push to and pull from
#    exit 10
#fi

#[[ -z ${DOCKER_NAMESPACE+x} ]] && DOCKER_NAMESPACE=sas

#echo "DOCKER_URL: ${DOCKER_URL}" >> everything.yml
#echo "DOCKER_NAMESPACE: ${DOCKER_NAMESPACE}" >> everything.yml

# if ${SAS_CREATE_AC_VRITUAL_ENV}; then
    # virtualenv ac-env
    # source ac-env/bin/activate
    # pip install --upgrade pip==9.0.3
    # pip install ansible-container[docker]
    # pip install --requirement requirements.txt
    # deactivate
# fi

# if [[ -z ${SAS_AC_VIRTUAL_ENV+x} ]]; then
    # if [ -d "${PWD}/ac-env" ]; then
        # source ${PWD}/ac-env/bin/activate
    # elif [ -d "${PWD}/ac-venv" ]; then
        # source ${PWD}/ac-venv/bin/activate
    # else
        # echo "[WARNING] : Unable to find virtual environment not so not running ansible-container"; echo
        # exit 0
    # fi
# else
    # source ${SAS_AC_VIRTUAL_ENV}/bin/activate
# fi

# ansible-container build

# if (( $rc != 0 )); then
    # echo "[ERROR] : Unable to build Docker images"; echo
    # exit 20
# fi

# [[ -z ${TAG+x} ]] && export TAG=$(date +"%Y%m%d%H%M")
# ansible-container push --push-to docker-registry --tag ${TAG} ${ARG_DOCKER_REG_USERNAME} ${ARG_DOCKER_REG_PASSWORD}

# if (( $rc != 0 )); then
    # echo "[ERROR] : Unable to push Docker images"; echo
    # exit 22
# fi

# deactivate

# ansible-playbook generate-manifests -e 'docker_tag=${TAG}'

# if (( $rc != 0 )); then
    # echo "[ERROR] : Unable to generate manifests"; echo
    # exit 30
# fi
