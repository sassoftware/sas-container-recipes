#!/bin/bash

###############################################################################
# Variables
###############################################################################

[[ -z ${SASROOT+x} ]]           && export SASROOT=/opt/sas
[[ -z ${SASDEPLOYID+x} ]]       && export SASDEPLOYID=viya
[[ -z ${SASHOME+x} ]]           && export SASHOME=${SASROOT}/${SASDEPLOYID}/home
[[ -z ${SASCONFIG+x} ]]         && export SASCONFIG=${SASROOT}/${SASDEPLOYID}/config
[[ -z ${SASSERVICENAME+x} ]]    && export SASSERVICENAME="postgres"
[[ -z ${SASSERVICECONTEXT+x} ]] && export SASSERVICECONTEXT="postgres"
[[ -z ${SASINSTANCE+x} ]]       && export SASINSTANCE=pgpool0
[[ -z ${PG_VOLUME+x} ]]         && export PG_VOLUME="${SASCONFIG}/data/sasdatasvrc/${SASSERVICECONTEXT}"
[[ -z ${SAS_CURRENT_HOST+x} ]]  && export SAS_CURRENT_HOST=$(hostname -f)

# In the case of Docker, we need to load up what the instance value is.
# The instance was saved by the docker_entrypoint.sh so it can be used 
# by multiple scripts
_sasuuidname=sas_${SASDEPLOYID}_${SASSERVICECONTEXT}_uuid
_k8ssasuuid=${PG_VOLUME}/${SAS_CURRENT_HOST}_${_sasuuidname}
_sasuuid=${PG_VOLUME}/${_sasuuidname}

[[ -e ${_k8ssasuuid} ]] && source ${_k8ssasuuid}
[[ -e ${_sasuuid} ]] && source ${_sasuuid}

# Process any overrides if they exist
_sysconfig=${SASCONFIG}/etc/sasdatasvrc/${SASSERVICENAME}/${SASINSTANCE}/sas-${SASSERVICENAME}
[[ -e ${_sysconfig} ]] && source ${_sysconfig}

# set standard environment if not already set
[[ -z ${SASLOGROOT+x} ]]         && export SASLOGROOT="${SASCONFIG}/var/log"
[[ -z ${SASLOGDIR+x} ]]          && export SASLOGDIR="${SASLOGROOT}/sasdatasvrc/${SASSERVICECONTEXT}"
[[ -z ${SASCONSULDIR+x} ]]       && export SASCONSULDIR="${SASHOME}"
[[ -z ${SASPGPOOLCONFIGDIR+x} ]] && export SASPGPOOLCONFIGDIR="${SASCONFIG}/etc/sasdatasvrc/${SASSERVICECONTEXT}/${SASINSTANCE}"
[[ -z ${SASPGPOOLOWNER+x} ]]     && export SASPGPOOLOWNER="saspgpool"

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

function reset_file {
    resetname=$1
    fileuser=$2
    filegroup=$3
    fileperms=$4

    [[ -e ${resetname} ]] && rm ${resetname}
    touch ${resetname}
    chown -v ${fileuser}:${filegroup} ${resetname}
    chmod -v ${fileperms} ${resetname}

}

###############################################################################
# Create the log directory if needed and backup the previous log file
###############################################################################

init_log

###############################################################################
# Make sure Consul binaries are on the host and that we can connect to Consul
###############################################################################

if [ ! -d ${SASCONSULDIR} ]; then
    echo_line "[pgpool] Consul is not available on host...exiting"
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
echo_line "[pgpool] Consul status peers: $consul_status"

if [ -z "$consul_status" ]; then
  echo_line "[pgpool] No consul peers available...exiting"
  exit 1;
fi

export SASINSTANCE=${_tmpinstance}

###############################################################################
# Run pgpool
###############################################################################

echo_line "[pgpool] Stop pgpool as ${SASPGPOOLOWNER}"
${SASHOME}/bin/pgpool -n -f ${SASPGPOOLCONFIGDIR}/pgpool.conf -F ${SASPGPOOLCONFIGDIR}/pcp.conf -a ${SASPGPOOLCONFIGDIR}/pool_hba.conf -m fast stop

###############################################################################
# Consul de-registration
###############################################################################

echo_line "[pgpool] Unregister pgpool service from Consul: ${SASSERVICENAME}-${SASINSTANCE}"
${_bootstrap_config} agent service deregister "${SASSERVICENAME}-${SASINSTANCE}"

