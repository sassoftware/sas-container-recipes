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
[[ -z ${SASPOSTGRESOWNER+x} ]]     && export SASPOSTGRESOWNER="sas"
[[ -z ${SASPOSTGRESGROUP+x} ]]     && export SASPOSTGRESGROUP="sas"
[[ -z ${SASPOSTGRESCONFIGDIR+x} ]] && export SASPOSTGRESCONFIGDIR="${SASCONFIG}/etc/sasdatasvrc/${SASSERVICENAME}/${SASINSTANCE}"
[[ -z ${PG_DATADIR+x} ]]           && export PG_DATADIR="${PG_VOLUME}/${SASINSTANCE}"

_LOGFILENAME=${SASLOGDIR}/${SASSERVICENAME}_${SASINSTANCE}_stop.log

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
# Stop postgres
###############################################################################

# Stop postgres via pg_ctl => This will create the PIDFILE
echo_line "[postgresql] Stopping postgres via pg_ctl..."
set -x
if [ -f ${SASHOME}/bin/pg_ctl ]; then
	${SASHOME}/bin/pg_ctl -o '-c config_file=${SASPOSTGRESCONFIGDIR}/postgresql.conf -c hba_file=${SASPOSTGRESCONFIGDIR}/pg_hba.conf' -D ${PG_DATADIR} -w -t 30 stop
else
	# Different location of pg_ctl for 19w47+
	${POSTGRESHOME}/bin/pg_ctl -o '-c config_file=${SASPOSTGRESCONFIGDIR}/postgresql.conf -c hba_file=${SASPOSTGRESCONFIGDIR}/pg_hba.conf' -D ${PG_DATADIR} -w -t 30 stop
fi
set +x

###############################################################################
# Unregister service
###############################################################################

# Consul service de-registration
echo_line "[postgresql] De-registering content in Consul"
set -x
${_bootstrap_config} agent service deregister "${SASSERVICENAME}-${SASINSTANCE}"
set +x

