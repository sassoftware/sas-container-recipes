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
[[ -z ${SASCONSULHOST+x} ]]    && SASCONSULHOST=localhost
[[ -z ${SAS_CURRENT_HOST+x} ]] && SAS_CURRENT_HOST=$(hostname -i)
[[ -z ${ESP_HTTP_PORT+x} ]]    && export ESP_HTTP_PORT=31415
[[ -z ${ESP_PUBSUB_PORT+x} ]]  && export ESP_PUBSUB_PORT=31416

CONSUL_TOKEN_FILE="${SASCONFIG}/etc/SASSecurityCertificateFramework/tokens/consul/${SASINSTANCE}/client.token"

_network_web_enabled="FALSE"

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
# Process TLS toggles
###############################################################################

if [ ! -z "${CONSUL_TOKEN}" ]; then
    # Get the TLS settings for the application and if those are not present, then the global settings
    _network_web_enabled=$(${BOOTSTRAP_CMD} kv read config/esp-${SASTENANT}-${SASINSTANCE}/sas.security/network.web.enabled)
    if [[ -z $_network_web_enabled ]]; then
        _network_web_enabled=$(${BOOTSTRAP_CMD} kv read config/application/sas.security/network.web.enabled)
    fi
fi

###############################################################################
# Register in Consul
###############################################################################

esp_service_name="SASESP"
esp_http_port=${ESP_HTTP_PORT}

_tag_tenant=""
if [ "${SASTENANT}" != "shared" ]; then
    _tag_tenant="--tags tenant=${SASTENANT}"
fi

_tag_rest_port_ssl=""
if [ "$_network_web_enabled" = "true" ]; then
    _tag_rest_port_ssl="--tags restProtocol=https"
fi

_tag_proxy="--tags proxy"

echo_line "Register the ESP service"

if [ "$_network_web_enabled" = "true" ]; then
    # shellcheck disable=SC2086
    ${BOOTSTRAP_CMD} agent service register \
        --name "${esp_service_name}"  \
        --address "${SAS_CURRENT_HOST}" \
        --port ${esp_http_port} \
        ${_tag_proxy} \
        --tags "https" \
        ${_tag_tenant} \
        ${_tag_rest_port_ssl} \
        "esp-${SASTENANT}-${SASINSTANCE}-http"
else
    # shellcheck disable=SC2086
    ${BOOTSTRAP_CMD} agent service register \
        --name "${esp_service_name}"  \
        --address "${SAS_CURRENT_HOST}" \
        --port ${esp_http_port} \
        ${_tag_proxy} \
        ${_tag_tenant} \
        ${_tag_rest_port_ssl} \
        "esp-${SASTENANT}-${SASINSTANCE}-http"
fi
rc=$?

if [ $rc != 0 ]; then
    echo_line "Failed to register the service esp-${SASTENANT}-${SASINSTANCE}-http on port ${esp_http_port}"
    exit $rc;
else
    echo_line "esp-${SASTENANT}-${SASINSTANCE}-http has been registered in Consul"
fi

echo_line "Register the ESP HTTP port for system monitoring"
if [ "$_network_web_enabled" = "true" ]; then
    ${BOOTSTRAP_CMD} agent check register \
        --service-id "esp-${SASTENANT}-${SASINSTANCE}-http" \
        --id "esp-${SASTENANT}-${SASINSTANCE}-http" \
        --name "esphttpport"  \
        --http "https://${SAS_CURRENT_HOST}:${esp_http_port}/${esp_service_name}" --interval 60s --timeout 5s
else
    ${BOOTSTRAP_CMD} agent check register \
        --service-id "esp-${SASTENANT}-${SASINSTANCE}-http" \
        --id "esp-${SASTENANT}-${SASINSTANCE}-http" \
        --name "esphttpport"  \
        --http "http://${SAS_CURRENT_HOST}:${esp_http_port}/${esp_service_name}" --interval 60s --timeout 5s
fi
rc=$?

if [ $rc != 0 ]; then
    echo_line "Failed to register the check esp-${SASTENANT}-${SASINSTANCE}-http on port ${esp_http_port}"
    exit $rc;
fi

echo_line "Register the ESP pubsub service"
# shellcheck disable=SC2086
${BOOTSTRAP_CMD} agent service register \
    --name "esp-${SASTENANT}-${SASINSTANCE}-pubsub"  \
    --address "${SAS_CURRENT_HOST}" \
    --port ${ESP_PUBSUB_PORT} \
    ${_tag_tenant} \
    "esp-${SASTENANT}-${SASINSTANCE}-pubsub"
rc=$?

if [ $rc != 0 ]; then
    echo_line "Failed to register the service esp-${SASTENANT}-${SASINSTANCE} on port ${ESP_PUBSUB_PORT}"
    exit $rc;
else
    echo_line "esp-${SASTENANT}-${SASINSTANCE} has been registered in Consul"
fi

echo_line "Register the ESP pubsub port for system monitoring"
${BOOTSTRAP_CMD} agent check register \
    --service-id "esp-${SASTENANT}-${SASINSTANCE}-pubsub" \
    --id "esp-${SASTENANT}-${SASINSTANCE}-pubsub" \
    --name "esppubsub"  \
    --tcp "${SAS_CURRENT_HOST}:${ESP_PUBSUB_PORT}" --interval 60s --timeout 5s
rc=$?

if [ $rc != 0 ]; then
    echo_line "Failed to register the check esp-${SASTENANT}-${SASINSTANCE}-pubsub on port ${ESP_PUBSUB_PORT}"
    exit $rc;
fi
