#!/bin/bash

###############################################################################
# Variables
###############################################################################

[[ -z ${SASDEPLOYID+x} ]]      && export SASDEPLOYID=viya
[[ -z ${SASHOME+x} ]]          && export SASHOME=/opt/sas/viya/home
[[ -z ${SASCONFIG+x} ]]        && export SASCONFIG=/opt/sas/${SASDEPLOYID}/config
[[ -z ${SASSERVICENAME+x} ]]   && export SASSERVICENAME="postgres"
[[ -z ${SASINSTANCE+x} ]]      && export SASINSTANCE=pgpool0
[[ -z ${PG_VOLUME+x} ]]        && export PG_VOLUME="${SASCONFIG}/data/sasdatasvrc/${SASSERVICENAME}"
[[ -z ${SAS_CURRENT_HOST+x} ]] && export SAS_CURRENT_HOST=$(hostname -f)

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

# set standard environment if not already set
[[ -z ${SASLOGROOT+x} ]] && export SASLOGROOT="${SASCONFIG}/var/log"
[[ -z ${SASLOGDIR+x} ]] && export SASLOGDIR="${SASLOGROOT}/sasdatasvrc/${SASSERVICENAME}"
[[ -z ${SASCONSULDIR+x} ]] && export SASCONSULDIR="${SASHOME}"
[[ -z ${SASPOSTGRESOWNER+x} ]] && export SASPOSTGRESOWNER="sas"
[[ -z ${SASPOSTGRESGROUP+x} ]] && export SASPOSTGRESGROUP="sas"
[[ -z ${SAS_CURRENT_HOST+x} ]]   && export SAS_CURRENT_HOST=$(hostname -f)

_LOGFILENAME=${SASLOGDIR}/${SASSERVICENAME}_${SASINSTANCE}_healthcheck.log

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

_logfile=""
if [ ! -z "${SASLOGDIR}" ]; then
    _logfile=${SASLOGDIR}/${SASSERVICENAME}_${SASINSTANCE}_helathcheck.log

    if [ ! -d $(dirname ${_logfile}) ]; then
        mkdir -vp $(dirname ${_logfile})
        chmod -v 0777 $(dirname ${_logfile})
        chown -v ${SASPOSTGRESOWNER}:${SASPOSTGRESGROUP} $(dirname ${_logfile})
    else
        if [ -e ${_logfile} ]; then
            mv -v ${_logfile} ${_logfile}_$(date +"%Y%m%d%H%M")
        fi
    fi
fi

###############################################################################
# Make sure Consul binaries are on the host and that we can connect to Consul
###############################################################################

if [ ! -d ${SASCONSULDIR} ]; then
  echo_line "[healthcheck] Consul is not available on host...exiting"
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
echo_line "[healthcheck] Consul status peers: $consul_status"

if [ -z "$consul_status" ]; then
  echo_line "[healthcheck] No consul peers available...exiting"
  exit 1;
fi

export SASINSTANCE=${_tmpinstance}

###############################################################################
# Check to see if we can connect to a database
###############################################################################

_pgport=$(${_bootstrap_config} kv read config/postgres/sas.dataserver.pool/common/connection/port)
_pguser=$(${_bootstrap_config} kv read config/application/sas/database/${SASSERVICENAME}/username)
_sasdb=$(${_bootstrap_config} kv read config/application/sas/database/database)

echo_line "See if pgpool is ready..."
export PGPASSWORD=$(${_bootstrap_config} kv read config/application/sas/database/${SASSERVICENAME}/password);

# Connect and query postgres database
_cmd_output=$(${SASHOME}/bin/psql -h ${SAS_CURRENT_HOST} -p ${_pgport} -U ${_pguser} "postgresql:///${_sasdb}?connect_timeout=5" -c '\conninfo' 2>&1 )
_return_code=$?

if [ ${_return_code} -ne 0 ]; then
    echo ${_cmd_output} | grep -isq "psql: timeout expired"
    if [ $? -eq 0 ]; then
        echo_line "Warning: \"${_cmd_output}\""
        echo Warning: "${_cmd_output}"
        exit 1
    else
        echo_line "ERROR: \"${_cmd_output}\""
        echo ERROR: "${_cmd_output}"
        exit ${_return_code}
    fi
else
    echo_line "${_cmd_output}"
    echo Success
fi

exit ${_return_code}

