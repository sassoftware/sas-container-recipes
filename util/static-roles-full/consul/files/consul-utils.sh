#!/bin/bash
echo "Bringing in some basic logging functions"
SCRIPTPATH="$( cd "$(dirname "$BASH_SOURCE")" ; pwd -P )"
. "${SCRIPTPATH}/basic_logging.sh"
[[ -n ${SASHOME} ]] || SASHOME="/opt/sas/viya/home"
debug_msg "SASHOME = ${SASHOME}"
[[ -n ${SASCONFIG} ]] || SASCONFIG=/opt/sas/viya/config
debug_msg "SASCONFIG=${SASCONFIG}"
[[ -n ${CONSUL_CONFIG_DIR} ]] || CONSUL_CONFIG_DIR=${SASCONFIG}/etc/consul.d  #Files are already located in this default location. They are important files.
debug_msg "CONSUL_CONFIG_DIR=${CONSUL_CONFIG_DIR}"

debug_msg "Setting locations of useful tools"
[[ -n ${SAS_CRYPTO_MANAGEMENT} ]] || SAS_CRYPTO_MANAGEMENT=${SASHOME}/SASSecurityCertificateFramework/bin/sas-crypto-management
debug_msg "SAS_CRYPTO_MANAGEMENT: ${SAS_CRYPTO_MANAGEMENT}"
[[ -n ${SAS_BOOTSTRAP_CONFIG} ]] || SAS_BOOTSTRAP_CONFIG=${SASHOME}/bin/sas-bootstrap-config
debug_msg "SAS_BOOTSTRAP_CONFIG: ${SAS_BOOTSTRAP_CONFIG}"
[[ -n ${SAS_CONFIGURATION_CLI} ]] || SAS_CONFIGURATION_CLI=${SASHOME}/libexec/admin-plugins/sas-configuration-cli
debug_msg "SAS_CONFIGURATION_CLI=${SAS_CONFIGURATION_CLI}"
debug_msg "Setting some default paths to useful artifacts if an env for their path is not already set."
[[ -n ${CONSUL_HTTP_ADDR} ]] || . ${SASCONFIG}/consul.conf
debug_msg "CONSUL_HTTP_ADDR=${CONSUL_HTTP_ADDR}"
[[ -n ${VAULT_TRUSTERS_CONSUL_PATH} ]] || VAULT_TRUSTERS_CONSUL_PATH="locks/consul_serial_restart/vault_trusters"
debug_msg "VAULT_TRUSTERS_CONSUL_PATH=${VAULT_TRUSTERS_CONSUL_PATH}"
[[ -n ${CONSUL_LOCK_PATH} ]] || CONSUL_LOCK_PATH="lock/tls/vault_cert/consul/"
debug_msg "CONSUL_LOCK_PATH=${CONSUL_LOCK_PATH}"
[[ -n ${VAULT_CERT_LIST_PATH} ]] || VAULT_CERT_LIST_PATH="${CONSUL_LOCK_PATH}has_vault_cert"
debug_msg "VAULT_CERT_LIST_PATH=${VAULT_CERT_LIST_PATH}"
[[ -n ${CONSUL_SERVICE_NAME} ]] || CONSUL_SERVICE_NAME="consul"
debug_msg "CONSUL_SERVICE_NAME=${CONSUL_SERVICE_NAME}"
[[ -n $CONSUL_SECRETS_DIR ]] || warning_msg "CONSUL_SECRETS_DIR is unset. If in Docker, this might cause issues with TLS."

[[ -n ${SAS_SECURE_FRAMEWORK} ]] || SAS_SECURE_FRAMEWORK=${SASCONFIG}/etc/SASSecurityCertificateFramework
debug_msg "SAS_SECURE_FRAMEWORK=${SAS_SECURE_FRAMEWORK}"
[[ -n ${SAS_ANCHORS_DIR} ]] || SAS_ANCHORS_DIR=${SAS_SECURE_FRAMEWORK}/cacerts
# This is not to be treated the same as it's default. In the Bareos world, they are the same. In Docker they are not!!!!
debug_msg SAS_ANCHORS_DIR=${SAS_ANCHORS_DIR}
[[ -n ${SAS_SERVICE_NAME} ]] || SAS_SERVICE_NAME=sas-consul
debug_msg "SAS_SERVICE_NAME=${SAS_SERVICE_NAME}"
[[ -n ${SAS_SERVICE_CONTEXT} ]] || SAS_SERVICE_CONTEXT=${SAS_SERVICE_NAME#sas-}
debug_msg "SAS_SERVICE_CONTEXT=${SAS_SERVICE_CONTEXT}"
[[ -n ${CONSUL_ACL_MASTER_TOKEN_FILE} ]] || CONSUL_ACL_MASTER_TOKEN_FILE="${SAS_SECURE_FRAMEWORK}/tokens/consul/default/management.token"
debug_msg "CONSUL_ACL_MASTER_TOKEN_FILE=${CONSUL_ACL_MASTER_TOKEN_FILE}"
[[ -n ${SAS_DEFAULT_TOKEN_DIR} ]] || SAS_DEFAULT_TOKEN_DIR=${SAS_SECURE_FRAMEWORK}/tokens
debug_msg "SAS_DEFAULT_TOKEN_DIR=${SAS_DEFAULT_TOKEN_DIR}"
[[ -n ${SAS_CONSUL_DEFAULT_TOKEN_DIR} ]] || SAS_CONSUL_DEFAULT_TOKEN_DIR=${SAS_DEFAULT_TOKEN_DIR}/consul/default
debug_msg "SAS_CONSUL_DEFAULT_TOKEN_DIR=${SAS_CONSUL_DEFAULT_TOKEN_DIR}"
[[ -n ${SAS_MANAGEMENT_TOKEN} ]] || SAS_MANAGEMENT_TOKEN=${SAS_CONSUL_DEFAULT_TOKEN_DIR}/management.token
debug_msg "SAS_MANAGEMENT_TOKEN=${SAS_MANAGEMENT_TOKEN}"
[[ -n ${SAS_ENCRYPTION_TOKEN} ]] || SAS_ENCRYPTION_TOKEN=${SAS_CONSUL_DEFAULT_TOKEN_DIR}/encryption.token
debug_msg "SAS_ENCRYPTION_TOKEN=${SAS_ENCRYPTION_TOKEN}"
[[ -n ${SAS_CLIENT_TOKEN} ]] || SAS_CLIENT_TOKEN=${SAS_CONSUL_DEFAULT_TOKEN_DIR}/client.token
debug_msg "SAS_CLIENT_TOKEN=${SAS_CLIENT_TOKEN}"
[[ -n ${CONSUL_TOKEN_FILE} ]] || CONSUL_TOKEN_FILE="${SAS_CONSUL_DEFAULT_TOKEN_DIR}/client.token"
debug_msg "CONSUL_TOKEN_FILE=${CONSUL_TOKEN_FILE}"
[[ -n ${CONSUL_VAULT_TOKEN_DIR} ]] || CONSUL_VAULT_TOKEN_DIR=${SAS_CONSUL_DEFAULT_TOKEN_DIR}
debug_msg "CONSUL_VAULT_TOKEN_DIR=${CONSUL_VAULT_TOKEN_DIR}"
[[ -n ${CONSUL_VAULT_TOKEN_FILE} ]] || CONSUL_VAULT_TOKEN_FILE=${CONSUL_VAULT_TOKEN_DIR}/vault.token
debug_msg "CONSUL_VAULT_TOKEN_FILE=${CONSUL_VAULT_TOKEN_FILE}"
[[ -n ${VAULT_ROOT_TOKEN_DIR} ]] || VAULT_ROOT_TOKEN_DIR=${SASCONFIG}/etc/vault/default
debug_msg "VAULT_ROOT_TOKEN_DIR=${VAULT_ROOT_TOKEN_DIR}"
[[ -n ${VAULT_ROOT_TOKEN_FILE} ]] || VAULT_ROOT_TOKEN_FILE=${VAULT_ROOT_TOKEN_DIR}/root_token
debug_msg "VAULT_ROOT_TOKEN_FILE=${VAULT_ROOT_TOKEN_FILE}"
[[ -n ${SAS_CA_BUNDLE} ]] || SAS_CA_BUNDLE=${SAS_SECURE_FRAMEWORK}/cacerts/trustedcerts.pem
debug_msg "SAS_CA_BUNDLE=${SAS_CA_BUNDLE}"
[[ -n ${SASUSER} ]] || SASUSER=sas
debug_msg "SASUSER=${SASUSER}"
[[ -n ${SASGROUP} ]] || SASGROUP=sas
debug_msg "SASGROUP=${SASGROUP}"
[[ -n ${SAS_CONSUL_SERVER_TLS_ROOT_DIR} ]] || SAS_CONSUL_SERVER_TLS_ROOT_DIR=${SAS_SECURE_FRAMEWORK}/tls/certs/consul
debug_msg "SAS_CONSUL_SERVER_TLS_ROOT_DIR=${SAS_CONSUL_SERVER_TLS_ROOT_DIR}"
[[ -n ${SAS_CONSUL_SERVER_TLS_DIR} ]] || SAS_CONSUL_SERVER_TLS_DIR=${SAS_CONSUL_SERVER_TLS_ROOT_DIR}/default
debug_msg "SAS_CONSUL_SERVER_TLS_DIR=${SAS_CONSUL_SERVER_TLS_DIR}"
[[ -n ${SAS_CONSUL_SERVER_PRI_ROOT_DIR} ]] || SAS_CONSUL_SERVER_PRI_ROOT_DIR=${SAS_SECURE_FRAMEWORK}/private/consul
debug_msg "SAS_CONSUL_SERVER_PRI_ROOT_DIR=${SAS_CONSUL_SERVER_PRI_ROOT_DIR}"
[[ -n ${SAS_CONSUL_SERVER_PRI_DIR} ]] || SAS_CONSUL_SERVER_PRI_DIR=${SAS_CONSUL_SERVER_PRI_ROOT_DIR}/default
debug_msg "SAS_CONSUL_SERVER_PRI_DIR=${SAS_CONSUL_SERVER_PRI_DIR}"
[[ -n ${SAS_CONSUL_SERVER_CRT} ]] || SAS_CONSUL_SERVER_CRT=${SAS_CONSUL_SERVER_TLS_DIR}/$(hostname).crt
debug_msg "SAS_CONSUL_SERVER_CRT=${SAS_CONSUL_SERVER_CRT}"
[[ -n ${SAS_CONSUL_SERVER_KEY} ]] || SAS_CONSUL_SERVER_KEY=${SAS_CONSUL_SERVER_PRI_DIR}/$(hostname).key
debug_msg "SAS_CONSUL_SERVER_KEY=${SAS_CONSUL_SERVER_KEY}"
[[ -n ${VAULT_SERVER_COUNT} ]] || VAULT_SERVER_COUNT="${CONSUL_BOOTSTRAP_EXPECT}"
debug_msg "VAULT_SERVER_COUNT=${VAULT_SERVER_COUNT}"
VAULT_CRT="${SAS_CONSUL_SERVER_TLS_DIR}/vault.crt"
VAULT_KEY="${SAS_CONSUL_SERVER_PRI_DIR}/vault.key"

# Set of functions for supporting docker containers
if [ -f ${SASHOME}/lib/envesntl/docker-functions ]; then
  source ${SASHOME}/lib/envesntl/docker-functions
fi

verbose_command(){
  ##execute the command and capture the output
  local output=$($*)
  rc=$?
  info_msg "${output}"
  return $rc
}

rebuild_local_sas_truststore(){ #This should only run in Docker. This function will rebuild truststores.
  #Ansible handles this in BareOS.
  info_msg "Rebuilding the local truststore."
  if [ -n "$SAS_ANCHORS_DIR" ] && [ -d "$SAS_ANCHORS_DIR" ] && [ "$SAS_ANCHORS_DIR" != "$SAS_SECURE_FRAMEWORK/cacerts" ]; then
    if [[ -n ${CACERTS_CONFIGMAP} ]]; then
       info_msg "Detected Kubernetes ConfigMap usage. Copying ConfigMap certs from ${SAS_ANCHORS_DIR}"
       copy_certs_from_configmap "${SAS_ANCHORS_DIR}"
    elif [ $(ls -1 ${SAS_ANCHORS_DIR}/*.crt | wc -l) -gt 0 ]; then
       cp -v $SAS_ANCHORS_DIR/*.crt $SAS_SECURE_FRAMEWORK/cacerts
    else
       info_msg "Anchors dir is empty."
    fi
  else
    warning_msg "No SAS_ANCHORS_DIR set. Or its not a directory.."
  fi
  info_msg "Running sas-merge-certificates.sh"
  ${SASHOME}/SASSecurityCertificateFramework/bin/sas-merge-certificates.sh ${SASHOME} ${SASCONFIG}
  info_msg "SASUSER: ${SASUSER}, SASGROUP: ${SASGROUP}"
}

is_cert_self_signed(){
  CONSUL_ADDR_NO_SCHEME=$(echo ${CONSUL_HTTP_ADDR} | awk '{split($0,a,"://")} END{print a[2]}')
  info_msg "Checking consul's certificate with openssl using -connect with \"${CONSUL_ADDR_NO_SCHEME}\" as the consul address"
  cert_as_text=$(openssl s_client -showcerts -connect ${CONSUL_ADDR_NO_SCHEME} < /dev/null)
  subject=$(echo "$cert_as_text" | grep subject= | sed "s#subject=.*/CN=##") #grep to find correct line then sed to make it only be the subject CN value.
  issuer=$(echo "$cert_as_text" | grep issuer= | sed "s#issuer=.*/CN=##")
  if [[ ${subject} != ${issuer} ]]; then
    info_msg "This is not a self signed certificate"
    return 1
  fi
  info_msg "This is a self-signed certificate. Returning 0"
  return 0
}

get_local_ip_address_list(){
  local ip_list=$(${SASHOME}/bin/sas-bootstrap-config network addresses --ipv4 --ipv6 --loopback | tr '\n' ',')
  ip_list=${ip_list%,}
  echo "${ip_list}"
}

get_vault_and_consul_address(){
#takes in a CONSUL_LIST/CONSUL_HTTP_ADDR or uses the env vars #returns the VAULT_ADDRESS and the CONSUL_HTTP_ADDR it found.
  (>&2 info_msg "This function is here to find a working vault and consul address. It utilizes the CONSUL_SERVER_LIST variable that needs to be in the env.")
  old_consul_addr=$CONSUL_HTTP_ADDR
  local IFS=","
  (>&2 info_msg "CONSUL_SERVER_LIST=\"${CONSUL_SERVER_LIST}\"")
  for entry in $CONSUL_SERVER_LIST
  do
    if [ "$entry" == "$(hostname -f)" ]; then
         (>&2 info_msg "Found myself in CONSUL_SERVER_LIST")
      : #continue
    elif [[ "$entry" =~ ^vault.*$ ]]; then
          (>&2 info_msg "Found Vault consul in CONSUL_SERVER_LIST")
      :
    else #this is a good consul address
      local CONSUL_IP=$(echo "${entry}" | cut -d: -f1)
      local CONSUL_HTTP_ADDR="https://${CONSUL_IP}:8501"
      export CONSUL_HTTP_ADDR
      (>&2 info_msg "CONSUL_HTTP_ADDR is ${CONSUL_HTTP_ADDR}")
      local VAULT_ADDR=""
      VAULT_ADDR=$(${SASHOME}/bin/sas-bootstrap-config catalog serviceurl --tag https vault)
      if [ $? -eq 0 ]; then
        echo "${VAULT_ADDR}|<VAULT_ADDR CONSUL_ADDR>|${CONSUL_HTTP_ADDR}"
        break
      fi
      unset CONSUL_HTTP_ADDR
      local VAULT_ADDR=""
    fi
  done
  export CONSUL_HTTP_ADDR=$old_consul_addr

}

create_consul_port_config_json(){
  if [[ $# -ne 1 ]]; then
    info_msg "mode not set. Defaulting to secured mode."
    mode="secured"
  else
    mode="$1"
    mode=$(echo $mode | tr '[:upper:]' '[:lower:]')
    info_msg "Creating our json in $mode configuration."
  fi
  info_msg "Moving the consul port configuration template file to the consul configuration directory."
  if [[ -f ${SASCONFIG}/etc/consul.d/config-tls.json ]]; then
    rm -f ${SASCONFIG}/etc/consul.d/config-tls.json #Remove the Viya3.3 TLS file.
  fi
  if [[ -f ${SASCONFIG}/etc/consul.d/config-consul-ports.json ]]; then
    rm -f ${SASCONFIG}/etc/consul.d/config-consul-ports.json #Remove any old version of the file we are about to create.
  fi

  copy_output=$(cp -v ${SASCONFIG}/etc/sas-consul/default/config-consul-ports.template ${SASCONFIG}/etc/consul.d/config-consul-ports.json)
  info_msg "${copy_output}"
  chown ${SASUSER}:${SASGROUP} ${SASCONFIG}/etc/consul.d/config-consul-ports.json
  chmod 600 ${SASCONFIG}/etc/consul.d/config-consul-ports.json

  if [[ $? -ne 0 ]]; then
    info_msg "Failed to move the template file to the configuration folder. Returning 1. "
    return 1
  fi
  if [[ $mode == "secured" ]]; then
    sed -i "s|{HTTPS_PORT}|8501|" ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    DISABLE_CONSUL_HTTP_PORT=$(echo ${DISABLE_CONSUL_HTTP_PORT} | tr '[:upper:]' '[:lower:]')
    if [[ ${DISABLE_CONSUL_HTTP_PORT} == true ]]; then
      sed -i "s|{HTTP_PORT}|-1|" ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    else
      sed -i "s|{HTTP_PORT}|8500|" ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    fi
    sed -i "s|{CA_BUNDLE}|${SAS_CA_BUNDLE}|" ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    sed -i "s|{CONSUL_CERT_FILE}|${SAS_CONSUL_SERVER_CRT}|" ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    sed -i "s|{CONSUL_KEY_FILE}|${SAS_CONSUL_SERVER_KEY}|" ${SASCONFIG}/etc/consul.d/config-consul-ports.json
  elif [[ $mode == "insecure" ]]; then
    sed -i "s|{HTTPS_PORT}|-1|" ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    sed -i "s|{HTTP_PORT}|8500|" ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    sed -i -r '/"ca_file".*/d' ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    sed -i -r '/"cert_file".*/d' ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    sed -i -r '/"key_file".*/d' ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    sed -i -r '/"tls_min_version".*/d' ${SASCONFIG}/etc/consul.d/config-consul-ports.json
    sed -i -r '/"verify_outgoing".*/d' ${SASCONFIG}/etc/consul.d/config-consul-ports.json
  else
    error_msg $LINENO "mode was incorrectly set. Mode was set to \"$mode\""
    info_msg "acceptable options for mode are [secured | insecure ]"
  fi
}

start_consul(){
  if [[ $# -ne 2 ]]; then
    error_msg $LINENO "Missing necessary parameters: tls_on and was_bootstrapping_consul in start_consul"
    return 1
  fi
  local tls_on=$1
  local was_bootstrapping_consul=$2

  ## Update Config Files
  export CONSUL_CONSULD_DIR=${CONSUL_CONSULD_DIR:-/opt/sas/viya/config/etc/consul.d}
  export CONSUL_GOSSIP=${CONSUL_GOSSIP:-${CONSUL_CONSULD_DIR}/config-gossip.json}
  export CONSUL_ACL=${CONSUL_ACL:-${CONSUL_CONSULD_DIR}/config-acl.json}
  export CONSUL_ACL_CREATE_CLIENT=${CONSUL_ACL_CREATE_CLIENT:-${CONSUL_CONSULD_DIR}/config-acl-create-client.json}
  export CONSUL_CONSULWATCHES=${CONSUL_ACL_CREATE_CLIENT:-${CONSUL_CONSULD_DIR}/config-consulwatches.json}

  if [[ ${tls_on} -eq 1 ]]; then
    info_msg "Determined that we are running Consul with TLS enabled."
    info_msg "Running the script to create our config-consul-ports.json file"
    create_consul_port_config_json secured
    if [[ $? -eq 1 ]]; then
      info_msg "Failed to create our consul port configuration file. Exiting with error."
      return 1
    fi
  fi

  if [[ -f "${CONSUL_GOSSIP}" ]]; then
    info_msg "setting our consul gossip token file $CONSUL_GOSSIP"
    sed -i -e "s/{GOSSIP_ENCRYPTION_KEY}/${GOSSIP_ENCRYPTION_KEY}/g" $CONSUL_GOSSIP
  fi

  if [[ -f "${CONSUL_ACL}" ]]; then
    info_msg "setting our consul acl file $CONSUL_ACL"
    sed -i -e "s/{CONSUL_ACL_MASTER_TOKEN}/${CONSUL_ACL_MASTER_TOKEN}/g" $CONSUL_ACL
  fi

  if [[ -f "${CONSUL_ACL_CREATE_CLIENT}" ]]; then
    info_msg "creating our consul client acl file $CONSUL_ACL_CREATE_CLIENT"
    sed -i -e "s/{CONSUL_TOKEN}/${CONSUL_TOKEN}/g" $CONSUL_ACL_CREATE_CLIENT
  fi

  if [[ -f "${CONSUL_CONSULWATCHES}" ]]; then
    info_msg "setting our service name with our service context in $CONSUL_CONSULWATCHES"
    sed -i -e "s/{SERVICE_NAME}/${SAS_SERVICE_CONTEXT}/g" $CONSUL_CONSULWATCHES
  fi

  export SAS_SERVICE_PID_DIR=/opt/sas/viya/config/var/run/${SAS_SERVICE_CONTEXT}
  export SAS_SERVICE_PID=${SAS_SERVICE_PID_DIR}/${SAS_SERVICE_NAME}.pid
  mkdir -pv ${SAS_SERVICE_PID_DIR}
  touch ${SAS_SERVICE_PID}

  info_msg "Starting Consul process"
  exec /opt/sas/viya/home/bin/${SAS_SERVICE_NAME} -p ${SAS_SERVICE_PID}
}

get_consul_public_cert_count(){
  if [[ -n $1 ]]; then
    local directory=$1
    (>&2 info_msg "Directory supplied as paramater: $directory ")
  elif [[ -n ${SAS_ANCHORS_DIR} ]]; then
    (>&2 info_msg "No directory supplied, but using SAS_ANCHORS_DIR env: $SAS_ANCHORS_DIR")
    local directory=${SAS_ANCHORS_DIR}
  else
    (>&2 error_msg $LINENO "No directory supplied to count consul self-signed certs. Returning.")
    return 1
  fi
  local consul_cert_count=$(ls $directory | grep -e "^consul" | wc -w)
  echo "$consul_cert_count"
} #take in directory, output the cert count.

get_san_dns_list(){
  local san_dns_list="--san-dns localhost"
  local common_name=$(hostname -f)
  if [[ $? -ne 0 ]]; then
    error_msg $LINENO "hostname -f returned a non-zero rc. This was the output of the command: ${common_name}. FQDN required."
    return 1
  else
    san_dns_list="${san_dns_list} --san-dns ${common_name}"
  fi
  local short_name=$(hostname -s)
  if [[ $? -ne 0 ]]; then
    warning_msg "hostname -s returned a non-zero rc. This was the output of the command: ${short_name}. Short name will not be added to certificate."
  else
    san_dns_list="${san_dns_list} --san-dns ${short_name}"
  fi
  local base_hostname=$(hostname)
  if [[ $? -ne 0 ]]; then
    error_msg $LINENO "hostname returned a non-zero rc. This was the output of the command: ${base_hostname}."
    return 2
  else
    san_dns_list="${san_dns_list} --san-dns ${base_hostname}"
  fi

  if [[ -n "${CONSUL_SERVICE_NAME}" ]]; then
    san_dns_list="${san_dns_list} --san-dns ${CONSUL_SERVICE_NAME}"
  fi
  echo "${san_dns_list}"
}

generate_self_signed_certificate(){
  if [[ -n $1 ]]; then
    local LOCAL_CERT_PATH=$1
  elif [[ -n  ${SAS_CONSUL_SERVER_CRT} ]]; then
    local LOCAL_CERT_PATH=${SAS_CONSUL_SERVER_CRT}
  else
    error_msg $LINENO "Path for local cert not specified"
    return 1
  fi

  if [[ -n $2 ]]; then
    local LOCAL_KEY_PATH=$2
  elif [[ -n  ${SAS_CONSUL_SERVER_KEY} ]]; then
    local LOCAL_KEY_PATH=${SAS_CONSUL_SERVER_KEY}
  else
    error_msg $LINENO "Path for local key not specified"
    return 2
  fi

  if [[ -n $3 ]]; then
    local anchors_dir=$3
  elif [[ -n ${SAS_ANCHORS_DIR} ]]; then
    local anchors_dir=${SAS_ANCHORS_DIR}
  else
    error_msg $LINENO "Path for anchors dir not specified"
    return 3
  fi
  #san-dns list
  local san_dns_list=$(get_san_dns_list)
  if [[ $? -ne 0 ]]; then
    error_msg $LINENO "Failed to get a valid san-dns list."
    return 4
  fi
  debug_msg "san_dns_list is ${san_dns_list}"
  local common_name=$(hostname -f)

  #san-ip list
  public_ip="$(get_local_ip_address_list)"
  old_ifs=$IFS
  IFS=','
  local holder=""
  for ip in $public_ip; do
    holder="${holder}--san-ip $ip "
  done
  IFS=$old_ifs

  san_ip="$holder --san-ip 0.0.0.0"

  debug_msg "san_ip list is ${san_ip}"
  info_msg "Writing self-signed key to ${LOCAL_KEY_PATH}"
  info_msg "Writing self-signed cert to ${LOCAL_CERT_PATH}"
  local LOCAL_KEY_PATH_DIR=$(dirname ${LOCAL_KEY_PATH})
  local LOCAL_CERT_PATH_DIR=$(dirname ${LOCAL_CERT_PATH})
  mkdir -pv ${LOCAL_KEY_PATH_DIR} ${LOCAL_CERT_PATH_DIR}
  chown ${SASUSER}:${SASGROUP} ${LOCAL_KEY_PATH_DIR} ${LOCAL_CERT_PATH_DIR}
  [ -e ${LOCAL_KEY_PATH} ] && rm ${LOCAL_KEY_PATH}
  [ -e ${LOCAL_CERT_PATH_DIR}/server.csr ] && rm ${LOCAL_CERT_PATH_DIR}/server.csr
  [ -e ${LOCAL_CERT_PATH} ] && rm ${LOCAL_CERT_PATH}
  ${SAS_CRYPTO_MANAGEMENT} genkey --out-file ${LOCAL_KEY_PATH}
  ${SAS_CRYPTO_MANAGEMENT} gencsr --out-file ${LOCAL_CERT_PATH_DIR}/server.csr --key ${LOCAL_KEY_PATH} --subject CN=$common_name $san_dns_list $san_ip
  ${SAS_CRYPTO_MANAGEMENT} selfsign --out-file ${LOCAL_CERT_PATH} --signing-key ${LOCAL_KEY_PATH} --csr ${LOCAL_CERT_PATH_DIR}/server.csr --ext-key-usage KeyEncipherment --ext-key-usage TLSWebServerAuthentication --ext-key-usage TLS Web Client Authentication
  if [[ ! -f ${LOCAL_CERT_PATH} ]]; then
   error_msg $LINENO "NO CERT FILE WRITTEN"
    return 6
  fi
  if [[ ! -f ${LOCAL_KEY_PATH} ]]; then
    error_msg $LINENO "NO KEY FILE WRITTEN"
    return 7
  fi
  chmod 644 ${LOCAL_CERT_PATH}
  chmod 600 ${LOCAL_KEY_PATH}
  chown ${SASUSER}:${SASGROUP} ${LOCAL_CERT_PATH}
  chown ${SASUSER}:${SASGROUP} ${LOCAL_KEY_PATH}
  rm ${LOCAL_CERT_PATH_DIR}/server.csr
}

generate_vault_certificate(){
  if [[ $# -ne 1 ]]; then
    if [[ -z ${VAULT_ADDR} ]]; then
      error_msg $LINENO "No Vault address was provided. Using ${VAULT_ADDR}"
      return 1
    fi
  else
    local VAULT_ADDR=$1
  fi
  info_msg "VAULT_ADDR is ${VAULT_ADDR}"
  local ip_list=$(get_local_ip_address_list)
  ip_list="$ip_list,0.0.0.0"
  info_msg "Making directories for the certs if it doesnt already exist"
  mkdir_output=$(mkdir -pv ${SAS_CONSUL_SERVER_PRI_DIR} ${SAS_CONSUL_SERVER_TLS_DIR})
  chown -R ${SASUSER}:${SASGROUP} ${SAS_CONSUL_SERVER_PRI_ROOT_DIR} ${SAS_CONSUL_SERVER_TLS_ROOT_DIR}
  info_msg ${mkdir_output}

  vault_cafile="$(get_vault_ca_file)"
  if [[ $? -ne 0 ]]; then
    error_msg $LINENO "Failed to find the vault ca in ${SAS_ANCHORS_DIR}"
    return 2
  fi

  #san-dns list
  local san_dns_list=$(get_san_dns_list)
  if [[ $? -ne 0 ]]; then
    error_msg $LINENO "Failed to get a valid san-dns list."
    return 3
  fi
  local common_name=$(hostname -f)
  debug_msg "san_dns_list is ${san_dns_list}"

  local total_time_waited=0
  local notify_backoff=5
  while true; do
    if [[ "${total_time_waited}" -ge 900 ]]; then
        info_msg "Spent 15 minutes trying to get a vault certificate."
        info_msg "Exiting with a failure."
        return 4
    fi
    sleep 5s
    let "total_time_waited = total_time_waited + 5"
    if [[ ${total_time_waited} -ge ${notify_backoff} ]]; then
      let "notify_backoff=notify_backoff*2"
      info_msg "Attempting to generate vault certificate at vault address: ${VAULT_ADDR}"
      info_msg "Running SAS_CRYPTO_MANAGEMENT command: "
      echo "${SAS_CRYPTO_MANAGEMENT} --log-level=debug req-vault-cert \
      --common-name ${common_name} --san-ip ${ip_list} \
      ${san_dns_list} \
      --vault-cafile \"${vault_cafile}\"  --vault-token \"${CONSUL_VAULT_TOKEN_FILE}\" \
      --out-crt ${VAULT_CRT} --out-form \"pem\" \
      --out-key ${VAULT_KEY} \
      --vault-addr=${VAULT_ADDR}"
      info_msg "Total time waited so far=${total_time_waited} seconds. Still trying to acquire a vault certificate"
    fi

    ${SAS_CRYPTO_MANAGEMENT} --log-level=debug req-vault-cert \
    --common-name ${common_name} --san-ip ${ip_list} \
    ${san_dns_list} \
    --vault-cafile "${vault_cafile}" --vault-token "${CONSUL_VAULT_TOKEN_FILE}" \
    --out-crt ${VAULT_CRT} --out-form "pem" \
    --out-key ${VAULT_KEY} \
    --vault-addr=${VAULT_ADDR}
    RESULT=$?

    if [[ "${RESULT}" -eq 0 ]]; then
        info_msg "The generate_vault_certificate function finished with success after ${total_time_waited} seconds."
        break
    fi
  done

  if [[ ! -s ${VAULT_KEY} ]] || [[ ! -s ${VAULT_CRT} ]]; then # -s tests that the file exists and has a size greater than 0.
      error_msg $LINENO "Failed to write Vault cert or key"
      return 1
  fi
  chown ${SASUSER}:${SASGROUP} ${VAULT_CRT} ${VAULT_KEY}
  chmod 644 ${VAULT_CRT}
  chmod 600 ${VAULT_KEY}
  return 0
}

check_vaults_for_https(){
  local count=0
  local total_time_waited=0
  local notify_backoff=5
  if [[ -z ${CONSUL_HTTP_ADDR} ]]; then
    error_msg $LINENO "CONSUL_HTTP_ADDR is not set."
    return 1
  fi
  export CONSUL_HTTP_ADDR
  local catalog_result=1
  while [[ $catalog_result -ne 0 ]]; do
    VAULT_CATALOG=$(/opt/sas/viya/home/bin/sas-bootstrap-config --output json catalog service vault | tr '\n' '|' | sed 's/|/\\n/g')
    SERVICE_ID_LIST=$(python - <<END
import os, json, sys
json_input=json.loads('$VAULT_CATALOG')
vault_server_count=$VAULT_SERVER_COUNT

https=0
#adjust the number of https Vault instances if none are registered as active.
foundactive=-1
if json_input['items'] is None:
#no vault instance(s) registered. try again.
    exit(1)
for x in json_input['items']:
    print (x['serviceID'])
    if "https" in x['serviceTags']:
        https+=1
    if "active" in x['serviceTags']:
        foundactive=0
if https != vault_server_count:
    exit(2)
if foundactive == -1:
    exit(3)
exit(0)
END
)
    catalog_result=$?
    debug_msg "catalog result: $catalog_result"
    if [[ $catalog_result -eq 3 ]]; then
      info_msg "All vaults are https, waiting for one to become active."
    fi
    if [[ "${total_time_waited}" -ge 900 ]]; then
      error_msg $LINENO "Waited 15 minutes for all vaults to be https. Check vault logs on each instance for additional information."
      return 1
    fi
    sleep 5s
    let "total_time_waited = total_time_waited + 5"
    if [[ ${total_time_waited} -ge ${notify_backoff} ]]; then
      let "notify_backoff=notify_backoff*2"
      info_msg "Total time waited so far=${total_time_waited} seconds. Waiting for every vault server to have an https tags in consul"
      info_msg "Here is the list of vault's registered in consul: ${SERVICE_ID_LIST}"
    fi
  done
  info_msg "All vaults are https and one is active."
  return 0
}

check_vault_count(){
  local count
  local notify_backoff=5
  local total_time_waited
  if [[ -z ${CONSUL_HTTP_ADDR} ]]; then
    error_msg $LINENO "CONSUL_HTTP_ADDR is not set."
    return 1
  fi
  export CONSUL_HTTP_ADDR
  while true; do
    VAULT_CATALOG=$(/opt/sas/viya/home/bin/sas-bootstrap-config --output json catalog service vault | tr '\n' '|' | sed 's/|/\\n/g')
    count=$(python - <<END
import os, json, sys
json_input=json.loads('$VAULT_CATALOG')

if json_input['items'] is None:
    print ( 0 )
    exit(0)
print ( len(json_input['items']) )
END
)
    sleep 5s
    let "total_time_waited = total_time_waited + 5"
    if [[ "${total_time_waited}" -ge "${notify_backoff}" ]]; then
      let "notify_backoff=notify_backoff*2"
      info_msg "Count is: $count. Waiting for count to be 0"
      info_msg "Total time waited so far=${total_time_waited} seconds. Still waiting for all vault instances to deregister from consul."
    fi
    if [[ $count -eq 0 ]]; then break; fi
    if [[ "${total_time_waited}" -ge 900 ]]; then
      error_msg $LINENO "Waited 15 minutes for all vaults to deregister from consul. Check vault logs on each instance for additional information."
      return 1
    fi
  done
}

get_vault_ca_file(){
  tries=0
  vault_cafile=""
  while [[ ${vault_cafile} == "" ]]; do
    if [[ ${tries} -ge 60 ]]; then
      error_msg $LINENO "NO VAULT CA found in ${SAS_ANCHORS_DIR}."
      error_msg $LINENO "Waited 5 minutes for it to appear after Vault placed https tag in consul."
      return 2
    fi
    let "tries=tries+1"
    sleep 5s
    vault_cafile=$(ls ${SAS_ANCHORS_DIR}/vault*.crt | head -1)
  done

  if [[ -n ${CACERTS_CONFIGMAP} ]]; then
    cat $vault_cafile | base64 -di > $SAS_SECURE_FRAMEWORK/cacerts/$(basename $vault_cafile)
    echo $SAS_SECURE_FRAMEWORK/cacerts/$(basename $vault_cafile)
  else
    echo $vault_cafile #return the answer as text.
  fi
}

remove_consul_security_artifacts(){
  ${SAS_BOOTSTRAP_CONFIG} --token-file ${CONSUL_TOKEN_FILE} kv delete ${VAULT_CERT_LIST_PATH}
  if [[ $? -ne 0 ]]; then
    error_msg $LINENO "Failed to remove certificate state from Consul k/v store."
  fi
  rm -f ${CONSUL_VAULT_TOKEN_FILE}
  rm -rf ${SAS_CONSUL_SERVER_PRI_ROOT_DIR}
  rm -rf ${SAS_CONSUL_SERVER_TLS_ROOT_DIR}
}

function remove_viya33_certs(){
  #During the UIP, make sure that the old cert is deleted.

  if [[ -f "${SAS_CONSUL_SERVER_PRI_DIR}/consul.key" ]]; then
    info_msg "Removing the Viya3.3 key."
    verbose_command rm -v ${SAS_CONSUL_SERVER_PRI_DIR}/consul.key
  fi

  if [[ -f "${SAS_CONSUL_SERVER_TLS_DIR}/consul.pem" ]]; then
    info_msg "Removing the Viya3.3 cert."
    verbose_command rm -v ${SAS_CONSUL_SERVER_TLS_DIR}/consul.pem
  fi
}

