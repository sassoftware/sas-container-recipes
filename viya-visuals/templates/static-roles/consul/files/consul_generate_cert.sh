#!/bin/bash
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPTPATH}/basic_logging.sh"
. "${SCRIPTPATH}/consul-utils.sh"
. /etc/sysconfig/sas/sas-viya-consul-default

function distribute_consul_public_certs(){
  if [[ ${RUNNING_IN_DOCKER} != "true" ]]; then
    info_msg "Going to copy this certificate to all other consul machines"
    machine_ip=$(hostname -i)
    ip_list=$(get_local_ip_address_list)
    info_msg "CONSUL_SERVER_LIST is ${CONSUL_SERVER_LIST}"
    IFS=","
    for ip in ${CONSUL_SERVER_LIST};
    do
      info_msg "IP=$ip"
      ip_no_space=$(echo -e "${ip}" | tr -d '[:space:]' )
      ip="${ip_no_space}"
      found_ip=false
      for i in $ip_list;
      do
        if [[ "$i" == "$ip" ]]; then
          info_msg "Found machine ip, will not copy to same machine"
          found_ip=true
        fi
      done
      if [[ "${found_ip}" == false ]]; then
        info_msg "copying cert from $machine_ip to $ip"
        su - ${SASUSER} -c "scp -i  ~${SASUSER}/.ssh/sas_key ${SASCONFIG}/etc/SASSecurityCertificateFramework/cacerts/consul-$(hostname -s).crt $ip:${SASCONFIG}/etc/SASSecurityCertificateFramework/cacerts/"
      fi
    done
  fi
  #similar wait loop in docker-entrypoint.sh
  info_msg "Waiting for there to be ${CONSUL_BOOTSTRAP_EXPECT} consul certificates in ${SAS_ANCHORS_DIR}"
  count=0
  while [[ ${count} -lt ${CONSUL_BOOTSTRAP_EXPECT} ]];
  do
    sleep 1s
    info_msg "Count is $count."
    count=$(get_consul_public_cert_count ${SAS_ANCHORS_DIR}/)
    if [[ $? -ne 0 ]]; then
      error_msg $LINENO "Error occurred while trying to count the number of self-signed certs. Exiting 1."
      exit 1
    fi
  done
  info_msg "Finished waiting for all certs to be present"
  directory_output="$(ls ${SAS_ANCHORS_DIR}/)"
  info_msg "${directory_output}"
}

info_msg "Removing Viya3.3 certificates and keys if they exist"
remove_viya33_certs

if [[ $RUNNING_IN_DOCKER == "true" ]]; then
  mkdir_output=$(mkdir -pv ${SAS_CONSUL_SERVER_PRI_DIR} ${SAS_CONSUL_SERVER_TLS_DIR})
  chown -R ${SASUSER}:${SASGROUP} ${SAS_CONSUL_SERVER_PRI_ROOT_DIR} ${SAS_CONSUL_SERVER_TLS_ROOT_DIR}
  info_msg "${mkdir_output}"
  if [ -f ${CONSUL_SECRETS_DIR}/server.crt ]; then
    info_msg "Copying server cert to ephemeral storage."
    cp -vf ${CONSUL_SECRETS_DIR}/server.crt ${SAS_CONSUL_SERVER_CRT}
    if [[ $? -ne 0 ]]; then
      error_msg $LINENO "Failed to copy server cert from ${CONSUL_SECRETS_DIR}/server.crt to ${SAS_CONSUL_SERVER_CRT}"
      exit 1
    fi
  fi
  if [ -f ${CONSUL_SECRETS_DIR}/server.key ]; then
    info_msg "Copying server key to ephemeral storage"
    cp -vf ${CONSUL_SECRETS_DIR}/server.key ${SAS_CONSUL_SERVER_KEY}
    if [[ $? -ne 0 ]]; then
      error_msg $LINENO "Failed to copy server key from ${CONSUL_SECRETS_DIR}/server.key to ${SAS_CONSUL_SERVER_KEY}"
      exit 1
    fi
  fi
fi

SECURE_CONSUL=$(echo $SECURE_CONSUL | tr '[:upper:]' '[:lower:]')
if [[ ${SECURE_CONSUL} == "true" ]]; then
  info_msg "SECURE_CONSUL was true. We are securing consul."
  if [[ ! -s ${SAS_CONSUL_SERVER_KEY} ]] || [[ ! -s ${SAS_CONSUL_SERVER_CRT} ]]; then
    info_msg "Generating a self-signed certificate."
    mkdir_output=$(mkdir -pv ${SAS_CONSUL_SERVER_PRI_DIR} ${SAS_CONSUL_SERVER_TLS_DIR})
    chown -R ${SASUSER}:${SASGROUP} ${SAS_CONSUL_SERVER_PRI_ROOT_DIR} ${SAS_CONSUL_SERVER_TLS_ROOT_DIR}
    info_msg "${mkdir_output}"
    generate_self_signed_certificate ${SAS_CONSUL_SERVER_CRT} ${SAS_CONSUL_SERVER_KEY}
    if [[ $? -ne 0 ]]; then
      error_msg $LINENO "Failed to create a self-signed certificate."
      exit 1
    fi
    info_msg "Creating our consul-port-config.json"
    create_consul_port_config_json secured
    if [[ $? -eq 1 ]]; then
      error_msg $LINENO "Failed to create our consul port configuration file. Exiting 1."
      exit 1
    fi
  else
    info_msg "Using the cert and key already present."
    create_consul_port_config_json secured
    if [[ $? -eq 1 ]]; then
      error_msg $LINENO "Failed to create our consul port configuration file. Exiting 1."
      exit 1
    fi
  fi
  cat ${SASCONFIG}/etc/consul.d/config-consul-ports.json
  info_msg "Copying our certificate to the cacerts location so it can be added to the trust store."

  if [[ -n ${CACERTS_CONFIGMAP} ]]; then
    info_msg "Detected Kubernetes ConfigMap usage. Posting this server's certificate to ${CACERTS_CONFIGMAP}"
    post_file_contents_to_configmap "$CACERTS_CONFIGMAP" "consul-$(hostname -s).crt" "$SAS_CONSUL_SERVER_CRT"
    if [ $? -ne 0 ]; then
       error_msg $LINENO "Failed to post this server's certificate to ${CACERTS_CONFIGMAP}. Exiting."
       exit 1
    fi
    info_msg "Successfully posted this server's certificate to ${CACERTS_CONFIGMAP}"
  else
    copy_output=$(cp -pv $SAS_CONSUL_SERVER_CRT ${SAS_ANCHORS_DIR}/consul-$(hostname -s).crt)
    if [[ $? -ne 0 ]]; then
      error_msg $LINENO "Failed to copy the ca cert to the correct location."
      exit 1
    fi
    info_msg "${copy_output}"
  fi

  info_msg "We need to distribute our certificate to other machines in the trust store."
  distribute_consul_public_certs
else
  info_msg "SECURE CONSUL variable was unset or false."
  info_msg "SECURE_CONSUL=$SECURE_CONSUL"
  echo "Creating our consul-port-config.json"
  create_consul_port_config_json insecure
  if [[ $? -eq 1 ]]; then
    info_msg "Failed to create our consul port configuration file. Exiting 1."
    exit 1
  fi
  cat ${SASCONFIG}/etc/consul.d/config-consul-ports.json
  if [[ -f "${SAS_CONSUL_SERVER_CRT}" ]]; then
    info_msg "Found a consul cert. Removing it since we are not going to secure consul."
    rm ${SAS_CONSUL_SERVER_CRT}
  fi

  if [[ -f "${SAS_CONSUL_SERVER_KEY}" ]]; then
    info_msg "Found a consul key. Removing it since we are not going to secure consul."
    rm -v ${SAS_CONSUL_SERVER_KEY}
  fi

  if [[ -f "${CONSUL_VAULT_TOKEN_FILE}" ]]; then
    info_msg "Found a vault token for consul. Removing it since we are not securing consul."
    rm -v ${CONSUL_VAULT_TOKEN_FILE}
  fi
  info_msg "Exiting without creating a certificate"
fi

