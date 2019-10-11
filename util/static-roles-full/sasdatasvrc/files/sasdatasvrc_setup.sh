#!/bin/bash

set -e
#set -x

###############################################################################
# Variables
###############################################################################

# Take in a name of a password variable and then see if that variable is set.
# If the password is not set return an error
function is_password_empty() {
    passwd_to_test=$1
    # Expand the variable in a variable
    # https://stackoverflow.com/questions/14049057/bash-expand-variable-in-a-variable
    if [[ -z ${!passwd_to_test+x} ]]; then
        echo "[ERROR] : Value for '${passwd_to_test}' was not provided...exiting"
        exit 1
    fi
}

[[ -z ${SASDEPLOYID+x} ]]      && export SASDEPLOYID=viya
[[ -z ${SASHOME+x} ]]          && export SASHOME=/opt/sas/viya/home
[[ -z ${SASCONFIG+x} ]]        && export SASCONFIG=/opt/sas/${SASDEPLOYID}/config
[[ -z ${SASSERVICENAME+x} ]]   && export SASSERVICENAME="postgres"
[[ -z ${SASINSTANCE+x} ]]      && export SASINSTANCE=node0
[[ -z ${PG_VOLUME+x} ]]        && export PG_VOLUME="${SASCONFIG}/data/sasdatasvrc/${SASSERVICENAME}"
[[ -z ${SAS_CURRENT_HOST+x} ]] && export SAS_CURRENT_HOST=$(hostname -f)

excessargs=()

while [ -n "$1" ]
do
  case "$1" in
    -p)
      shift
      SASPOSTGRESPIDFILE="$1"
      ;;

    -d)
      shift
      SASDEPLOYID="$1"
      ;;

     *)
# if we don't recognize argument as expected opt, accumulate and let something else consume those
      excessargs+=("$1")
      ;;
  esac
  shift  # next value
done

source ${SASHOME}/lib/envesntl/docker-functions

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
[[ -z ${SASLOGROOT+x} ]]           && export SASLOGROOT="${SASCONFIG}/var/log"
[[ -z ${SASLOGDIR+x} ]]            && export SASLOGDIR="${SASLOGROOT}/sasdatasvrc/${SASSERVICENAME}"
[[ -z ${SASCONSULDIR+x} ]]         && export SASCONSULDIR="${SASHOME}"
[[ -z ${SASPOSTGRESPORT+x} ]]      && export SASPOSTGRESPORT=5432
[[ -z ${SASPOSTGRESOWNER+x} ]]     && export SASPOSTGRESOWNER="sas"
[[ -z ${SASPOSTGRESGROUP+x} ]]     && export SASPOSTGRESGROUP="sas"
[[ -z ${SAS_DBNAME+x} ]]           && export SAS_DBNAME="SharedServices"
[[ -z ${SAS_DEFAULT_PGUSER+x} ]]   && export SAS_DEFAULT_PGUSER="dbmsowner"
is_password_empty SAS_DEFAULT_PGPWD
[[ -z ${SAS_INSTANCE_PGUSER+x} ]]  && export SAS_INSTANCE_PGUSER="${SAS_DEFAULT_PGUSER}"
[[ -z ${SAS_INSTANCE_PGPWD+x} ]]   && export SAS_INSTANCE_PGPWD="${SAS_DEFAULT_PGPWD}"
[[ -z ${SAS_DATAMINING_USER+x} ]]  && export SAS_DATAMINING_USER="dataminingwarehouse"
is_password_empty SAS_DATAMINING_PASSWORD
[[ -z ${SASPOSTGRESREPLUSER+x} ]]  && export SASPOSTGRESREPLUSER="replication"
is_password_empty SASPOSTGRESREPLPWD
[[ -z ${PG_DATADIR+x} ]]           && export PG_DATADIR="${PG_VOLUME}/${SASINSTANCE}"
[[ -z ${SASPOSTGRESCONFIGDIR+x} ]] && export SASPOSTGRESCONFIGDIR="${SASCONFIG}/etc/sasdatasvrc/${SASSERVICENAME}/${SASINSTANCE}"
[[ -z ${SASPOSTGRESRUNDIR+x} ]]    && export SASPOSTGRESRUNDIR="${SASCONFIG}/var/run/sasdatasvrc"
[[ -z ${SASPOSTGRESPIDFILE+x} ]]   && export SASPOSTGRESPIDFILE="sas-${SASDEPLOYID}-${SASSERVICENAME}-${SASINSTANCE}.pid"
[[ -z ${SASPOSTGRESDBSIZE+x} ]]    && export SASPOSTGRESDBSIZE="large"
[[ -z ${SASPOSTGRESPRIMARY+x} ]]   && export SASPOSTGRESPRIMARY=false

POSTGRESQL_CONFIG_DEFN="sas.dataserver.conf"
POSTGRESQL_CONF_SECTIONS="CONNECTIONSETTINGS,SECURITYANDAUTHENTICATION,TCPKEEPALIVES,MEMORY,DISK,KERNELRESOURCEUSAGE,COSTBASEDVACUUMDELAY,BACKGROUNDWRITER,ASYNCHRONOUSBEHAVIOR,WRITEAHEADLOGSETTINGS,WRITEAHEADLOGCHECKPOINTS,WRITEAHEADLOGARCHIVING,REPLICATIONSENDINGSERVER,REPLICATIONMASTERSERVER,REPLICATIONSTANDBYSERVERS,PLANNERMETHODCONFIGURATION,PLANNERCOSTCONSTANTS,GENETICQUERYOPTIMIZER,OTHERPLANNEROPTIONS,WHERETOLOG,WHENTOLOG,WHATTOLOG,QUERYINDEXSTATISTICSCOLLECTOR,STATISTICSMONITORING,AUTOVACUUMPARAMETERS,CLIENTCONNECTIONDEFAULTSSTATEMENTBEHAVIOR,CLIENTCONNECTIONDEFAULTSLOCALEANDFORMATTING,CLIENTCONNECTIONDEFAULTSOTHERDEFAULTS,LOCKMANAGEMENT,PREVIOUSPOSTGRESQLVERSIONS,OTHERPLATFORMSANDCLIENTS,ERRORHANDLING"
POSTGRESQLHBA_CONFIG_DEFN="sas.dataserver.hba"
POSTGRESQLHBA_CONF_SECTIONS=""

# Define defaults for the service's hba configuration
UPPER_SASSERVICENAME=$(echo ${SASSERVICENAME} | awk '{print toupper($0)}')
[[ -z ${SAS_DATASERVER_HBA_COMMON_HBA_01+x} ]] && export SAS_DATASERVER_HBA_COMMON_HBA_01="local   all         all                         trust                 # for Unix domain socket connections only"
[[ -z ${SAS_DATASERVER_HBA_COMMON_HBA_02+x} ]] && export SAS_DATASERVER_HBA_COMMON_HBA_02="sas-chosen    replication ${SASPOSTGRESREPLUSER}         all             md5                 # for replication to nodes on other servers"
[[ -z ${SAS_DATASERVER_HBA_COMMON_HBA_03+x} ]] && export SAS_DATASERVER_HBA_COMMON_HBA_03="sas-chosen    all         all         0.0.0.0/0       md5                 # for all IPv4 client connections"
[[ -z ${SAS_DATASERVER_HBA_COMMON_HBA_04+x} ]] && export SAS_DATASERVER_HBA_COMMON_HBA_04="sas-chosen    all         all         ::0/0           md5                 # for all IPv6 client connections"
[[ -z ${SAS_DATASERVER_CONF_COMMON_CONNECTIONSETTINGS_PORT+x} ]] && export SAS_DATASERVER_CONF_COMMON_CONNECTIONSETTINGS_PORT=${SASPOSTGRESPORT}
[[ -z ${SAS_DATASERVER_CONF_COMMON_WHERETOLOG_LOGGING_COLLECTOR+x} ]] && export SAS_DATASERVER_CONF_COMMON_WHERETOLOG_LOGGING_COLLECTOR="on"
[[ -z ${SAS_DATASERVER_CONF_COMMON_WHERETOLOG_LOG_DIRECTORY+x} ]] && export SAS_DATASERVER_CONF_COMMON_WHERETOLOG_LOG_DIRECTORY=${SASLOGDIR}

if [[ "${SECURE_CONSUL}" == "true" ]]; then
    [[ -z ${SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_CERT_FILE+x} ]] && export SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_CERT_FILE="${SASCONFIG}/etc/SASSecurityCertificateFramework/tls/certs/sasdatasvrc/postgres/${SASINSTANCE}/sascert.pem"
    [[ -z ${SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_KEY_FILE+x} ]]  && export SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_KEY_FILE="${SASCONFIG}/etc/SASSecurityCertificateFramework/private/sasdatasvrc/postgres/${SASINSTANCE}/saskey.pem"
    [[ -z ${SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_CA_FILE+x} ]]   && export SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_CA_FILE="${SASCONFIG}/etc/SASSecurityCertificateFramework/cacerts/trustedcerts.pem"
fi

_LOGFILENAME=${SASLOGDIR}/${SASSERVICENAME}_${SASINSTANCE}_setup.log

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

function add_bulk_consul_kv_pair {
    servicename=$1
    servicedefn=$2
    section=$3
    filename=$4
    section_header=false

    while IFS='=' read -r name value ; do
        if [[ $name == "${servicedefn}_${section}_"* ]]; then
            # We have a key, so add the section header unless we have already done so
            if [ "${section_header}" = "false" ]; then
                blankpadding="      "
                if [[ ${section} == *"_"* ]]; then
                    while IFS='_' read -ra SECTIONS ; do
                        for ymlsection in "${SECTIONS[@]}"; do
                            lower_yamlsection="${blankpadding}$(echo ${ymlsection} | awk '{print tolower($0)}')"
                            # look for section
                            set +e
                            _tmpresult=$(grep -c "${lower_yamlsection}" ${filename})
                            set -e
                            if [ $_tmpresult -eq 0 ]; then
                                echo >> ${filename} "${lower_yamlsection}:"
                            fi
                            blankpadding=${blankpadding}"  "
                        done
                    done <<< "${section}"
                else
                    echo >> ${filename} "${blankpadding}$(echo ${section} | awk '{print tolower($0)}'):"
                    blankpadding=${blankpadding}"  "
                fi
                section_header=true
            fi
            key=$(echo $name | sed "s/${servicedefn}_${section}_//")
            if [[ ${value} =~ ^[0-9]+$ ]]; then
                echo >> ${filename} "${blankpadding}$(echo $key | awk '{print tolower($0)}'): ${value}"
            else
                echo >> ${filename} "${blankpadding}$(echo $key | awk '{print tolower($0)}'): '${value}'"
            fi
        fi
    done < <(env|sort)
}


function create_and_load_bulk_consul_file {
    lower_srvcname=$(echo $1 | awk '{print tolower($0)}')
    lower_srvcdefn=$(echo $2 | awk '{print tolower($0)}')
    sectionlist=$3
    yamlfile=$4

    reset_file ${yamlfile} ${SASPOSTGRESOWNER} ${SASPOSTGRESGROUP} 0755

    echo >> ${yamlfile} "config:"
    echo >> ${yamlfile} "  ${lower_srvcname}:"
    echo >> ${yamlfile} "    ${lower_srvcdefn}:"

    upper_srvcname=$(echo ${lower_srvcname} | awk '{print toupper($0)}')
    upper_srvcdefn=$(echo ${lower_srvcdefn//\./_} | awk '{print toupper($0)}')
    for instance in COMMON $(echo ${SASINSTANCE} | awk '{print toupper($0)}'); do
        if [ ! -z "${sectionlist}" ]; then
            while IFS=',' read -ra DEFNSECTIONS ; do
                for defnsection in "${DEFNSECTIONS[@]}"; do
                    add_bulk_consul_kv_pair ${upper_srvcname} ${upper_srvcdefn} ${instance}_${defnsection} ${yamlfile}
                done
            done <<< "${sectionlist}"
        else
            add_bulk_consul_kv_pair ${upper_srvcname} ${upper_srvcdefn} ${instance} ${yamlfile}
        fi
    done

    ${BOOTSTRAP_CONFIG} kv bulkload --force --site-default --yaml ${yamlfile}
}

function add_range_to_ctmpl {
    srvcname=$(echo $1 | awk '{print tolower($0)}')
    srvcdefn=$(echo $2 | awk '{print tolower($0)}')
    sectionlist=$3
    ctmplfile=$4
    for instance in COMMON $(echo ${SASINSTANCE} | awk '{print toupper($0)}'); do
        while IFS=',' read -ra DEFNSECTIONS ; do
            for defnsection in "${DEFNSECTIONS[@]}"; do
                echo >>${ctmplfile} "{{ range tree \"config/${srvcname}/${srvcdefn}/$(echo ${instance} | awk '{print tolower($0)}')/$( echo ${defnsection} | awk '{print tolower($0)}')\" }}"
                echo >>${ctmplfile} "{{- if .Value | regexMatch \"^[0-9]+$\" }}"
                echo >>${ctmplfile} "{{ .Key }} = {{ .Value }}"
                echo >>${ctmplfile} "    {{- else }}"
                echo >>${ctmplfile} "{{ .Key }} = '{{ .Value }}'"
                echo >>${ctmplfile} "    {{- end }}"
                echo >>${ctmplfile} "{{ end -}}"
            done
        done <<< "${sectionlist}"
    done
}

function elect_postgres_primary {
    registered_primary_uid=$(${BOOTSTRAP_CONFIG} kv read config/application/sas/database/${SASSERVICENAME}/primary_uid)

    if [ ! -z "${registered_primary_uid}" ]; then
        echo_line "Primary node selected: ${registered_primary_uid}"
    elif [ "${SASPOSTGRESPRIMARY}" = "true" ] && [ -z "${registered_primary_uid}" ]; then
        ${BOOTSTRAP_CONFIG} kv write config/application/sas/database/${SASSERVICENAME}/primary ${SAS_CURRENT_HOST}
        ${BOOTSTRAP_CONFIG} kv write --force config/application/sas/database/${SASSERVICENAME}/primary_uid ${SASINSTANCE}
    else
        # Get a Consul session in order to request the init lock
        # We've seen situations where Consul will not return a session ID
        # from this REST call, so try it a few times before giving up after a minute.
        count=0
        while [ 1 -eq 1 ]; do
          response=$(curl -X PUT ${CONSUL_HTTP_ADDR}/v1/session/create 2>/dev/null)
          session_rc=$?
          echo $response | grep -e "\"ID\":\".*\"" &>/dev/null
         if [ $session_rc -ne 0 -o $? -ne 0 ]; then
            echo_line "Failed to create a Consul session ID. Return code from curl was: $session_rc   Consul response was: $response"
            if [ $count -gt 12 ]; then
              echo_line "Could not create a Consul session after 1 minute. Exiting."
              exit 1
            fi
            echo_line "Sleeping before trying to create a Consul session again..."
            let "count=count+1"
            sleep 5s
          else
            session_id=$(echo $response | sed "s/.*\"ID\":\"\(.*\)\".*/\1/")
            if [ "$session_id" == "" ]; then
              echo_line "Failed to parse Consul JSON response; exiting. Response was: $response"
              exit 1
            fi
            break
          fi
        done

        # Repeatedly attempt to acquire the init lock until it is either acquired or 5 minutes passes
        count=0
        while [ 1 -eq 1 ]; do
          lock_acquired=$(curl -K- -X PUT ${CONSUL_HTTP_ADDR}/v1/kv/${SASSERVICENAME}primary?acquire=$session_id 2>/dev/null <<< "header=\"X-Consul-Token: $CONSUL_TOKEN\"")
          if [ $? -ne 0 -o "$lock_acquired" == "" ]; then
            echo_line "Failed to query Consul lock acquisition. Exiting."
            exit 1
          fi

          if [ "$lock_acquired" == "true" ]; then
            echo_line "This node acquired the Consul lock. Initializing."
            ${BOOTSTRAP_CONFIG} kv write config/application/sas/database/${SASSERVICENAME}/primary ${SAS_CURRENT_HOST}
            ${BOOTSTRAP_CONFIG} kv write config/application/sas/database/${SASSERVICENAME}/primary_uid ${SASINSTANCE}
            export SASPOSTGRESPRIMARY=true

            lock_released=$(curl -K- -X PUT ${CONSUL_HTTP_ADDR}/v1/kv/${SASSERVICENAME}primary?release=$session_id 2>/dev/null <<< "header=\"X-Consul-Token: $CONSUL_TOKEN\"")
            if [ $? -ne 0 -o "$lock_released" != "true" ]; then
              echo_line "Failed to release the Consul lock; exiting. Response was: $lock_released"
              exit 1
            else
              echo_line "Released the Consul lock. Continuing with configuration."
              break
            fi
          elif [ "$lock_acquired" == "false" ]; then
            if [ $count -gt 60 ]; then
              echo_line "Timed out waiting for the Consul lock. Exiting."
              exit 1
            else
              echo_line "This node did not acquire the Consul lock. Sleeping..."
              let "count=count+1"
              sleep 5s
            fi
          else
            echo_line "Unexpected response from Consul lock acquisition request; exiting. Response was: $lock_acquired"
            exit 1
          fi
        done
    fi
}

function create_user {
    dbuser=$1
    dbpwd=$2

    # -h = database host
    # -p = database server port
    # -U = database user name
    # -E = encrypt stored password
    # -l = role can login (default)
    # -d = role can create new databases
    # -r = role can create new roles
    # -s = role will be superuser

	if ${POSTGRESHOME}/bin/psql postgres -h ${SASPOSTGRESRUNDIR} -p ${SASPOSTGRESPORT} -U ${SASPOSTGRESOWNER} -tAc "SELECT 1 FROM pg_roles WHERE rolname='${dbuser}'" | grep -q 1; then
        echo_line "User ${dbuser} already exists"
    else
        echo_line "Creating user ${dbuser}..."
        ${POSTGRESHOME}/bin/createuser -h ${SASPOSTGRESRUNDIR} -p ${SASPOSTGRESPORT} -U ${SASPOSTGRESOWNER} -Eldrs ${dbuser}
    fi

    echo_line "Updating password for user ${dbuser}..."
	${POSTGRESHOME}/bin/psql -h ${SASPOSTGRESRUNDIR} -p ${SASPOSTGRESPORT} -U ${SASPOSTGRESOWNER} postgres -c "ALTER ROLE \"${dbuser}\" WITH PASSWORD '${dbpwd}'"

    if [[ "${dbuser}" == "${SAS_DATAMINING_USER}" ]]; then
		${POSTGRESHOME}/bin/psql -h ${SASPOSTGRESRUNDIR} -p ${SASPOSTGRESPORT} -U ${SASPOSTGRESOWNER} postgres -c "ALTER ROLE \"${dbuser}\" WITH NOINHERIT"
    fi
}

function create_database {
    create_user ${SAS_DEFAULT_PGUSER} ${SAS_DEFAULT_PGPWD}
    create_user ${SAS_INSTANCE_PGUSER} ${SAS_INSTANCE_PGPWD}
    create_user ${SAS_DATAMINING_USER} ${SAS_DATAMINING_PASSWORD}

    echo_line "setting up database ${SAS_DBNAME}"

    # -h = database host
    # -p = database server port
    # -U = database user name
    # -E, --encoding=ENCODING  encoding for the database
    # -l, --locale=LOCALE      locale settings for the database
    # --lc-collate=LOCALE      LC_COLLATE setting for the database
    # --lc-ctype=LOCALE        LC_CTYPE setting for the database
    # -O, --owner=OWNER        database user to own the new database
    # -T, --template=TEMPLATE  template database to copy

    # To see if the db exists:
    if ${POSTGRESHOME}/bin/psql -h ${SASPOSTGRESRUNDIR} -p ${SASPOSTGRESPORT} -U ${SASPOSTGRESOWNER} -lqt | cut -d \| -f 1 | grep -qw ${SAS_DBNAME}; then
      echo_line "Database ${SAS_DBNAME} already exists"
    else
      ${POSTGRESHOME}/bin/createdb -h ${SASPOSTGRESRUNDIR} -p ${SASPOSTGRESPORT} -U ${SASPOSTGRESOWNER} -O ${SASPOSTGRESOWNER} -E UTF8 -T template0 --locale=en_US.utf8 ${SAS_DBNAME}
    fi

    echo_line "grant all privileges on ${SAS_DBNAME} to ${SAS_DEFAULT_PGUSER}"
    # -c = run only single command (SQL or internal) and exit
	${POSTGRESHOME}/bin/psql -h ${SASPOSTGRESRUNDIR} -p ${SASPOSTGRESPORT} -U ${SASPOSTGRESOWNER} postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"${SAS_DBNAME}\" TO \"${SAS_DEFAULT_PGUSER}\""

    if [ "${SAS_INSTANCE_PGUSER}" != "${SAS_DEFAULT_PGUSER}" ]; then
        echo_line "grant all privileges on ${SAS_DBNAME} to ${SAS_INSTANCE_PGUSER}"
        # -c = run only single command (SQL or internal) and exit
		${POSTGRESHOME}/bin/psql -h ${SASPOSTGRESRUNDIR} -p ${SASPOSTGRESPORT} -U ${SASPOSTGRESOWNER} postgres -c "GRANT ALL PRIVILEGES ON DATABASE \"${SAS_DBNAME}\" TO \"${SAS_INSTANCE_PGUSER}\""
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

BOOTSTRAP_CONFIG=${SASCONSULDIR}/bin/sas-bootstrap-config

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
consul_status=$(${BOOTSTRAP_CONFIG} status peers)
echo_line "[postgresql] Consul status peers: $consul_status"

if [ -z "$consul_status" ]; then
  echo_line "[postgresql] No consul peers available...exiting"
  exit 1;
fi

export SASINSTANCE=${_tmpinstance}

##############################################################################
# Generate the key and cert for TLS
##############################################################################

if [[ "${SECURE_CONSUL}" == "true" ]]; then
    #
    # Make the directories for the cert and key
    #
    mkdir -p $(dirname $SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_CERT_FILE)
    mkdir -p $(dirname $SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_KEY_FILE)
    chown -R ${SASPOSTGRESOWNER}:${SASPOSTGRESGROUP} ${SASCONFIG}/etc/SASSecurityCertificateFramework/tls/certs/sasdatasvrc
    chown -R ${SASPOSTGRESOWNER}:${SASPOSTGRESGROUP} ${SASCONFIG}/etc/SASSecurityCertificateFramework/private/sasdatasvrc

    #
    # Use sas-bootstrap-config and its 'network addresses' command to obtain a string
    # consisting of a comma delimited list of IP addresses found on this machine.
    #
    CERT_IPADDRESS_LIST=$(${BOOTSTRAP_CONFIG} network addresses | tr '[:space:]' ',' | sed 's/.$//' )

    #
    # Gather some info to be used in TLS cert generation.
    #
    CERT_HOSTNAME_PLAIN=$(hostname)
    CERT_HOSTNAME_FQDN=$(hostname -f)
    CERT_HOSTNAME_SHORT_NAME=$(hostname -s)

    #
    # Run sas-crypto-management to generate a new certificate file.
    #
    $SASHOME/SASSecurityCertificateFramework/bin/sas-crypto-management \
        req-vault-cert \
        --common-name $CERT_HOSTNAME_FQDN \
        --out-crt $SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_CERT_FILE \
        --out-key $SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_KEY_FILE \
        --san-dns localhost \
        --san-dns $CERT_HOSTNAME_FQDN \
        --san-dns $CERT_HOSTNAME_PLAIN \
        --san-dns $CERT_HOSTNAME_SHORT_NAME \
        --san-ip 127.0.0.1 \
        --san-ip $CERT_IPADDRESS_LIST \
        --vault-token $SASCONFIG/etc/SASSecurityCertificateFramework/tokens/sasdatasvrc/default/vault.token \
        --vault-cafile $SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_CA_FILE

    chown ${SASPOSTGRESOWNER}:${SASPOSTGRESGROUP} $SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_CERT_FILE
    chown ${SASPOSTGRESOWNER}:${SASPOSTGRESGROUP} $SAS_DATASERVER_CONF_COMMON_SECURITYANDAUTHENTICATION_SSL_KEY_FILE
fi

##############################################################################
# Initialize the configuration
##############################################################################

if [ ! -d ${SASPOSTGRESCONFIGDIR} ]; then
    echo_line "[postgresql] Create configuration directory"
    mkdir -vp ${SASPOSTGRESCONFIGDIR}
fi

echo_line "[postgresql] Change ownership and permissions on the config directory: ${SASPOSTGRESCONFIGDIR}"
chmod -v 0777 ${SASPOSTGRESCONFIGDIR}
chown -v ${SASPOSTGRESOWNER}:${SASPOSTGRESGROUP} ${SASPOSTGRESCONFIGDIR}

if [ ! -d ${PG_VOLUME} ]; then
    echo_line "[postgresql] Create root data directory: ${PG_VOLUME}"
    mkdir -vp ${PG_VOLUME}
    echo_line "[postgresql] Change ownership and permissions on the data directory: ${PG_VOLUME}"
    chmod -vR 0700 ${PG_VOLUME}
    chown -v ${SASPOSTGRESOWNER}:${SASPOSTGRESGROUP} ${PG_VOLUME}
fi


if [ ! -d ${SASPOSTGRESRUNDIR} ]; then
    echo_line "[postgresql] Create run directory: ${SASPOSTGRESRUNDIR}"
    mkdir -vp ${SASPOSTGRESRUNDIR}
fi

echo_line "[postgresql] Change ownership and permissions on the run directory: ${SASPOSTGRESRUNDIR}"
chmod -vR 0700 ${SASPOSTGRESRUNDIR}
chown -v ${SASPOSTGRESOWNER}:${SASPOSTGRESGROUP} ${SASPOSTGRESRUNDIR}

# Copy and update the basic configuration
if [ ! -e ${SASPOSTGRESCONFIGDIR}/postgresql.conf ]; then
    cp -v ${SASHOME}/share/postgresql/${SASPOSTGRESDBSIZE}_postgresql.conf ${SASPOSTGRESCONFIGDIR}/postgresql.conf
    sed -i "s|SASPOSTGRESLOGDIR|${SASLOGDIR}|" ${SASPOSTGRESCONFIGDIR}/postgresql.conf
    sed -i "s|SASPOSTGRESRUNDIR|${SASPOSTGRESRUNDIR}|" ${SASPOSTGRESCONFIGDIR}/postgresql.conf
    sed -i "s|SASPOSTGRESDATADIR|${PG_DATADIR}|" ${SASPOSTGRESCONFIGDIR}/postgresql.conf
    sed -i "s|SASPOSTGRESCONFIGDIR|${SASPOSTGRESCONFIGDIR}|" ${SASPOSTGRESCONFIGDIR}/postgresql.conf
    sed -i "s|SASPOSTGRESPIDFILE|${SASPOSTGRESPIDFILE}|" ${SASPOSTGRESCONFIGDIR}/postgresql.conf
fi

# Load the postgresql configuration into Consul
create_and_load_bulk_consul_file \
    ${SASSERVICENAME} \
    ${POSTGRESQL_CONFIG_DEFN} \
    ${POSTGRESQL_CONF_SECTIONS} \
    ${SASPOSTGRESCONFIGDIR}/sas_dataserver_conf.yml

# Load the postgresql hba configuration into Consul
create_and_load_bulk_consul_file \
    ${SASSERVICENAME} \
    ${POSTGRESQLHBA_CONFIG_DEFN} \
    "${POSTGRESQLHBA_CONF_SECTIONS}" \
    ${SASPOSTGRESCONFIGDIR}/sas_dataserver_hba.yml

# if [ ! -e ${SASPOSTGRESCONFIGDIR}/handle_failover.sh ]; then
#     cp -v ${SASHOME}/share/postgresql/handle_failover.sh ${SASPOSTGRESCONFIGDIR}/handle_failover.sh
#     sed -i "s|SASHOME|${SASHOME}|" ${SASPOSTGRESCONFIGDIR}/handle_failover.sh
#     sed -i "s|SASCONFIG|${SASCONFIG}|" ${SASPOSTGRESCONFIGDIR}/handle_failover.sh
#     sed -i "s|PG_DATADIR|${PG_DATADIR}|" ${SASPOSTGRESCONFIGDIR}/handle_failover.sh
# fi
##############################################################################
# Create Consul template files
##############################################################################

# Set up config files
userdefined_postgresql_ctmpl_file=${SASPOSTGRESCONFIGDIR}/userdefined_postgresql.conf.ctmpl
userdefined_postgresql_conf_file=${SASPOSTGRESCONFIGDIR}/userdefined_postgresql.conf
postgresql_hba_ctmpl_file=${SASPOSTGRESCONFIGDIR}/pg_hba.conf.ctmpl
postgresql_hba_conf_file=${SASPOSTGRESCONFIGDIR}/pg_hba.conf

reset_file ${userdefined_postgresql_ctmpl_file} ${SASPOSTGRESOWNER} ${SASPOSTGRESGROUP} 0755

cat >> ${userdefined_postgresql_ctmpl_file} << CFTMPLLOOP
{{define "ssloption" }}
    {{- if eq (keyOrDefault "config/${SASSERVICENAME}/sas.security/network.databaseTraffic.enabled" "not_found") "not_found" -}}
        {{if (keyOrDefault "config/application/sas.security/network.databaseTraffic.enabled" "false" | parseBool) -}}
            ssl = true
        {{- else -}}
            ssl = false
        {{- end -}}
    {{- else -}}
        {{- if (key "config/${SASSERVICENAME}/sas.security/network.databaseTraffic.enabled"| parseBool) -}}
            ssl = true
        {{- else -}}
            ssl = false
        {{- end -}}
    {{- end -}}
{{- end -}}

{{template "ssloption"}} # Added through Consul-template
CFTMPLLOOP

add_range_to_ctmpl \
    ${SASSERVICENAME} \
    ${POSTGRESQL_CONFIG_DEFN} \
    ${POSTGRESQL_CONF_SECTIONS} \
    ${userdefined_postgresql_ctmpl_file}

if [ ! -e ${postgresql_hba_ctmpl_file} ]; then
    cp -v ${SASHOME}/share/postgresql/pg_hba.conf.ctmpl ${postgresql_hba_ctmpl_file}
    sed -i "s|SASSERVICENAME|${SASSERVICENAME}|" ${postgresql_hba_ctmpl_file}
fi

##############################################################################
# Reload the configuration files from consul
##############################################################################

# Call consul template to create user defined file
update_config_from_consul \
    ${userdefined_postgresql_ctmpl_file} \
    ${userdefined_postgresql_conf_file} \
    ${SASPOSTGRESOWNER} ${SASPOSTGRESGROUP} 0755

update_config_from_consul \
    ${postgresql_hba_ctmpl_file} \
    ${postgresql_hba_conf_file} \
    ${SASPOSTGRESOWNER} ${SASPOSTGRESGROUP} 0755

##############################################################################
# Elect a primary node
##############################################################################

elect_postgres_primary

##############################################################################
# Initialize the database depending on if this is a primary or secondary
##############################################################################

# See what Consul has registered as the primary node
registered_primary_node=$(${BOOTSTRAP_CONFIG} kv read config/application/sas/database/${SASSERVICENAME}/primary)
echo_line "[postgresql] IP for Primary node registered in Consul: ${registered_primary_node}"
echo_line "[postgresql] IP for this host:                         ${SAS_CURRENT_HOST}"

registered_primary_uid=$(${BOOTSTRAP_CONFIG} kv read config/application/sas/database/${SASSERVICENAME}/primary_uid)
echo_line "[postgresql] UID for Primary node registered in Consul: ${registered_primary_uid}"
echo_line "[postgresql] UID for this host:                         ${SASINSTANCE}"

if [ "${registered_primary_uid}" = "${SASINSTANCE}" ]; then
    echo_line "[repl:primary] Consul says I am the primary..."
    if [ -d ${PG_DATADIR} ]; then
        # See if my Consul info says I am primary
        echo_line "[repl:primary] Checking to see if I think I was already primary"
        my_primary_uid=$(${BOOTSTRAP_CONFIG} kv read config/${SASSERVICENAME}/sas.dataserver.pool/backend/${SASINSTANCE}/primary_uid)

        if [ "$my_primary_uid" == "${SASINSTANCE}" ]; then
            echo_line "[repl:primary] Primary UIDs match...nothing to do"
        else
            echo_line "[repl:primary] I am being promoted from standby to primary"
            # Call promote in this case.
        fi
    else
        # I am the primary but the data dir does not exist
        echo_line "[repl:primary] I am primary but the data dir does not exist..."
        echo_line "[repl:primary] Running primary data node configuration"

        # Call function to set up the primary node
        primary_data_node
    fi
else
    echo_line "[repl:secondary] I am not primary; executing secondary configuration..."
    echo_line "[repl:secondary] Running secondary data node configuration with a primary of: $registered_primary_node"

    # Call function to set up the secondary node
    secondary_data_node ${registered_primary_node} ${registered_primary_uid}
fi

# Start postgres via pg_ctl
echo_line "[postgresql] Starting postgres via pg_ctl..."
${POSTGRESHOME}/bin/pg_ctl -o "-c config_file=${SASPOSTGRESCONFIGDIR}/postgresql.conf -c hba_file=${SASPOSTGRESCONFIGDIR}/pg_hba.conf" -D ${PG_DATADIR} -w -t 30 start

if [ $? = 0 ]; then
  echo_line "[postgresql] PostgreSQL started successfully"

  if [ "${registered_primary_node}" = "${SAS_CURRENT_HOST}" ]; then
    echo_line "[postgresql] Creating database"
    create_database
  fi

  if [ ${SASPOSTGRESREPLICATION} ] && [ "${registered_primary_node}" = "${SAS_CURRENT_HOST}" ]; then
    echo_line "[repl:primary] setting up replication"
    cat >${SASPOSTGRESCONFIGDIR}/setup-replication.sql << REPL
DO
\$body\$
BEGIN
  IF NOT EXISTS (SELECT * FROM pg_catalog.pg_user WHERE usename = 'replication') THEN
    CREATE ROLE ${SASPOSTGRESREPLUSER} WITH REPLICATION PASSWORD '${SASPOSTGRESREPLPWD}' LOGIN;
  END IF;
END
\$body\$;
REPL

    # Run the script
	${POSTGRESHOME}/bin/psql -h ${SASPOSTGRESRUNDIR} -p ${SASPOSTGRESPORT} -U ${SASPOSTGRESOWNER} postgres < ${SASPOSTGRESCONFIGDIR}/setup-replication.sql
  fi
else
  echo_line "[postgresql] The PostgreSQL server start seems to have some problems, please see logs for details."
  exit 1
fi

# Stop postgres via pg_ctl
echo_line "[postgresql] Stopping postgres via pg_ctl..."
${POSTGRESHOME}/bin/pg_ctl -o "-c config_file=${SASPOSTGRESCONFIGDIR}/postgresql.conf -c hba_file=${SASPOSTGRESCONFIGDIR}/pg_hba.conf" -D ${PG_DATADIR} -w -t 30 stop
