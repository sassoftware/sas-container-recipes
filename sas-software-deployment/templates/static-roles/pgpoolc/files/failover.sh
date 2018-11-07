#!/bin/bash

BOOTSTRAP_CONFIG=SASHOME/bin/sas-bootstrap-config

# failover_command = 'failover.sh %d "%h" %m "%H" %M %P'
#
# Execute command by failover.
# special values:  %d = node id
#                  %h = host name
#                  %p = port number
#                  %D = database cluster path
#                  %m = new master node id
#                  %M = old master node id
#                  %H = new master node host name
#                  %P = old primary node id
#                  %R = new master database cluster path
#                  %r = new master port number
#                  %% = '%' character
FAILED_NODE_ID=$1
FAILED_HOST_NAME=$2
NEW_MASTER_ID=$3
NEW_MASTER_HOST_NAME=$4
OLD_MASTER_ID=$5
OLD_PRIMARY_NODE_ID=$6
LOG_DIR="SASLOGDIR"
LOG_FILE=$LOG_DIR/failover.log

echo >>${LOG_FILE} "[pgpool/failover] Failover triggered at $(date)"


if [ "$FAILED_NODE_ID" == "$OLD_PRIMARY_NODE_ID" ];then
  if [ -z ${NEW_MASTER_HOST_NAME+x} ];
    echo >>${LOG_FILE} "[pgpool/failover:primary] New master not selected, all hosts must be down"
  else
    echo >>${LOG_FILE} "[pgpool/failover:primary] Record the FAILED_NODE_ID of $FAILED_NODE_ID as down in Consul"
    ${BOOTSTRAP_CONFIG} kv write --force config/SASSERVICENAME/sas.dataserver.pool/backend/$FAILED_NODE_ID/status down
    echo >>${LOG_FILE} "[pgpool/failover:primary] Record the NEW_MASTER_HOST_NAME of $NEW_MASTER_HOST_NAME as the new primary in Consul"
    NEW_MASTER_IP=$(getent hosts ${NEW_MASTER_HOST_NAME} | awk '{ print $1 }')
    ${BOOTSTRAP_CONFIG} kv write --force config/application/sas/database/SASSERVICENAME/primary $NEW_MASTER_IP
  fi
else
  echo >>${LOG_FILE} "[pgpool/failover:standby] Record the FAILED_NODE_ID of $FAILED_NODE_ID as down in Consul"
  ${BOOTSTRAP_CONFIG} kv write --force config/SASSERVICENAME/sas.dataserver.pool/backend/$FAILED_NODE_ID/status down
fi

