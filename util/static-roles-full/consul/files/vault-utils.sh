#!/bin/bash
# vault-utils.sh
echo "Sourcing other environment variables from /etc/sysconfig/sas/sas-viya-vault-default"
. /etc/sysconfig/sas/sas-viya-vault-default
log_msg()
{
  [ "$MYNAME" == "" ] && MYNAME=$(basename $0)
  local timestamp=`date "+%Y/%m/%d %T.%6N"`
  echo $timestamp $MYNAME "$*"
  if [ -n "$MY_LOG_FILE" ]; then
  {
    echo $timestamp "$*" >> $MY_LOG_FILE
  }
  fi
}

debug_msg()
{
  if [ -n "$DEBUG" ] && [ $DEBUG -gt 0 ]; then
  {
    local timestamp=`date "+%Y/%m/%d %T.%6N"`
    [ "$MYNAME" == "" ] && MYNAME=$(basename $0)
    echo $timestamp '(debug)' $MYNAME "$*"
    if [ -n "$MY_LOG_FILE" ]; then
    {
      echo $timestamp '(debug)' "$*" >> $MY_LOG_FILE
    }
    fi
  }
  fi
}

err_msg()
{
  local timestamp=`date "+%Y/%m/%d %T.%6N"`
  [ "$MYNAME" == "" ] && MYNAME=$(basename $0)
  echo $timestamp '(error)' $MYNAME "$*" >&2
  if [ -n "$MY_LOG_FILE" ]; then
  {
    echo $timestamp '(error)' "$*" >> $MY_LOG_FILE
  }
  fi
}

local_vault_addr () {
  [ -n "$SAS_VAULT_CONFDIR" ] || SAS_VAULT_CONFDIR=/opt/sas/viya/config/etc/vault/default
  VAULT_TLS=$(sed -n '/listener "tcp" {/,/}/p' $SAS_VAULT_CONFDIR/vault.hcl | grep -v "^[[:space:]]*//" | grep tls_disable | cut -d "=" -f 2 | tr -d \ )
  if [ "$VAULT_TLS" == "" -o "$VAULT_TLS" == "0" ]
  then
    VAULT_SCHEME=https
  else
    VAULT_SCHEME=http
  fi
  VAULT_PORT=$(sed -n '/listener "tcp" {/,/}/p' $SAS_VAULT_CONFDIR/vault.hcl | grep 'address' | cut -d ":" -f 2 | tr -d \")
  echo "${VAULT_SCHEME}://127.0.0.1:${VAULT_PORT}"
}

wait_vault_unsealed () {
  local is_self
  local leader_address
  local leader_ip
  local my_ip
  local is_actually_self
  log_msg "INFO: Asking Vault who is the leader:"
  while [ true ]
  do
    local curl_out=$(curl -s -k1 $(local_vault_addr)/v1/sys/leader)
    read is_self leader_address <<< $(echo "$curl_out" | python -c "import sys, json; holder = json.load(sys.stdin); print (holder['is_self']);print (holder['leader_address'])")
    log_msg "This was the output of that curl: $curl_out"
    if [ "$leader_address" == "" ]
    then
      log_msg "INFO: Vault reported that a leader has not been elected yet. Waiting 5 seconds for election."
      sleep 5s
    elif [ "$is_self" == "False" ]
    then
      is_actually_self="false"
      leader_ip=$(echo $leader_address | sed "s#http[s]*://\([^:/]*\).*#\1#")
      log_msg "INFO: Vault reported that this instance is not the leader."
      log_msg "INFO: Vault reported leader is at instance with ip: $leader_ip."

      ipList="$(${SASHOME}/bin/sas-bootstrap-config network addresses --loopback --ipv4 --ipv6) $(hostname -f)"
      for my_ip in $ipList
      do
        if [ "$my_ip" == "$leader_ip" ]
        then
          is_actually_self="true"
          break
        fi
      done
      if [ "$is_actually_self" == "true" ]
      then
        log_msg "INFO: This instance is running on the ip of the leader."
        log_msg "INFO: Sleeping 5s to let Vault resolve this confusion."
        sleep 5s
      else # "$is_self" == "False" -a "$is_actually_self" == "false"
        break # goes to "We do not need to wait for Vault to unseal"

      fi
    else # "$is_self" = "True"
      break # goes to "$is_self" == "True"
    fi
  done

  if [ "$is_self" == "True" ]
  then
    log_msg "Vault reported that we are the leader,"
    log_msg "Waiting for local vault to be healthy at $(local_vault_addr)"
    VAULT_STATUS=0
    while [ "${VAULT_STATUS}" != "200" ] # 200 for active
    do
      sleep 5s
      VAULT_STATUS=$(curl -s -o /dev/null -k1 -I -w "%{http_code}" $(local_vault_addr)/v1/sys/health)
    done
  else
    log_msg "We do not need to wait for Vault to unseal."
  fi
}

# function which parses out a PEM format object
# parameter 1 is the raw result
# parameter 2 is the label for the first object.
# parameter 3(optional) is the label for the second object.
# object 1 is printed to sdtout, object 2 is printed to stderr
parse_for() {
  found=0
  while read -r line
  do
    if [ $found -eq 0 ]
    then
      if [ "$(grep -wF "$2" <<< "$line" )" != "" ]
      then
        found=1
        sed "s/$2\s*//" <<< "$line"
      elif [ "$3" != "" -a "$(grep -wF "$3" <<< "$line")" != "" ]
      then
        found=2
        >&$found sed "s/$3\s*//" <<< "$line"
      fi
    else
      >&$found echo "$line"
      if [ "$(grep -F "-" <<< "$line" )" != "" ] ; then
        found=0
      fi
    fi
  done <<< "$1"
  unset found
}

# need SASHOME VAULT_CONFIG_DIR SAS_CRT
issue_vault_cert() {
  if [ $# -eq 5 ]; then
    SASHOME=$1
    VAULT_SHARED_SECRETS_DIR=$2
    VAULT_CONFIG_DIR=$3
    SAS_CRT=$4
    VAULT_SERVICE_NAME=$5
  elif [ "$SAS_CRT" == "" -o "$VAULT_CONFIG_DIR" == "" -o "$VAULT_SHARED_SECRETS_DIR" == "" -o "$SASHOME" == "" ]
  then
    log_msg "Usage: issue_vault_cert \$SASHOME \$VAULT_CONFIG_DIR \$VAULT_SHARED_SECRETS_DIR \$SAS_CRT"
    return 1
  fi
  log_msg "INFO: Using SASHOME=$SASHOME VAULT_CONFIG_DIR=$VAULT_CONFIG_DIR VAULT_SHARED_SECRETS_DIR=$VAULT_SHARED_SECRETS_DIR SAS_CRT=$SAS_CRT"

  # if on linux, get list of ip addresses on all interfaces
  ipList=$(echo $(${SASHOME}/bin/sas-bootstrap-config network addresses --loopback --ipv4 --ipv6) | tr -s ' ' ',')
  if [ -n "$SAS_VAULT_PKI_IPSUBJECTALTNAMES" ]
  then
    ipList="${ipList},$SAS_VAULT_PKI_IPSUBJECTALTNAMES"
  fi

  if [ -n "$VAULT_HOSTNAME" ]
  then
    commonname=$VAULT_HOSTNAME
  else
    commonname=$(hostname -f)
  fi

  NAMELIST=$(echo $commonname | sed "s/\([^\.]*\)\(.*\)/\\1,\\1\\2/"),localhost,${VAULT_SERVICE_NAME}
  if [ -n "$SAS_VAULT_PKI_SUBJECTALTNAMES" ]
  then
    NAMELIST="$NAMELIST,$SAS_VAULT_PKI_SUBJECTALTNAMES"
  fi

  debug_msg "ipList=\"$ipList\""
  debug_msg "NAMELIST=\"$NAMELIST\""
  # generate new private key, and certificate for vault.
  ${SASHOME}/SASSecurityCertificateFramework/bin/sas-crypto-management req-vault-cert --vault-addr ${VAULT_ADDR} --vault-token ${VAULT_SHARED_SECRETS_DIR}/root_token \
    --vault-cafile ${VAULT_CONFIG_DIR}../../SASSecurityCertificateFramework/cacerts/trustedcerts.pem --common-name "vault.$commonname" \
    --san-ip "${ipList}" --san-dns "$NAMELIST" --out-key ${VAULT_CONFIG_DIR}/vault.key --out-crt ${VAULT_CONFIG_DIR}/vault.crt
  if [ $? -ne 0 ]
  then
    log_msg "error issuing vault certificate" >&2
    return 1
  fi
  # make a bundle of the server, intermediate, and root certs (required by vault)
  cat ${VAULT_CONFIG_DIR}/vault.crt ${SAS_CRT} > ${VAULT_CONFIG_DIR}/vault-bundle.crt
  chown ${SASUSER}:${SASGROUP} ${VAULT_CONFIG_DIR}/vault-bundle.crt ${VAULT_CONFIG_DIR}/vault.key ${VAULT_CONFIG_DIR}/vault.crt
}
# rc 0 means we found our serviceID registered in the consul catalog.
#   if this happens the node we are registered on is printed to stdout.
# rc1 means that our serviceID is not registered.
get_registered_consul_node_for_vault(){
  if [ $# -lt 1 ]; then
    err_msg "missing parameter. Usage: ${FUNCTION[0]} service_id" >&2
    return 1
  fi
  service_id=$1
  VAULT_CATALOG=$(/opt/sas/viya/home/bin/sas-bootstrap-config --output json catalog service vault)
  echo "${VAULT_CATALOG}" | python -c "import sys, json;
json_input=json.load(sys.stdin)
for x in json_input['items']:
    if \"$service_id\" == x['serviceID']:
        print (x['address'])
        exit (0)
exit(1)
"
}

deregister_vault(){
  our_hostname=$(hostname -f)
  service_id=vault:${our_hostname}:8200
  while true; do
    consul_address=$(get_registered_consul_node_for_vault $service_id)
    [[ $? -ne 0 ]] && break
    CONSUL_HTTP_ADDR_NO_HTTPS=${CONSUL_HTTP_ADDR#https://}
    CONSUL_HTTP_ADDR_NO_HTTP=${CONSUL_HTTP_ADDR#http://}
    if [[ ${CONSUL_HTTP_ADDR} != ${CONSUL_HTTP_ADDR_NO_HTTPS} ]]; then
      #was https
      CONSUL_ADDR_NO_SCHEME=${CONSUL_HTTP_ADDR_NO_HTTPS}
      CONSUL_SCHEME="https"
    elif [[ ${CONSUL_HTTP_ADDR} != ${CONSUL_HTTP_ADDR_NO_HTTP} ]]; then
      #was http
      CONSUL_ADDR_NO_SCHEME=${CONSUL_HTTP_ADDR_NO_HTTP}
      CONSUL_SCHEME="http"
    fi
    CONSUL_PORT=${CONSUL_HTTP_ADDR##*:} #TO-Do Make this more resilient
    CONSUL_ADDRESS=${CONSUL_SCHEME}://${consul_address}:${CONSUL_PORT}

    echo "Attempting to deregister ${service_id} from node: ${CONSUL_ADDRESS}"
    local OLD_CONSUL_ADDR=$CONSUL_HTTP_ADDR
    export CONSUL_HTTP_ADDR=$CONSUL_ADDRESS
    export CONSUL_HTTP_TOKEN=$(cat /opt/sas/viya/config/etc/SASSecurityCertificateFramework/tokens/consul/default/client.token)
    /opt/sas/viya/home/bin/sas-bootstrap-config agent service deregister $service_id
    export CONSUL_HTTP_ADDR=$OLD_CONSUL_ADDR
    echo "Return code was $?"
  done
}

