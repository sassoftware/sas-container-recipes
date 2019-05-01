#!/bin/bash
#
# Description:
#   It sets up the Consul KVs and registration for microservices to connect to the database.
#
# Parameters:
#   $1: Postgres server hostname
#   $2: Postgres port
# $3: Password of the database user 'dbmsowner'.


f_logger() {

    dateTimeStamp="$(date +'%F %T')"


    # Loop and append if param not null
    # logMsg="$2 $3 $4 ..."

    local logMsg=''
    local count=1

    for var in "$@"
    do
        #echo "$var"
        if [ $count -eq 2 ]; then
            logMsg="$var"
        elif [ $count -gt 2 ]; then
            logMsg="$logMsg $var"
        fi

        #echo $logMsg

        (( count += 1 ))
    done


    case "$1" in
        ERROR)
            # Log with ERROR: and send it to stderr
            if [ -z "$CurrentLogFile" ]; then
                echo "$1: $logMsg" 1>&2
            else
                echo "$1: $logMsg" | tee -a "$CurrentLogFile" 1>&2
            fi

            return 1
            ;;
        '')
            # Log a blank line
            if [ -z "$CurrentLogFile" ]; then
                echo ""
            else
                echo "" >> "$CurrentLogFile"
            fi
            ;;
        *)
            # Log with "LOG:" and does not echo. No 'tee'
            if [ -z "$CurrentLogFile" ]; then
                echo "LOG: $1 $logMsg"
            else
                echo "LOG: $1 $logMsg" >> "$CurrentLogFile"
            fi
            ;;
    esac

} # f_logger


# Check the parameters

if [ $# -lt 3 ]; then
    f_logger ERROR "Usage: $0 <Postgres server hostname> <Postgres port> <dbmsowner password>"
    f_logger ERROR "Example: $0 pghost1 5432 dbmsUserPwd1"
    exit 1
fi


# Define variables

[[ -z ${SASHOME+x} ]]   && export SASHOME=/opt/sas/viya/home
[[ -z ${SASCONFIG+x} ]] && export SASCONFIG=/opt/sas/viya/config

PGHOST=$1
PGPORT=$2
DBMS_USER_PASSWORD=$3

SERVICE_NAME=postgres
NODE_NAME=pgpool0  # Even when there is no pgpool, it has to be of pgpool because that's what microservices expect.
DBMS_USER=dbmsowner
dbName=SharedServices

# Source a script to define CONSUL related variables
# source $SASHOME/lib/envesntl/sas-start-functions
source $SASCONFIG/consul.conf

f_logger "CONSUL_HTTP_ADDR=$CONSUL_HTTP_ADDR"

# Set Consul client token
tokenFile="$SASCONFIG/etc/SASSecurityCertificateFramework/tokens/consul/default/client.token"
if [ -r "$tokenFile" ]; then
    token=$(cat $tokenFile)
    export CONSUL_TOKEN=$token  # defined later again.
    export CONSUL_HTTP_TOKEN=$token
else
    f_logger ERROR "$tokenFile is missing"
    exit 1
fi

# Check if ssl is on
export SECURED_FLG=$($SASHOME/bin/sas-bootstrap-config kv read config/$SERVICE_NAME/sas.security/network.databaseTraffic.enabled)
if [ -z "$SECURED_FLG" ]; then
    export SECURED_FLG=$($SASHOME/bin/sas-bootstrap-config kv read config/application/sas.security/network.databaseTraffic.enabled)
    if [ -z "$SECURED_FLG" ]; then
        export SECURED_FLG="false"
    fi
fi

# Let the pipe command fail if any command in the piping fails.
set -o pipefail

# Load Consul KVs for database connection info.
# Use --force to always load the same values
f_logger "Load Consul KVs with $DBMS_USER, $dbName, and other connection info"

$SASHOME/bin/sas-bootstrap-config kv write --force --site-default "config/application/postgres/username" "$DBMS_USER"
rC=$?; if [ $rC -ne 0 ]; then f_logger ERROR "failed loading Consul kv with $DBMS_USER. rC=$rC"; exit $rC; fi

$SASHOME/bin/sas-bootstrap-config kv write --force --site-default "config/application/sas/database/database" "$dbName"
rC=$?; if [ $rC -ne 0 ]; then f_logger ERROR "failed loading Consul kv with SharedServices. rC=$rC"; exit $rC; fi

$SASHOME/bin/sas-bootstrap-config kv write --force --site-default "config/application/sas/database/databaseServerName" "postgres"
rC=$?; if [ $rC -ne 0 ]; then f_logger ERROR "failed loading Consul kv with server name. rC=$rC"; exit $rC; fi

$SASHOME/bin/sas-bootstrap-config kv write --force --site-default "config/application/sas/database/postgres/username" "$DBMS_USER"
rC=$?; if [ $rC -ne 0 ]; then f_logger ERROR "failed loading Consul kv with username. rC=$rC"; exit $rC; fi

$SASHOME/bin/sas-bootstrap-config kv write --force --site-default "config/application/sas/database/schema" "\${application.schema}"
rC=$?; if [ $rC -ne 0 ]; then f_logger ERROR "failed loading Consul kv with schema. rC=$rC"; exit $rC; fi

# For password, do not use --force if already exists.
# It is to prevent the password from being replaced so that it may not mismatch with the password in Postgres server.
# Use 2>/dev/null to suppress the false alarm: "Key already exists. Write failed."
f_logger "Load $DBMS_USER password to Consul"

$SASHOME/bin/sas-bootstrap-config kv write --site-default "config/application/postgres/password" "$DBMS_USER_PASSWORD" 2>/dev/null
rC=$?; if [ $rC -ne 0 ]; then f_logger ERROR "failed loading Consul kv with password. rC=$rC"; exit $rC; fi

$SASHOME/bin/sas-bootstrap-config kv write --site-default "config/application/sas/database/postgres/password" "$DBMS_USER_PASSWORD" 2>/dev/null
rC=$?; if [ $rC -ne 0 ]; then f_logger ERROR "failed loading Consul kv with password. rC=$rC"; exit $rC; fi

# Register the service to Consul
f_logger "Register ${SERVICE_NAME}-${NODE_NAME} to Consul"
jsonFile="$HOME/service_node_registration.json"

# Even when there is no pgpool, the registration has to be of pgpool because that's what microservices expect
# We still use postgres' host and port.
tag="\"pgpool:${SERVICE_NAME}\", \"public\", \"pgpool\""

if [ "$SECURED_FLG" = "true" ]; then
    tag="$tag, \"ssl\""
fi

echo "{
  \"id\": \"${SERVICE_NAME}-${NODE_NAME}\",
  \"name\": \"${SERVICE_NAME}\",
  \"tags\": [
    $tag
  ],
  \"address\": \"$PGHOST\",
  \"port\": $PGPORT
}" | tee $jsonFile

$SASHOME/bin/sas-bootstrap-config agent service register --json $jsonFile
rC=$?; if [ $rC -ne 0 ]; then f_logger ERROR "failed registering a service to Consul. rC=$rC"; exit $rC; fi
