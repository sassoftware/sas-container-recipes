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
[[ -e ${SASCONFIG}/etc/sasdatasvrc/${SASSERVICENAME}/${SASINSTANCE}/sas-${SASSERVICENAME} ]] \
  && source ${SASCONFIG}/etc/sasdatasvrc/${SASSERVICENAME}/${SASINSTANCE}/sas-${SASSERVICENAME}

[[ -z ${SASLOGROOT+x} ]]           && export SASLOGROOT="${SASCONFIG}/var/log"
[[ -z ${SASLOGDIR+x} ]]            && export SASLOGDIR="${SASLOGROOT}/sasdatasvrc/${SASSERVICENAME}"
[[ -z ${SASCONSULDIR+x} ]]         && export SASCONSULDIR="${SASHOME}"
[[ -z ${SASPOSTGRESOWNER+x} ]]     && export SASPOSTGRESOWNER="postgres"
[[ -z ${SASPOSTGRESGROUP+x} ]]     && export SASPOSTGRESGROUP="postgres"
[[ -z ${SASPOSTGRESCONFIGDIR+x} ]] && export SASPOSTGRESCONFIGDIR="${SASCONFIG}/etc/sasdatasvrc/${SASSERVICENAME}/${SASINSTANCE}"
[[ -z ${SASPOSTGRESRUNDIR+x} ]]    && export SASPOSTGRESRUNDIR="${SASCONFIG}/var/run/sasdatasvrc"

_LOGFILENAME=${SASLOGDIR}/${SASSERVICENAME}_${SASINSTANCE}_isready.log

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
# Define the _logfile and create the log directory if needed
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
# Check postgres status
###############################################################################

_postgres_port=$(${_bootstrap_config} kv read config/postgres/sas.dataserver.conf/common/connectionsettings/port)
_sasdbowner=$(${_bootstrap_config} kv read config/application/sas/database/postgres/username)
_sasdb=$(${_bootstrap_config} kv read config/application/sas/database/database)

echo_line "[postgresql] See if postgres is ready..."
_status=$(${SASHOME}/bin/pg_isready -h ${SASPOSTGRESRUNDIR} -p ${_postgres_port} -U ${_sasdbowner} -d ${_sasdb})
_exit_code=$?

echo_line "[postgresql] status = ${_status}"

exit ${_exit_code}

