#!/bin/bash

set -e
# set -x


source /opt/sas/config/sas-env.sh
source /opt/sas/config/pgpool-env.sh
source ${SASHOME}/lib/envesntl/docker-functions

pcp_args="-h localhost -p 9898 -U dbmsowner -w"
pcp_node_arg="-n"

echo_line "[pgpool/watcher] start called at $(date) "

export PATH=$PATH:${SASHOME}/bin
pgpool_ctmpl_file=${SASPGPOOLCONFIGDIR}/pgpool.conf.ctmpl
pgpool_conf_file=${SASPGPOOLCONFIGDIR}/pgpool.conf

# if token file exists, then set the environment variable for bootstrap config
CONSUL_TOKEN_FILE=${SASTOKENDIR}/client.token
if [ -f $CONSUL_TOKEN_FILE ]; then
    export CONSUL_TOKEN=$(cat $CONSUL_TOKEN_FILE)
    echo_line "$(date) [pgpool/watcher] exporting CONSUL_TOKEN"
fi

BOOTSTRAP_CONFIG=${SASHOME}/bin/sas-bootstrap-config
export PCPPASSFILE=${SASPGPOOLCONFIGDIR}/.pcppass

# don't exit on error here. hacky way to deal with pgpool not listening yet
set +e
nodes=$(${SASHOME}/pgpool-II40/bin/pcp_node_count ${pcp_args})
while [[ $nodes == "" || $nodes == "0" ]]; do
    echo_line "$(date) [pgpool/watcher] no backends online yet."
    sleep 5
    echo_line "$(date) [pgpool/watcher] Pausing and then rechecking."
    nodes=$(${SASHOME}/pgpool-II40/bin/pcp_node_count ${pcp_args})
done
set -e

function node_count_from_consul {
    echo $(${BOOTSTRAP_CONFIG} kv read --recurse config/${SASSERVICENAME}/sas.dataserver.pool/backend/|awk -F '/' '{print $5}'|sort -n|uniq|wc -l)
}

# PID of the current process
echo_line "$(date) [pgpool/watcher] $(${SASHOME}/pgpool-II40/bin/pcp_node_count ${pcp_args}) backends are now online."
while :; do
    consul_node_cnt=$(node_count_from_consul)

    nodes=$(${SASHOME}/pgpool-II40/bin/pcp_node_count ${pcp_args})
    if [[ ${consul_node_cnt} -gt ${nodes} ]];then
        update_config_from_consul \
            ${pgpool_ctmpl_file} \
            ${pgpool_conf_file} \
            ${SASPGPOOLOWNER} ${SASPGPOOLGROUP} 0755
        ${SASHOME}/bin/pgpool -n -f ${SASPGPOOLCONFIGDIR}/pgpool.conf reload
        nodes=$(${SASHOME}/pgpool-II40/bin/pcp_node_count ${pcp_args})
    fi
    echo_line "$(date) [pgpool/watcher] Looping through to see what nodes we may need to attach"

    # Get the information about the nodes that pgpool knows about
    for i in `seq 1 $nodes`; do
        node_index=$(($i-1))
        node_host=$(pcp_node_info ${pcp_args} ${pcp_node_arg} ${node_index} | awk -F" " '{ print $1 }')
        node_status=$(pcp_node_info ${pcp_args} ${pcp_node_arg} ${node_index} | awk -F" " '{ print $3 }')

        # $ pcp_node_info 10 localhost 9898 postgres hogehoge 0
        # host1 5432 1 1073741823.500000

        # The result is in the following order:
        # 1. hostname
        # 2. port number
        # 3. status
        # 4. load balance weight

        # Status is represented by a digit from [0 to 3].
        # 0 - This state is only used during the initialization. PCP will never display it.
        # 1 - Node is up. No connections yet.
        # 2 - Node is up. Connections are pooled.
        # 3 - Node is down.

        echo_line "$(date) [pgpool/watcher] node_index  = ${node_index}"
        echo_line "$(date) [pgpool/watcher] node_host   = ${node_host}"
        echo_line "$(date) [pgpool/watcher] node_status = ${node_status}"

        if [ "${node_status}" == "3" ]; then

            echo_line "$(date) [pgpool/watcher] Node ${node_index} is down"

            # Now loop through each of the nodes registered in Consul and see what their status is
            #   If we have one that is "up" but pcp_node status is "down", then we need to add the node back to pgpool

            node_name=${node_host//-/}
            echo_line ${BOOTSTRAP_CONFIG} kv read config/${SASSERVICENAME}/sas.dataserver.pool/backend/${node_name}/status
            consul_status=$(${BOOTSTRAP_CONFIG} kv read config/${SASSERVICENAME}/sas.dataserver.pool/backend/${node_name}/status)

            if [ "$consul_status" == "up" ]; then
            echo_line "$(date) [pgpool/watcher] Consul says the node is up"
            echo_line "$(date) [pgpool/watcher] Running pcp_attach_node for ${node_index}"
            pcp_attach_node ${pcp_args} ${node_index}
            else
            echo_line "$(date) [pgpool/watcher] Consul says node is still down"
            fi
        fi
    done
    sleep 10
done
