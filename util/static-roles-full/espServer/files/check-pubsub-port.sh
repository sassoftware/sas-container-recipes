#!/bin/sh

export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/sas/viya/home/SASFoundation/sasexe

# Run the pubsub port check
/opt/sas/viya/home/bin/check-pubsub-port.py

# Exit based on the code coming from check-pubsub-port.py
exit $?
