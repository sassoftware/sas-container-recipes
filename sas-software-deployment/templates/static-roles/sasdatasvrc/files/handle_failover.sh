#!/bin/bash

set -e
#set -x

###############################################################################
# Variables
###############################################################################

# set standard environment if not already set
[[ -z ${SASDEPLOYID+x} ]]      && export SASDEPLOYID=viya
[[ -z ${SASHOME+x} ]]          && export SASHOME=/opt/sas/viya/home
[[ -z ${SASCONFIG+x} ]]        && export SASCONFIG=/opt/sas/${SASDEPLOYID}/config
[[ -z ${SASSERVICENAME+x} ]]   && export SASSERVICENAME="postgres"
[[ -z ${SASINSTANCE+x} ]]      && export SASINSTANCE=node0
[[ -z ${SAS_CURRENT_HOST+x} ]] && export SAS_CURRENT_HOST=$(hostname -f)
[[ -z ${PG_VOLUME+x} ]]        && export PG_VOLUME="${SASCONFIG}/data/sasdatasvrc/${SASSERVICENAME}"

# In the case of Docker, we need to load up what the instance value is.
# The instance was saved by the docker_entrypoint.sh so it can be used 
# by multiple scripts
_sasuuidname=sas_${SASDEPLOYID}_${SASSERVICENAME}_uuid
_k8ssasuuid=${PG_VOLUME}/${SAS_CURRENT_HOST}_${_sasuuidname}
_sasuuid=${PG_VOLUME}/${_sasuuidname}

[[ -e ${_k8ssasuuid} ]] && source ${_k8ssasuuid}
[[ -e ${_sasuuid} ]] && source ${_sasuuid}

# Process any overrides if they exist
_sysconfig=${SASCONFIG}/etc/sasdatasvrc/${SASSERVICENAME}/${SASINSTANCE}/sas-${SASSERVICENAME}
[[ -e ${_sysconfig} ]] && source ${_sysconfig}

[[ -z ${SASLOGROOT+x} ]]           && export SASLOGROOT="${SASCONFIG}/var/log"
[[ -z ${SASLOGDIR+x} ]]            && export SASLOGDIR="${SASLOGROOT}/sasdatasvrc/${SASSERVICENAME}"
[[ -z ${SASCONSULDIR+x} ]]         && export SASCONSULDIR="${SASHOME}"
[[ -z ${SASPOSTGRESOWNER+x} ]]     && export SASPOSTGRESOWNER="postgres"
[[ -z ${SASPOSTGRESGROUP+x} ]]     && export SASPOSTGRESGROUP="postgres"
[[ -z ${SASPOSTGRESCONFIGDIR+x} ]] && export SASPOSTGRESCONFIGDIR="${SASCONFIG}/etc/sasdatasvrc/${SASSERVICENAME}/${SASINSTANCE}"
[[ -z ${PG_DATADIR+x} ]]           && export PG_DATADIR="${PG_VOLUME}/${SASINSTANCE}"

_LOGFILENAME=${SASLOGDIR}/${SASSERVICENAME}_${SASINSTANCE}_failover.log

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

if [ ! -d ${SASCONSULDIR} ]; then
  echo_line "[postgresql] Consul is not available on host...exiting"
  exit 1
fi

_bootstrap_config=${SASCONSULDIR}/bin/sas-bootstrap-config

_tmpinstance=${SASINSTANCE}
export SASINSTANCE=default

# Source the file which contains the Consul functions
source ${SASHOME}/lib/envesntl/sas-start-functions

# Setup service execution environment
sas_set_service_env

# Setup access to Consul and Vault
set +e
sas_set_consul_vault
set -e

# Make sure Consul is up
consul_status=$(${_bootstrap_config} status peers)
echo_line "[postgresql] Consul status peers: $consul_status"

if [ -z "$consul_status" ]; then
  echo_line "[postgresql] No consul peers available...exiting"
  exit 1;
fi

export SASINSTANCE=${_tmpinstance}

###############################################################################
# Take the steps needed to handle failover
###############################################################################

# See what Consul has registered as the primary node
registered_primary_uid=$(${BOOTSTRAP_CONFIG} kv read config/application/sas/database/${SASSERVICENAME}/primary_uid)
echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] Primary node registered in Consul: $registered_primary_uid"
echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] UID of this host: ${SASINSTANCE}"

if [ ! -z ${registered_primary_uid} ]; then
    echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] Checking to see if my primary matches Consul's"

    if [ ! -z ${SASINSTANCE} ]; then
        if [ "${registered_primary_uid}" != "${SASINSTANCE}" ]; then
            # if no, take action
            echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] The UID in Consul does not match this nodes expected primary..."

            if [ "${registered_primary_uid}" == "${SASINSTANCE}" ]; then
                echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] I am being promoted from standby to primary"
                ${SASHOME}/bin/pg_ctl -o "${opts}" -D ${PG_DATADIR} promote

                echo >>${WATCHER_LOG} "$(date) INFO: Recording primary host in Consul at config/${SASSERVICENAME}/sas.dataserver.pool/backend/${SASINSTANCE}/primary"
                ${BOOTSTRAP_CONFIG} kv write --force config/${SASSERVICENAME}/sas.dataserver.pool/backend/${SASINSTANCE}/primary ${SAS_CURRENT_HOST}
                ${BOOTSTRAP_CONFIG} kv write --force config/${SASSERVICENAME}/sas.dataserver.pool/backend/${SASINSTANCE}/status up
            else
                echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] We are going to sleep and then exit in order to give the data nodes a chance to start first"
                primary_status="down"
                while [ "${primary_status}" = "down" ]; do
                    echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] Primary node status is ${primary_status}...sleeping and looping until it comes up"
                    sleep 5
                    primary_status=$(${BOOTSTRAP_CONFIG} kv read config/${SASSERVICENAME}/sas.dataserver.pool/backend/${registered_primary_uid}/status)
                done;

                echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] Primary node status is ${primary_status}...so moving on to setup new replication"

                # Should try to make sure the new primary is alive and well somehow...maybe ping it???
                echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] A peer has been promoted"
                echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] Updating configuration to follow new primary..."
                secondary_data_node
            fi
        else
            echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] Primary ip addresses match...nothing to do"
        fi
    else
        echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] This node has not registered a primary yet...nothing to do"
    fi
else
    echo >>${WATCHER_LOG} "$(date) [postgresql/watcher] No primary node registered...waiting for primary to show themselves"
fi

