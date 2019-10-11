#!/bin/bash

set -e
#set -x

source /opt/sas/config/sas-env.sh
source /opt/sas/config/postgres-env.sh
source ${SASHOME}/lib/envesntl/docker-functions

###############################################################################
# Variables
###############################################################################

BOOTSTRAP_CONFIG=${SASHOME}/bin/sas-bootstrap-config
export CONSUL_TOKEN=$(cat ${SASTOKENDIR}/management.token)

###############################################################################
# Functions
###############################################################################

function init_log() {
    if [ ! -z "${SASLOGDIR}" ]; then
        if [ ! -d $(dirname ${_LOGFILENAME}) ]; then
            mkdir -vp $(dirname ${_LOGFILENAME})
            chmod -v 0777 $(dirname ${_LOGFILENAME})
            chown -v ${SASPOSTGRESOWNER}:${SASPOSTGRESGROUP} $(dirname ${_LOGFILENAME})
        else
            if [ -e ${_LOGFILENAME} ]; then
                mv -v ${_LOGFILENAME} ${_LOGFILENAME}_$(date +"%Y%m%d%H%M")
            fi
        fi
    fi
}

function echo_line {
    line_out="$(date) - $1"
    if [ ! -z "${SASLOGDIR}" ]; then
        printf "%s\n" "$line_out" >>${_LOGFILENAME}
    else
        printf "%s\n" "$line_out"
    fi
}

# The script that has the functions to set up the primary or secondary nodes
source ${SASHOME}/libexec/sasdatasvrc/script/sasdatasvrc_datanodes

###############################################################################
# Create the log directory if needed and backup the previous log file
###############################################################################

init_log

###############################################################################
# Make sure Consul binaries are on the host and that we can connect to Consul
###############################################################################

# if [ ! -d ${SASCONSULDIR} ]; then
#   echo_line_line "[postgresql] Consul is not available on host...exiting"
#   exit 1
# fi

export SASINSTANCE=default
_current_uid=$(hostname -f)
_current_uid=${_current_uid//-/}

# Source the file which contains the Consul functions
source ${SASHOME}/lib/envesntl/sas-start-functions

# Setup service execution environment
sas_set_service_env

# Setup access to Consul and Vault
set +e
sas_set_consul_vault
set -e

# Make sure Consul is up
consul_status=$(${BOOTSTRAP_CONFIG} status peers)
echo_line "[postgresql] Consul status peers: $consul_status"

if [ -z "$consul_status" ]; then
  echo_line "[postgresql] No consul peers available...exiting"
  exit 1;
fi

###############################################################################
# Take the steps needed to handle failover
###############################################################################

# See what Consul has registered as the primary node
while true;do
    registered_primary_node=$(${BOOTSTRAP_CONFIG} kv read config/application/sas/database/${SASSERVICENAME}/primary)
    registered_primary_uid=$(${BOOTSTRAP_CONFIG} kv read config/application/sas/database/${SASSERVICENAME}/primary_uid)
    my_primary_uid=$(${BOOTSTRAP_CONFIG} kv read config/${SASSERVICENAME}/sas.dataserver.pool/backend/${_current_uid}/primary_uid)
    my_primary_node=$(${BOOTSTRAP_CONFIG} kv read config/${SASSERVICENAME}/sas.dataserver.pool/backend/${_current_uid}/primary)
    echo_line "$(date) [postgresql/watcher] Primary node registered in Consul: $registered_primary_uid"
    echo_line "$(date) [postgresql/watcher] UID of this host: ${_current_uid}"

    if [ ! -z ${my_primary_uid} ]; then
        echo_line "$(date) [postgresql/watcher] Checking to see if my primary matches Consul's"

        if [ ! -z ${_current_uid} ]; then
            if [ "${registered_primary_uid}" != "${my_primary_uid}" ]; then
                # if no, take action
                echo_line "$(date) [postgresql/watcher] The UID in Consul does not match this nodes expected primary..."

                if [ "${registered_primary_uid}" == "${_current_uid}" ]; then
                    echo_line "$(date) [postgresql/watcher] I am being promoted from standby to primary"

					if [ -f ${SASHOME}/bin/pg_ctl ]; then
                    	${SASHOME}/bin/pg_ctl -o "${opts}" -D ${PG_DATADIR} promote
					else
						# Different location of pg_ctl for 19w47+
                    	${POSTGRESHOME}/bin/pg_ctl -o "${opts}" -D ${PG_DATADIR} promote
					fi

                    echo_line "$(date) INFO: Recording primary host in Consul at config/${SASSERVICENAME}/sas.dataserver.pool/backend/${_current_uid}/primary"
                    ${BOOTSTRAP_CONFIG} kv write --force config/${SASSERVICENAME}/sas.dataserver.pool/backend/${_current_uid}/primary $(hostname -f)
                    ${BOOTSTRAP_CONFIG} kv write --force config/${SASSERVICENAME}/sas.dataserver.pool/backend/${_current_uid}/primary_uid ${_current_uid}
                    ${BOOTSTRAP_CONFIG} kv write --force config/${SASSERVICENAME}/sas.dataserver.pool/backend/${_current_uid}/status up
                else
                    echo_line "$(date) [postgresql/watcher] We are going to sleep and then exit in order to give the data nodes a chance to start first"
                    primary_status=$(${BOOTSTRAP_CONFIG} kv read config/${SASSERVICENAME}/sas.dataserver.pool/backend/${registered_primary_uid}/status)
                    while [ "${primary_status}" = "down" ]; do
                        echo_line "$(date) [postgresql/watcher] Primary node status is ${primary_status}...sleeping and looping until it comes up"
                        sleep 5
                        primary_status=$(${BOOTSTRAP_CONFIG} kv read config/${SASSERVICENAME}/sas.dataserver.pool/backend/${registered_primary_uid}/status)
                    done;

                    echo_line "$(date) [postgresql/watcher] Primary node status is ${primary_status}...so moving on to setup new replication"

                    # Should try to make sure the new primary is alive and well somehow...maybe ping it???
                    echo_line "$(date) [postgresql/watcher] A peer has been promoted"
                    echo_line "$(date) [postgresql/watcher] Updating configuration to follow new primary..."
                    ${BOOTSTRAP_CONFIG} kv write --force config/${SASSERVICENAME}/sas.dataserver.pool/backend/${_current_uid}/primary ${registered_primary_node}
                    ${BOOTSTRAP_CONFIG} kv write --force config/${SASSERVICENAME}/sas.dataserver.pool/backend/${_current_uid}/primary_uid ${registered_primary_uid}
                    secondary_data_node ${registered_primary_node} ${registered_primary_uid} true
                fi
            else
                echo_line "$(date) [postgresql/watcher] Primary ip addresses match...nothing to do"
            fi
        else
            echo_line "$(date) [postgresql/watcher] This node has not registered a primary yet...nothing to do"
        fi
    else
        echo_line "$(date) [postgresql/watcher] No primary node registered...waiting for primary to show themselves"
    fi
    sleep 5
done
