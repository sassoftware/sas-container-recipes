#! /bin/bash

# Uncomment the following to enable debugging
# set -x

# Set up locale
if [ -f /etc/profile.d/lang.sh ];  then
    . /etc/profile.d/lang.sh
fi

###############################################################################
# Variables
###############################################################################

SAS_BIN="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
_DEPLOY_CNFG="${SAS_BIN}/../../config"
SASINSTANCE="default"
SASCASINSTANCE="default"
_SASCASINSTANCE="default"
SASTENANT="shared"
SASCASDATADIR="${_DEPLOY_CNFG}/data/cas/${SASCASINSTANCE}"
SASCASAPPSRVENABLED="true"
SASCONTROLLERHOST=localhost
SASCONSULHOST=localhost
SASCONTROLLERPORT=5570
SASCONTROLLERHTTPPORT=8777
_CAS_ROLE=controller

CONSUL_TOKEN_FILE="${_DEPLOY_CNFG}/etc/SASSecurityCertificateFramework/tokens/consul/${SASINSTANCE}/client.token"

_network_web_enabled="FALSE"
_network_sasdata_enabled="FALSE"

###############################################################################
# Functions
###############################################################################

function echo_line {
    line_out="$(date) - $1"
    printf "%s\n" "$line_out"
}

###############################################################################
# Process inputs
###############################################################################

while [ "$#" -gt 0 ]
do
    if [ "$1" = "-i" ]; then
        shift
        _SASCASINSTANCE="$1"
    elif [ "$1" = "-r" ]; then
        shift
        _rootdir="$1"
    elif [ "$1" = "--role" ]; then
        shift
        _CAS_ROLE="$1"
    else
        shift
    fi
    shift
done

if [ ! -z $_rootdir ]; then
    SASROOTDIR=$(dirname $_rootdir)
    SAS_BIN=$_rootdir/home/bin
    _DEPLOY_CNFG=$_rootdir/config
    SASCASDATADIR="${_DEPLOY_CNFG}/data/cas/${SASCASINSTANCE}"
    CONSUL_TOKEN_FILE="${_DEPLOY_CNFG}/etc/SASSecurityCertificateFramework/tokens/consul/${SASINSTANCE}/client.token"
fi

###############################################################################
# Process CAS specific settings
###############################################################################

[ -f ${_DEPLOY_CNFG}/etc/sysconfig/cas/${_SASCASINSTANCE}/sas-cascontroller ] && source ${_DEPLOY_CNFG}/etc/sysconfig/cas/${_SASCASINSTANCE}/sas-cascontroller
[ -f ${_DEPLOY_CNFG}/etc/sysconfig/cas/${_SASCASINSTANCE}/sas-cas ] && source ${_DEPLOY_CNFG}/etc/sysconfig/cas/${_SASCASINSTANCE}/sas-cas ${_rootdir} ${_SASCASINSTANCE}

###############################################################################
# Process environment settings
###############################################################################

[ -f /etc/sysconfig/sas/sasenv-${SASINSTANCE}.conf ] && . /etc/sysconfig/sas/sasenv-${SASINSTANCE}.conf

###############################################################################
# Check out inputs
###############################################################################

if [ -z ${SASTENANT} ] || [ -z ${SASCASINSTANCE} ] || [ -z ${SASCONTROLLERHOST} ] || [ -z ${SASCONTROLLERPORT} ] || [ -z ${SASCONTROLLERHTTPPORT} ] || [ -z ${SASCASAPPSRVENABLED} ] || [ -z ${SASCASDATADIR} ]; then
    echo_line "Not all options are set"
    exit 1;
fi

# See if the current host is the controller
[[ -z ${SAS_CURRENT_HOST+x} ]] && export SAS_CURRENT_HOST=$(hostname -f)
if [ "${_CAS_ROLE}" != "controller" ] && [ "${_CAS_ROLE}" != "backup" ]; then
    echo_line "Primary Controller Host   = ${SASCONTROLLERHOST}"
    echo_line "Secondary Controller Host = ${SASBACKUPHOST}"
    echo_line "Current Host              = ${SAS_CURRENT_HOST}"
    echo_line "Current host is neither the primary or secondary controller so not registering CAS service from ${SAS_CURRENT_HOST}"
    echo_line "Exiting with zero return code"
    exit 0
fi

# If we are in a deployment where the following values are set, then we are 
# in deployment where the port we want to register in consul is an external port
# and differs from the internal.
[[ -z ${SAS_CAS_CONTROLLER_PORT+x} ]] && export SAS_CAS_CONTROLLER_PORT=${SASCONTROLLERPORT}
[[ -z ${SAS_CAS_HTTP_PORT+x} ]] && export SAS_CAS_HTTP_PORT=${SASCONTROLLERHTTPPORT}

###############################################################################
# Setup up Consul options
###############################################################################

BOOTSTRAP_CMD="${SAS_BIN}/sas-bootstrap-config"

if [ -f ${BOOTSTRAP_CMD} ] && [ -f ${CONSUL_TOKEN_FILE} ]; then
    if [ -e ${_rootdir}/home/lib/envesntl/sas-start-functions ]; then
        echo_line "Sourcing init functions"
        source ${_rootdir}/home/lib/envesntl/sas-start-functions

        echo_line "Setting up variables for running sas_set_consul_vault"
        servicecontext="cas"
        [[ -z ${SASCONFIG+x} ]] && export SASCONFIG=${_DEPLOY_CNFG}

        # Running sas_set_consul_vault
        sas_set_consul_vault

        _deploy_id=$(basename $_rootdir)
        if [ "$_deploy_id" != "viya" ]; then
            echo_line "Adjusting CONSUL_TOKEN and VAULT_TOKEN based on multi-tenancy"
            export CONSUL_TOKEN=$(cat ${_DEPLOY_CNFG}/etc/SASSecurityCertificateFramework/tokens/consul/${_deploy_id}/${SASINSTANCE}/client.token)
            export VAULT_TOKEN=$(cat ${_DEPLOY_CNFG}/etc/SASSecurityCertificateFramework/tokens/${servicecontext}/${_deploy_id}/${SASINSTANCE}/vault.token)
        fi
    else
        # Following is needed to cover VI BOSH releases
        BOOTSTRAP_CMD="${BOOTSTRAP_CMD} --token-file ${CONSUL_TOKEN_FILE} --consul ${SASCONSULHOST}:8500"
    fi

    echo_line "wait until Consul is ready"
    _consul_leader=$(${BOOTSTRAP_CMD} status leader --wait --tick-seconds 5 --timeout-seconds 60)
    rc=$?

    if [ $rc != 0 ]; then
        echo_line "Failed to get Consul leader"
        exit $rc;
    fi
else
    echo_line "Error: Either ${CONSUL_TOKEN_FILE} or ${BOOTSTRAP_CMD} is not present"
    exit 1;
fi

echo_line ""

###############################################################################
# Process TLS toggles
###############################################################################

if [ ! -z "${CONSUL_TOKEN}" ]; then
    # Get the TLS settings for the application and if those are not present, then the global settings
    _network_web_enabled=$(${BOOTSTRAP_CMD} kv read config/cas-${SASTENANT}-${SASCASINSTANCE}-http/sas.security/network.web.enabled)
    if [ -z $_network_web_enabled ]; then
        _network_web_enabled=$(${BOOTSTRAP_CMD} kv read config/application/sas.security/network.web.enabled)
    fi

    _network_sasdata_enabled=$(${BOOTSTRAP_CMD} kv read config/cas-${SASTENANT}-${SASCASINSTANCE}/sas.security/network.sasData.enabled)
    if [ -z $_network_sasdata_enabled ]; then
        _network_sasdata_enabled=$(${BOOTSTRAP_CMD} kv read config/application/sas.security/network.sasData.enabled)
    fi
fi

###############################################################################
# Register in Consul
###############################################################################

_rest_port_ssl=""
if [ "$_network_web_enabled" = "true" ]; then
    _rest_port_ssl="--tags restProtocol=https"
fi

_tag_role="--tags controller"
_tag_proxy="--tags proxy"
if [ "${_CAS_ROLE}" = "backup" ]; then
    _tag_role="$_tag_role --tags ${_CAS_ROLE}"
    _tag_proxy=""
elif [ "${_CAS_ROLE}" = "controller" ]; then
    _tag_role="$_tag_role --tags primary"
fi

echo_line "Register the CAS service along with the CAS binary port"
if [ "$_network_sasdata_enabled" = "true" ]; then
    ${BOOTSTRAP_CMD} agent service register \
        --name "cas-${SASTENANT}-${SASCASINSTANCE}"  \
        --address "${SAS_CURRENT_HOST}" \
        --port ${SAS_CAS_CONTROLLER_PORT} \
        ${_tag_role} \
        --tags "restPort=${SAS_CAS_HTTP_PORT}" \
        ${_rest_port_ssl} \
        --tags "appServerEnabled=${SASCASAPPSRVENABLED}" \
        --tags "rootLibPath=${SASCASDATADIR}" \
        --tags "ssl" \
        "cas-${SASTENANT}-${SASCASINSTANCE}"
else
    ${BOOTSTRAP_CMD} agent service register \
        --name "cas-${SASTENANT}-${SASCASINSTANCE}"  \
        --address "${SAS_CURRENT_HOST}" \
        --port ${SAS_CAS_CONTROLLER_PORT} \
        ${_tag_role} \
        --tags "restPort=${SAS_CAS_HTTP_PORT}" \
        ${_rest_port_ssl} \
        --tags "appServerEnabled=${SASCASAPPSRVENABLED}" \
        --tags "rootLibPath=${SASCASDATADIR}" \
        "cas-${SASTENANT}-${SASCASINSTANCE}"
fi
rc=$?

if [ $rc != 0 ]; then
    echo_line "Failed to register the service cas-${SASTENANT}-${SASCASINSTANCE} on port ${SAS_CAS_CONTROLLER_PORT}"
    exit $rc;
else
    echo_line "cas-${SASTENANT}-${SASCASINSTANCE} has been registered in Consul"
fi

echo_line "Register the CAS binary port for system monitoring"
${BOOTSTRAP_CMD} agent check register \
    --service-id "cas-${SASTENANT}-${SASCASINSTANCE}" \
    --id "cas-${SASTENANT}-${SASCASINSTANCE}-client" \
    --name "casport"  \
    --tcp "${SAS_CURRENT_HOST}:${SAS_CAS_CONTROLLER_PORT}" --interval 60s --timeout 5s
rc=$?

if [ $rc != 0 ]; then
    echo_line "Failed to register the check for cas-${SASTENANT}-${SASCASINSTANCE} on port ${SAS_CAS_CONTROLLER_PORT}"
    exit $rc;
fi

# Only register the http service if we are the controller. If we register the backup http service
# this will cause problems in the rest of the system.
#if [ "${_CAS_ROLE}" = "controller" ]; then
#    echo_line "Register the CAS HTTP service along with the HTTP port"
    if [ "$_network_web_enabled" = "true" ]; then
        ${BOOTSTRAP_CMD} agent service register \
            --name "cas-${SASTENANT}-${SASCASINSTANCE}-http"  \
            --address "${SAS_CURRENT_HOST}" \
            --port ${SAS_CAS_HTTP_PORT} \
            ${_tag_proxy} \
            --tags "https" \
            "cas-${SASTENANT}-${SASCASINSTANCE}-http"
    else
        ${BOOTSTRAP_CMD} agent service register \
            --name "cas-${SASTENANT}-${SASCASINSTANCE}-http"  \
            --address "${SAS_CURRENT_HOST}" \
            --port ${SAS_CAS_HTTP_PORT} \
            ${_tag_proxy} \
            "cas-${SASTENANT}-${SASCASINSTANCE}-http"
    fi
    rc=$?

    if [ $rc != 0 ]; then
        echo_line "Failed to register the service cas-${SASTENANT}-http-${SASCASINSTANCE} on port ${SAS_CAS_HTTP_PORT}"
        exit $rc;
    else
        echo_line "cas-${SASTENANT}-${SASCASINSTANCE}-http has been registered in Consul"
    fi
#fi

echo_line "Register the CAS HTTP port for system monitoring"
if [ "$_network_web_enabled" = "true" ]; then
    ${BOOTSTRAP_CMD} agent check register \
        --service-id "cas-${SASTENANT}-${SASCASINSTANCE}-http" \
        --id "cas-${SASTENANT}-${SASCASINSTANCE}-http" \
        --name "cashttpport"  \
        --http "https://${SAS_CURRENT_HOST}:${SAS_CAS_HTTP_PORT}" --interval 60s --timeout 5s
else
    ${BOOTSTRAP_CMD} agent check register \
        --service-id "cas-${SASTENANT}-${SASCASINSTANCE}-http" \
        --id "cas-${SASTENANT}-${SASCASINSTANCE}-http" \
        --name "cashttpport"  \
        --http "http://${SAS_CURRENT_HOST}:${SAS_CAS_HTTP_PORT}" --interval 60s --timeout 5s
fi
rc=$?

if [ $rc != 0 ]; then
    echo_line "Failed to register the check cas-${SASTENANT}-http-${SASCASINSTANCE} on port ${SAS_CAS_HTTP_PORT}"
    exit $rc;
fi
