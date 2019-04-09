#!/usr/bin/env python

# standard imports
from ctypes import *
import os
import sys
import platform
import logging

os.environ["LD_LIBRARY_PATH"] = "/opt/sas/viya/home/SASFoundation/sasexe"
os.environ["DFESP_HOME"] = "/opt/sas/viya/home/SASEventStreamProcessingEngine/current"

# import ESP pubsub and modeling apis
sys.path.append('/opt/sas/viya/home/SASEventStreamProcessingEngine/current/lib')

import pubsubApi
import modelingApi
'''
This is using the ESP pub/sub API to validate the pubsub port
'''
def main():
    # Initialize publishing capabilities. This is the first pub/sub API call 
    # that must be made, and it only needs to be called once. 
    # The first parameter is the log level, so we are turning logging off for 
    # this example. The second parameter provides the ability to provide a log 
    # configuration file path to configure how logging works, NULL will use the 
    # defaults, but for us this does not matter given we're turning it off.
    ret = pubsubApi.Init(modelingApi.ll_Off, None)
    if ret == 0:
        print('Could not initialize ESP pubsub library')
        raise SystemExit

    # Send an ESP url string requesting a ping
    # dfESP://localhost:31416
    rc = pubsubApi.PingHostPort('dfESP://localhost:31416')

    # stop pubsub
    pubsubApi.Shutdown()

    if rc == 1:
        sys.exit(0)
    else:
        sys.exit(-1)

if __name__ == '__main__':
    main()
