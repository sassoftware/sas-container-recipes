#!/bin/bash
#This script is used to create vault certs for our local consul agents.
# This script is expected to be run after trust store has been built with vault-ca.crt
# Consul must be up for this to work. Vault relies on Consul and we need Vault for our vault certificates.
echo "Bringing in consul logging functions, env vars, useful consul configuration functions, and consul's sysconfig file."
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPTPATH}/basic_logging.sh"
. "${SCRIPTPATH}/consul-utils.sh"
. /etc/sysconfig/sas/sas-viya-consul-default

info_msg "Removing Viya3.3 certificates and keys if they exist"
remove_viya33_certs

SECURE_CONSUL=$(echo $SECURE_CONSUL | tr '[:upper:]' '[:lower:]')
info_msg "SECURE_CONSUL is ${SECURE_CONSUL}."
if [[ "${SECURE_CONSUL}" == "false" ]]; then
  info_msg "This means that consul will not get a vault certificate"
  info_msg "Creating our config-consul-ports json"
  create_consul_port_config_json insecure
  if [[ $? -eq 1 ]]; then
    info_msg "Failed to create our consul port configuration file. Exiting 1."
    exit 1
  fi
  if [[ -f "${SAS_CONSUL_SERVER_CRT}" ]]; then
    info_msg "Found a consul cert. Removing it since we are not going to secure consul."
    remove_output=$(rm -v ${SAS_CONSUL_SERVER_CRT})
    info_msg "${remove_output}"
  fi

  if [[ -f "${SAS_CONSUL_SERVER_KEY}" ]]; then
    info_msg "Found a consul key. Removing it since we are not going to secure consul."
    remove_output=$(rm -v ${SAS_CONSUL_SERVER_KEY})
    info_msg "${remove_output}"
  fi

  if [[ -f "${CONSUL_VAULT_TOKEN_FILE}" ]]; then
    info_msg "Found a vault token for consul. Removing it since we are not securing consul."
    remove_output=$(rm -v ${CONSUL_VAULT_TOKEN_FILE})
    info_msg "${remove_output}"
  fi
  info_msg "Exiting 0"
  exit 0
fi

#wait for vault to come up.
if [[ ${RUNNING_IN_DOCKER} != "true" ]]; then
  info_msg "Creating folders if they don't exist to log the output of get_vault_and_consul_address command"
  mkdir -pv ${SASCONFIG}/var/log/consul/default/
  chown ${SASUSER}:${SASGROUP} ${SASCONFIG}/var/log/consul/default/
fi
VAULT_ADDR=""
while [[ "${VAULT_ADDR}" == "" ]];
do
  if [[ ${RUNNING_IN_DOCKER} != "true" ]]; then
    VAULT_ADDR=$(get_vault_and_consul_address 2>>${SASCONFIG}/var/log/consul/default/localconsul_generate_vault_cert.log)
  else
    VAULT_ADDR=$(get_vault_and_consul_address)
  fi
  VAULT_ADDR=$(echo $VAULT_ADDR | sed "s#|.*##")
  info_msg "Vault address is: ${VAULT_ADDR}"
  if [[ "${total_time_waited}" -ge 900 ]]; then
    info_msg "Spent 15 minutes trying to get a vault address."
    info_msg "Exiting 1"
    exit 1
  fi
  sleep 5s
  let "total_time_waited = total_time_waited + 5"
  info_msg "Total time waited so far=${total_time_waited} seconds"
done
info_msg "Found Vault:${VAULT_ADDR}."
info_msg "Getting Vault Certificate."
generate_vault_certificate $VAULT_ADDR
RESULT=$?
if [[ "${RESULT}" -eq 1 ]]; then
  error_msg $LINENO "Failed to generate a vault certificate because VAULT_ADDR is blank (${VAULT_ADDR}). Exiting 1"
  exit 1
fi
if [[ "${RESULT}" -eq 2 ]]; then
  error_msg $LINENO "Failed to generate a vault certificate because there was no vault ca found in our cacert folder."
  exit 2
fi
if [[ "${RESULT}" -eq 3 ]]; then
  error_msg $LINENO "Timed out attempting to get a vault cert."
  exit 3
fi

info_msg "Copying cert and key to referenced location"
chown ${SASUSER}:${SASGROUP} "${VAULT_KEY}" "${VAULT_CRT}"
chmod 600 "${VAULT_KEY}"
chmod 644 "${VAULT_CRT}"
copy_output=$(cp -pv "${VAULT_KEY}" "${SAS_CONSUL_SERVER_KEY}") #set to capture the output
info_msg "${copy_output}"
copy_output=$(cp -pv "${VAULT_CRT}" "${SAS_CONSUL_SERVER_CRT}")
info_msg "${copy_output}"

info_msg "Creating our port config file @ ${SASCONFIG}/etc/consul.d/config-consul-ports.json"
create_consul_port_config_json secured
if [[ $? -eq 1 ]]; then
  info_msg "Failed to create our consul port configuration file. Exiting 1."
  exit 1
fi
cat ${SASCONFIG}/etc/consul.d/config-consul-ports.json
