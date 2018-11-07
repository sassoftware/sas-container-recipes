#!/bin/bash

DATA_PATH=/data
ESP_PATH=/opt/sas/viya/home/SASEventStreamProcessingEngine/current
ESP_CONFIG_PATH=/opt/sas/viya/config/etc/SASEventStreamProcessingEngine/default
DFESP_HOME=${ESP_PATH}
SASEXE=/opt/sas/viya/home/SASFoundation/sasexe
LD_LIBRARY_PATH=${ESP_PATH}/lib:${ESP_PATH}/lib/plugins:${SASEXE}:${ESP_PATH}/lib/tk:${LD_LIBRARY_PATH}
PATH=${PATH}:${ESP_PATH}/BIN

HTTP_PORT=8080
PUB_SUB_PORT=5000
HTTP_PUB_SUB_PORT=8082
HOSTNAME=`hostname`

export ESP_PATH
export DFESP_HOME
export LD_LIBRARY_PATH
export PATH

if [ -n "${ESM_FRIENDLY_NAME}" ]
then
  export FRIENDLY_NAME=${ESM_FRIENDLY_NAME}
else
  export FRIENDLY_NAME=${HOSTNAME}
fi

if [ -n "${SAS_ESP_HTTP_ADMIN_PORT}" ]
then
  export HTTP_PORT=${SAS_ESP_HTTP_ADMIN_PORT}
fi

if [ -n "${SAS_ESP_HTTP_PUBSUB_PORT}" ]
then
  export HTTP_PUB_SUB_PORT=${SAS_ESP_HTTP_PUBSUB_PORT}
fi

export LD_LIBRARY_PATH=${DFESP_HOME}/lib:${DFESP_HOME}/lib/tk:${SASEXE}:${LD_LIBRARY_PATH}
export TKPATH=/opt/sas/viya/home/SASFoundation/sasexe

if [ -f "${DATA_PATH}/twitterpublisher.properties" ]
then
   cp "${DATA_PATH}/twitterpublisher.properties" "${DFESP_HOME}/etc/"
fi

# Write a file with the current timestamp in to indicate when this server started.
echo `date +%s` > ${ESP_PATH}/startup.timestamp

if [ -n "${SAS_ESP_SSL_HOST}" ]
then
  export DFESP_SSLPATH=${DFESP_HOME}/lib
  cp /data/ca.pem ${DFESP_HOME}/etc/
  cp /data/ca.pem ${ESP_CONFIG_PATH}
  
  # Compile to openssl properties file.
  while IFS='' read -r line || [[ -n "$line" ]]; do
    eval "echo \"$line\"" >> "${DFESP_HOME}/openssl.conf"
  done < "${DFESP_HOME}/openssl.conf.template"
  IPCOUNTER=1
  for IP in `hostname -I`
  do
    echo "IP.${IPCOUNTER} = ${IP}" >> ${DFESP_HOME}/openssl.conf
	let IPCOUNTER=IPCOUNTER+1
  done
  openssl req -sha256 -key /data/ca.key -new -out server.csr -subj "/C=US/ST=NC/L=Cary/O=SAS Institute/CN=${SAS_ESP_SSL_HOST}/emailAddress=GBR_RD_Scotland_ESP_Team@wnt.sas.com" -config ${DFESP_HOME}/openssl.conf
  openssl x509 -sha256 -req -in server.csr -CA /data/ca.pem -CAkey /data/ca.key -CAcreateserial -out server.crt -days 365 -extensions v3_req -extfile ${DFESP_HOME}/openssl.conf
  cat server.crt /data/ca.key > ${ESP_CONFIG_PATH}/server.pem
  keytool -importcert -keystore /etc/pki/java/cacerts -file /data/ca.pem -storepass changeit -noprompt -alias sasrds
  export HTTP_PUB_SUB_PORT=${HTTP_PUB_SUB_PORT}s
  export HTTP_PORT=${HTTP_PORT}s
fi

ESP_ARGS="-pubsub ${PUB_SUB_PORT} -http ${HTTP_PORT} -plugindir ${SASEXE} -engine ${FRIENDLY_NAME}"

if [ -n "${SAS_ESP_OAUTH_CLIENT}" ]
then
    ESP_ARGS="${ESP_ARGS} -auth ${SAS_ESP_OAUTH_CLIENT}"
fi

${DFESP_HOME}/bin/dfesp_xml_server ${ESP_ARGS}
