#!/bin/bash

echo "Bringing in some logging functions, consul utility functions, env vars, and CONSUL_HTTP_ADDR"
SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
. "${SCRIPTPATH}/basic_logging.sh"
. /etc/sysconfig/sas/sas-viya-consul-default
. "${SCRIPTPATH}/consul-utils.sh"
. ${SASCONFIG}/consul.conf
# explicitly add /sbin etc. to PATH since some sites change the default sudoers "secure_path"
PATH=/sbin:/usr/sbin:/bin:/usr/bin:$PATH

function delete_consul_self_signed_cacerts_from_machine(){
  debug_msg "RUNNING_IN_DOCKER=$RUNNING_IN_DOCKER"
  if [[ ${RUNNING_IN_DOCKER} == "true" ]]; then
    if [[ -n ${CACERTS_CONFIGMAP} ]]; then
      info_msg "Detected Kubernetes ConfigMap usage. Removing this server's cert from ${CACERTS_CONFIGMAP}"
      info_msg "Must wait until all servers are in the quorum before removing this server's cert from the ConfigMap."
      export CONSUL_HTTP_TOKEN=${CONSUL_TOKENS_MANAGEMENT}
      while [ $(${SASHOME}/bin/consul operator raft list-peers|grep -i consul|wc -l) -ne ${CONSUL_BOOTSTRAP_EXPECT} ]; do
        sleep 5s
      done
      info_msg "All servers are in quorum. Continuing."

      remove_key_from_configmap "${CACERTS_CONFIGMAP}" "consul-$(hostname -s).crt"
      if [ $? -ne 0 ]; then
        error_msg $LINENO "Failed to remove this server's cert from ${CACERTS_CONFIGMAP}. Exiting."
        exit 1
      fi
      info_msg "Successfully deleted this server's cert from ${CACERTS_CONFIGMAP}"
    else
      remove_output=$(rm -v ${SAS_ANCHORS_DIR}/consul-$(hostname -s).crt) #dealing with a shared volume. only delete your certificate.
      info_msg "${remove_output}"
    fi
  else
    info_msg "Not running in Docker, removing all consul-*.crt certs from ${SAS_ANCHORS_DIR}"
    remove_output=$(rm -v ${SAS_ANCHORS_DIR}/consul-*.crt)
    info_msg "${remove_output}"
  fi
}

#exit conditions
#if any of these conditions are not met, consul will not be killed.
if [[ -z ${CONSUL_BOOTSTRAP_EXPECT} ]]; then
  error_msg $LINENO "CONSUL_BOOTSTRAP_EXPECT is not set. Exiting 1"
  exit 1
fi

debug_msg $LINENO "CONSUL_SERVER_FLAG=${CONSUL_SERVER_FLAG}"
if [[ ${CONSUL_SERVER_FLAG} == "" ]] || [[ ${CONSUL_SERVER_FLAG} == "false" ]]; then
  info_msg "CONSUL AGENT SHOULD NOT USE KILL HELPER."
  exit 0
fi

CONSUL_PID=$(pidof consul)

if [[ ! -f ${CONSUL_TOKEN_FILE} ]]; then
  error_msg $LINENO "No consul client token file found at ${CONSUL_TOKEN_FILE}."
  kill -SIGTERM $CONSUL_PID
  exit 1
fi

export CONSUL_HTTP_TOKEN=$(cat ${CONSUL_TOKEN_FILE})
${SAS_BOOTSTRAP_CONFIG} status leader --wait --timeout-seconds 300 2>/dev/null
if [[ $? -ne 0 ]]; then
  error_msg $LINENO "Spent 5 minutes waiting for consul to form quorum. Check the sas_consul log for more information."
  exit 1
fi
info_msg "sas-bootstrap-config returned a leader"

SECURE_CONSUL=$(echo $SECURE_CONSUL | tr '[:upper:]' '[:lower:]')
if [[ ${SECURE_CONSUL} == "false" ]]; then
  info_msg "SECURE_CONSUL was false"
  info_msg "Not killing consul because it is not going to get a vault cert. Deleting all consul related certificates from this machine."
  delete_consul_self_signed_cacerts_from_machine #verify no consul specific self signed certificates are left on the machine
  info_msg "Removing our name if it exists from the ${VAULT_CERT_LIST_PATH} in consul"
  export CONSUL_HTTP_TOKEN=$(cat ${CONSUL_TOKEN_FILE})
  ${SASHOME}/bin/consul lock ${CONSUL_LOCK_PATH} ${SASHOME}/bin/remove_hostname_from_has_vault_cert.sh
  info_msg "Exiting"
  exit 0
fi

info_msg "Test for a self-signed certificate. We will replace a self-signed certificate with a new certificate from vault."
is_cert_self_signed
if [[ $? -ne 0 ]]; then
  info_msg "Kill helper has detected we are at steady state. We already have a vault certificate."
  info_msg "Waiting to get the lock: $CONSUL_LOCK_PATH to write that we have our cert"
  export CONSUL_HTTP_TOKEN=$(cat ${CONSUL_TOKEN_FILE})
  ${SASHOME}/bin/consul lock ${CONSUL_LOCK_PATH} ${SASHOME}/bin/write_has_vault_cert.sh
  if [[ $? -ne 0 ]]; then
    error_msg $LINENO "Failed to write that we have a certificate. This will cause errors in a deployment with more than one consul server."
    exit 1
  fi
  info_msg "We need to delete all self-signed certificates from this machine."
  delete_consul_self_signed_cacerts_from_machine
  info_msg "Exiting 0."
  exit 0
fi

###MAIN ROUTINE#############
#wait for Vault to say it has certificates
info_msg "Waiting for all vault instances to have certs."
check_vaults_for_https
if [[ $? -ne 0 ]]; then
  error_msg "Not all vaults registered as https within 15 minutes. Check the vault logs for information."
  exit 1
fi
info_msg "All vaults have registered as https"
info_msg "Using bootstrap config to get a serviceurl for vault."
#wait for vault to be ready to service requests.
VAULT_ADDR=$(${SASHOME}/bin/sas-bootstrap-config catalog serviceurl --wait --timeout-seconds 900 --tag https vault)
rc=$?
if [[ $rc -eq 79 ]]; then
  error_msg $LINENO "Waited 15 minutes to get a serviceurl for vault. Check the vault log for more information."
  exit 1
elif [[ $rc -ne 0 ]]; then
  error_msg $LINENO "sas-bootstrap-config had an error finding vault. Exiting with error."
  error_msg $LINENO "Try running: \"${SASHOME}/bin/sas-bootstrap-config catalog serviceurl --tag https vault\" manually."
  exit 1
fi
if [[ "$VAULT_ADDR" == "" ]]; then
  error_msg $LINENO "sas-bootstrap-config returned zero, but the vault address was blank. Exiting 1."
  exit 1
fi
info_msg "Found Vault:${VAULT_ADDR}"
info_msg "Trying to find vault root token."
notify_backoff=1
i=0
while [[ ! -f ${VAULT_ROOT_TOKEN_FILE} ]]; do
  if [[ $i -ge 900 ]]; then
    error_msg $LINENO "Waited for 15 minutes for a vault root token to appear -- after waiting for all the Vault instances to have an https tag."
    exit 1
  fi
  let "i=i+1"
  sleep 1s;
  if [[ $i -ge $notify_backoff ]]; then
    let "notify_backoff=2*notify_backoff"
    info_msg "Still waiting for vault token at ${VAULT_ROOT_TOKEN_FILE}."
  fi
done
info_msg "Found vault token after $i seconds."


if [[ ! -d ${SASCONFIG}/etc/SASSecurityCertificateFramework/tokens/consul/default/ ]]; then
  info_msg "Making a directory to house the consul service token"
  mkdir_output="$(mkdir -pv ${SASCONFIG}/etc/SASSecurityCertificateFramework/tokens/consul/default/)"
  info_msg "${mkdir_output}"
  chown -R ${SASUSER}:${SASGROUP} ${SASCONFIG}/etc/SASSecurityCertificateFramework/tokens/consul/
fi

vault_cafile="$(get_vault_ca_file)"
if [[ $? -ne 0 ]]; then
  error_msg $LINENO "Failed to find the vault ca in ${SAS_ANCHORS_DIR}"
  exit 2
fi

info_msg "Using the vault root token to generate a consul service token"
info_msg "Waiting for a 200 response from vault's policy backend."
curl_result="404"
total_time_waited=0
while [[ "${curl_result}" != "200" ]]; do
  #sas-bootstrap-config appends trailing slash to address.
  if [[ $total_time_waited -ge 300 ]]; then
    error_msg $LINENO "Waited for vault to be ready to service tokens for 5 minutes."
    error_msg $LINENO "Run a curl command to the /v1/sys/policy vault backend manually and verify that it works."
    exit 1
  fi
  curl_result=$(curl -K- -s -o /dev/null -1 --cacert ${vault_cafile} -w "%{http_code}" ${VAULT_ADDR}v1/sys/policy <<< "header=\"X-Vault-Token: $(cat ${VAULT_ROOT_TOKEN_FILE})\"")
  sleep 5s
  let "total_time_waited=total_time_waited+5"
done
info_msg "Waited for $total_time_waited seconds for Vault to be ready to service tokens."

${SASHOME}/SASSecurityCertificateFramework/bin/sas-crypto-management new-sec-token --appName consul --out-file ${CONSUL_VAULT_TOKEN_FILE} --root-token ${VAULT_ROOT_TOKEN_FILE} --service-root-token ${SASCONFIG}/etc/vault/default/service_root_token --vault-cafile ${vault_cafile} --vault-addr ${VAULT_ADDR}
if [[ $? -ne 0 ]]; then
  error_msg $LINENO "Failed to generate a vault token. Exiting 3."
  exit 3
fi
chown ${SASUSER}:${SASGROUP} ${CONSUL_VAULT_TOKEN_FILE} ${SASCONFIG}/etc/vault/default/service_root_token
chmod 600 ${CONSUL_VAULT_TOKEN_FILE} ${SASCONFIG}/etc/vault/default/service_root_token
info_msg "vault token acquired successfully."

generate_vault_certificate $VAULT_ADDR
RESULT=$?
if [[ "${RESULT}" -eq 1 ]]; then
    error_msg $LINENO "Failed to generate a vault certificate because VAULT_ADDR is blank (${VAULT_ADDR}). Exiting with failure"
    exit 4
fi
if [[ "${RESULT}" -eq 2 ]]; then
    error_msg $LINENO "Failed to generate a vault certificate because there was no vault ca found in our cacert folder."
    exit 5
fi
if [[ "${RESULT}" -eq 3 ]]; then
    error_msg $LINENO "Timed out attempting to get a vault cert."
    exit 6
fi

if [[ ! -f ${VAULT_KEY} ]] || [[ ! -f ${VAULT_CRT} ]]; then
  error_msg "Failed to write Vault cert or key to vault key: \"${VAULT_KEY}\" and vault cert to \"${VAULT_CRT}\". Exiting 1"
  exit 7
fi

chown ${SASUSER}:${SASGROUP} "${VAULT_KEY}" "${VAULT_CRT}"
chmod 600 "${VAULT_KEY}"
chmod 644 "${VAULT_CRT}"
move_msg=$(mv -v ${VAULT_CRT} ${SAS_CONSUL_SERVER_CRT})
info_msg "${move_msg}"
move_msg=$(mv -v ${VAULT_KEY} ${SAS_CONSUL_SERVER_KEY})
info_msg "${move_msg}"

if [[ -n ${CONSUL_SECRETS_DIR} ]]; then
  info_msg "Determined that the execution environment is Docker because the environment variable CONSUL_SECRETS_DIR is set"
  rm -rf ${CONSUL_SECRETS_DIR}/server.crt
  rm -rf ${CONSUL_SECRETS_DIR}/server.key
  cp -vf ${SAS_CONSUL_SERVER_CRT} ${CONSUL_SECRETS_DIR}/server.crt
  cp -vf ${SAS_CONSUL_SERVER_KEY} ${CONSUL_SECRETS_DIR}/server.key
fi

delete_consul_self_signed_cacerts_from_machine



info_msg "Waiting to get the lock: $CONSUL_LOCK_PATH to write that we have our cert: "
export CONSUL_HTTP_TOKEN=$(cat ${CONSUL_TOKEN_FILE})
${SASHOME}/bin/consul lock ${CONSUL_LOCK_PATH} ${SASHOME}/bin/write_has_vault_cert.sh
if [[ $? -ne 0 ]]; then
  error_msg $LINENO "One of two errors occurred."
  error_msg $LINENO "1) We have failed to write that we have a vault certificate"
  error_msg $LINENO "2) We have failed to release the lock after writing that we have a vault certificate"
  error_msg $LINENO "The exact cause will be realized below."
fi

notify_backoff=1
i=0
while [[ ${CONSUL_BOOTSTRAP_EXPECT}  -gt ${CONSULS_WITH_CERTS_COUNT} ]]; do
  if [[ $i -ge 900 ]]; then
    error_msg $LINENO "Waited 15 minutes for all consul servers to get a vault certificate. Check the kill helper log for all consul instances for more information."
    error_msg $LINENO "If this error is present on all 3 nodes, one or more consul agents failed to write that it has a vault certificate."
    exit 1
  fi
  sleep 1s
  let "i=i+1"
  HAS_VAULT_CERT_LIST=$($SAS_BOOTSTRAP_CONFIG kv read ${VAULT_CERT_LIST_PATH})
  if [[ $? -ne 0 ]]; then
    info_msg "Could not read from consul. Quorum was lost. This was likely caused because all consul agents consuls now have vault signed certificates and have left the cluster."
    info_msg "Killing consul and exiting our process."
    kill -SIGTERM $CONSUL_PID
    exit 0
  fi
  CONSULS_WITH_CERTS_COUNT=$(echo $HAS_VAULT_CERT_LIST | wc -w)
  if [[ $i -ge $notify_backoff ]]; then
    let "notify_backoff=2*notify_backoff"
    info_msg "Still waiting for all consul servers to place key in consul indicating successful acquisition of a vault certificate."
    info_msg "List of Consuls that have gotten a Vault cert: $HAS_VAULT_CERT_LIST"
    info_msg "CONSULS_WITH_CERTS_COUNT=$CONSULS_WITH_CERTS_COUNT"
  fi
done

info_msg "CONSULS_WITH_CERTS_COUNT (${CONSULS_WITH_CERTS_COUNT}) = CONSUL_BOOTSTRAP_EXPECT (${CONSUL_BOOTSTRAP_EXPECT})"
info_msg "Killing pid of consul"
info_msg "Running this command: kill -SIGTERM $CONSUL_PID"
kill -SIGTERM $CONSUL_PID

