#!/bin/sh

# This will expose what is being called to Consul
set -x

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/sas/viya/home/SASFoundation/sasexe

# Run the pubsub port check
python /opt/sas/viya/home/bin/check-pubsub-port.py

# Exit based on the code coming from check-pubsub-port.py
exit $?
