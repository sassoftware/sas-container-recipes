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

[[ -z ${SASROOT+x} ]]          && export SASROOT=/opt/sas
[[ -z ${SASDEPLOYID+x} ]]      && export SASDEPLOYID=viya
[[ -z ${SASINSTANCE+x} ]]      && export SASINSTANCE=default
[[ -z ${SASHOME+x} ]]          && export SASHOME=${SASROOT}/${SASDEPLOYID}/home
[[ -z ${SASCONFIG+x} ]]        && export SASCONFIG=${SASROOT}/${SASDEPLOYID}/config
[[ -z ${SASTENANT+x} ]]        && SASTENANT="shared"

CONSUL_TOKEN_FILE="${SASCONFIG}/etc/SASSecurityCertificateFramework/tokens/consul/${SASINSTANCE}/client.token"

###############################################################################
# Functions
###############################################################################

function echo_line {
    line_out="$(date) - $1"
    printf "%s\n" "$line_out"
}

###############################################################################
# Setup up Consul options
###############################################################################

BOOTSTRAP_CMD="${SASHOME}/bin/sas-bootstrap-config"

if [ -f ${BOOTSTRAP_CMD} ] && [ -f ${CONSUL_TOKEN_FILE} ]; then
    if [ -e ${SASHOME}/lib/envesntl/sas-start-functions ]; then
        echo_line "Sourcing init functions"
        source ${SASHOME}/lib/envesntl/sas-start-functions

        echo_line "Setting up variables for running sas_set_consul_vault"
        # shellcheck disable=SC2034
        servicecontext="espserver"

        # Running sas_set_consul_vault
        sas_set_consul_vault
    fi

    echo_line "wait until Consul is ready"
    # shellcheck disable=SC2034
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
# Unregister ESP
###############################################################################

# deregister the HTTP port
echo_line "Remove registration of the ESP HTTP service"
${BOOTSTRAP_CMD} agent service deregister \
    "esp-${SASTENANT}-${SASINSTANCE}-http"
rc=$?

if [ $rc != 0 ]; then
    echo_line "Failed to remove the esp-${SASTENANT}-${SASINSTANCE}-http service"
    exit $rc;
fi

# deregister the pubsub port
echo_line "Remove registration of the ESP service"
${BOOTSTRAP_CMD} agent service deregister \
    "esp-${SASTENANT}-${SASINSTANCE}-pubsub"
rc=$?

if [ $rc != 0 ]; then
    echo_line "Failed to remove the esp-${SASTENANT}-${SASINSTANCE}-pubsub service"
    exit $rc;
fi

