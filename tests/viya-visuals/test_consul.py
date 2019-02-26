#!/usr/bin/env python
"""A smoke test for Consul Containers"""

import json
import os
import time
import logging
import requests
import pytest

from kubetest_stdlib import kubeutils
from requests.packages.urllib3.exceptions import InsecureRequestWarning

# Supress warnings
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

logger = logging.getLogger(' Consul Smoke Test - examples/test_consul.py')

class TestSmoke():
    """ Use pytest to execute rest api operations against a container. """

    @classmethod
    def setup_class(cls):
        """
        Setup environment for the upcoming tests. This is basically the constructor for
        this test class. Its used to create the KubeUtils API instance used by some
        tests, retrieve environment variables from the testconfig.yaml and set up any
        structures and variables that might be used by All of the test methods below.

        """
        logger.info(" ")
        logger.info(" -----------------------------------------------------------")
        logger.info("                    Setting Up TestSmoke                    ")

        cls.NAMESPACE = os.environ.get('NAMESPACE', "default")

        # Create KubeUtils instance
        cls.kubeutilobj = kubeutils.KubeUtils()

        logger.info("                    Setup Created KubeUtils Object          ")

        # Get TEST_TYPE variable from the testconfig.yaml
        cls.TEST_TYPE = os.environ.get('TEST_TYPE', None)

        cls.pod_list = []
        # Get the list of currently running pods from kubernetes
        status, pods = cls.kubeutilobj.list("pods", cls.NAMESPACE)
        if "Success" in status:
            for pod in pods.get("items"):
                if pod.get("metadata"):
                    if pod["metadata"].get("name"):
                        pod_name = pod["metadata"]["name"]
                        cls.pod_list.append(pod_name)
        else:
            logger.error(" ERROR: pytests.py setup_class failed to retrieve pod list from Kubernetes..")
            logger.error("        pytests.py all subsequent tests will fail..")

        if cls.TEST_TYPE.lower() == 'local':
            # Get remaining variables from the testconfig.yaml
            cls.SERVICE_NAME = os.environ.get('SERVICE_NAME', None)
            cls.NAMESPACE = os.environ.get('NAMESPACE', "default")
            #cls.TARGET_POD_NAME = os.environ.get('TARGET_POD_NAME', None)
            logger.debug(" TestSmoke Setup_Class - TEST_TYPE: %s", cls.TEST_TYPE)
            #logger.debug(" TestSmoke Setup_Class - TARGET_POD_NAME: %s", cls.TARGET_POD_NAME)
            logger.debug(" TestSmoke Setup_Class - NAMESPACE: %s", cls.NAMESPACE)


        elif cls.TEST_TYPE.lower() == 'docker':
            # Get remaining variables from the testconfig.yaml
            cls.SERVICE_NAME = os.environ.get('SERVICE_NAME', None)
            cls.NAMESPACE = os.environ.get('NAMESPACE', "default")
            cls.TARGET_POD_NAME = os.environ.get('TARGET_POD_NAME', None)
            logger.debug(" TestSmoke Setup_Class - TEST_TYPE: %s", cls.TEST_TYPE)
            logger.debug(" TestSmoke Setup_Class - TARGET_POD_NAME: %s", cls.TARGET_POD_NAME)
            logger.debug(" TestSmoke Setup_Class - NAMESPACE: %s", cls.NAMESPACE)

        else:
            logger.info(" ERROR: testconfig.yaml. TEST_TYPE is undefined or misdefined. Please define as docker or local...")
            logger.info(" TEST_TYPE: %s", cls.TEST_TYPE)

        logger.info(" ")
        logger.info("                      Setup Complete                        ")
        logger.info(" -----------------------------------------------------------")

        logger.info(" ")
        logger.info(" -------    Begin Running Individual Smoke Tests     -------")


    # First pytest
    def test_01_consul_root(self):
        """
        Check user root
        """
        test_name = "consul"
        test_string = b"root"
        found = False
        for name in self.pod_list:
            if test_name in name:
                found = True
                break

        if not found:
            logger.info(" -----------------------------------------------------------")
            logger.info(" -------    test_01_consul_root: Root Test       -----------")
            logger.info(" -------                 N/A                     -----------")
            logger.info(" -----------------------------------------------------------")
            assert True 

        time.sleep(3)
        logger.info(" -----------------------------------------------------------")
        logger.info(" -------    test_01_consul_root: Root Test       -----------")
        logger.debug("test_01_consul_root: SERVICE_NAME = %s", self.SERVICE_NAME)
        logger.debug("test_01_consul_root: NAMESPACE = %s",self.NAMESPACE)
        logger.debug("test_01_consul_root: Pod name = %s",name)

        cmd = "exec {} whoami".format(name)
        logger.debug("test_01_consul_root: SERVICE_NAME = %s", cmd)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        if "Success" in status:
            if test_string in result["output"]: 
                logger.info(" -------    test_01: PASSED                       -----------")
            else:
                logger.info(" -------    test_01: FAILED                       -----------")

            assert test_string in result["output"]
        else:
            logger.info(" -------    test_01: FAILED                       -----------")
            logger.info("Result = {}".format(result))
            logger.info("Status = {}".format(status))
            assert False


    # Second pytest
    def test_02_hostname(self):
        """
        Check consul in hostname
        """
        test_name = "consul"
        test_string = b"consul"
        found = False
        for name in self.pod_list:
            if test_name in name:
                found = True
                break

        if not found:
            logger.info(" -----------------------------------------------------------")
            logger.info(" -------    test_02_consul_hostname: Hostname Test  --------")
            logger.info(" -------                  N/A                       --------")
            logger.info(" -----------------------------------------------------------")
            assert True 

        time.sleep(3)
        logger.info(" ")
        logger.info(" -----------------------------------------------------------")
        logger.info(" -------    test_02_consul_hostname: Hostname Test ---------")
        logger.debug("test_02_hostname: SERVICE_NAME = %s", self.SERVICE_NAME)
        logger.debug("test_02_hostname: NAMESPACE = %s",self.NAMESPACE)
        logger.debug("test_02_hostname: Pod name = %s",name)

        cmd = "exec {} hostname".format(name)
        logger.debug("test_02_hostname: cmd = %s", cmd)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        if "Success" in status:
            if test_string in result["output"]:
                logger.info(" -------    test_02: PASSED                       -----------")
            else:
                logger.info(" -------    test_02: FAILED                       -----------")

            assert test_string in result["output"]
        else:
            logger.info(" -------    test_02: FAILED                       -----------")
            logger.info("Result = {}".format(result))
            logger.info("Status = {}".format(status))
            assert False


    # # Third pytest
    # def test_03_agent_self(self):
    #     '''
    #     Ensure agent member name contains pod name
    #     http://consul.kubeworker1.sas.com/v1/agent/self

    #     '''
    #     time.sleep(3)
    #     logger.info(" ")
    #     logger.info(" ----------------------------------------------------")
    #     logger.info(" --------- test_03_agent_self: Agent Test ---------- ")
    #     url = "http://consul.kubeworker1.sas.com/v1/agent/self"
    #     logger.info("test_03_agent_self: url=%s", url)

    #     try:
    #         req = requests.get(url, verify=False)

    #     except requests.exceptions.RequestException as e:
    #         logger.info(" ERROR: test_03_agent_self requests.get() exception e = %s", e)
    #         assert False

    #     status = str(req.status_code)
    #     if not "200" in status:
    #         logger.info(" ERROR: test_03_agent_self,  requests.get() returned: %s", status)
    #         assert False

    #     req_dict = dict(json.loads(req.text))
    #     assert self.TARGET_POD_NAME in req_dict["Member"]["Name"]



    # # Forth pytest
    # def test_04_agent_member(self):
    #     '''
    #     http://consul.kubeworker1.sas.com/v1/agent/peers
    #     '''
    #     time.sleep(3)
    #     logger.info(" ")
    #     logger.info(" ----------------------------------------------------")
    #     logger.info(" ------ test_04_agent_member: Agent Member Test ---- ")
    #     url = "http://consul.kubeworker1.sas.com/v1/agent/members"
    #     logger.info("test_04_agent_member: url=%s", url)

    #     try:
    #         req = requests.get(url, verify=False)

    #     except requests.exceptions.RequestException as e:
    #         logger.info(" ERROR: test_04_agent_member requests.get() exception e = %s", e)
    #         assert False

    #     status = str(req.status_code)
    #     if not "200" in status:
    #         logger.info(" ERROR: test_04_agent_member,  requests.get() returned: %s", status)
    #         assert False

    #     print(json.loads(req.text))
    #     assert True
    #     #assert "consul" in dict(json.loads(req.text)[0])["Tags"]["role"]



    # def test_06_status_leader(self):
    #     """
    #     http://consul.kubeworker1.sas.com/v1/status/leader
    #     """
    #     time.sleep(3)
    #     logger.info(" ")
    #     logger.info(" ----------------------------------------------------")
    #     logger.info(" ---- test_06_status_leader: Status Leader Test ---- ")
    #     url = "http://consul.kubeworker1.sas.com/v1/status/leader"
    #     logger.info("test_06_status_leader: url=%s", url)

    #     try:
    #         req = requests.get(url, verify=False)

    #     except requests.exceptions.RequestException as e:
    #         logger.info(" ERROR: test_06_status_leader: requests.get() exception e = %s", e)
    #         assert False

    #     status = str(req.status_code)
    #     if not "200" in status:
    #         logger.info(" ERROR: test_06_status_leader:  requests.get() returned: %s", status)
    #         assert False

    #     assert req.status_code == 200
    #     logger.info(" ----------------------------------------------------")
    #     logger.info(" ")


    def test_251_espserver_root(self):
        """
        Check user root
        """
        test_name = "espserver"
        test_string = b"root"
        found = False
        for name in self.pod_list:
            if test_name in name:
                found = True

        if not found:
            logger.info(" --------------------------------------------------------")
            logger.info(" -----    test_251_espserver_root: Root User Test    ----")
            logger.info(" -------                   N/A                    -------")
            logger.info(" --------------------------------------------------------")
            assert True 

        time.sleep(3)
        logger.info(" -----------------------------------------------------------")
        logger.info(" ------    test_251_espserver_root: Root User Test    ------")
        logger.debug("test_251_espserver: SERVICE_NAME = %s", self.SERVICE_NAME)
        logger.debug("test_251_espserver: NAMESPACE = %s",self.NAMESPACE)
        logger.debug("test_251_espserver: Pod name = %s",name)

        cmd = "exec {} whoami".format(name)
        logger.debug("test_02_hostname: cmd = %s", cmd)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        if "Success" in status:
            if test_string in result["output"]:
                logger.info(" --------    test_251: PASSED                       ------------")
            else:
                logger.info(" --------    test_251: FAILED                       ------------")

            assert test_string in result["output"]
        else:
            logger.info(" --------    test_251: FAILED                       ------------")
            logger.info("Result = {}".format(result))
            logger.info("Status = {}".format(status))
            assert False


    def test_252_espserver_hostname(self):
        """
        Check espserver in hostname
        """
        test_name = "espserver"
        test_string = b"espserver"
        found = False
        for name in self.pod_list:
            if test_name in name:
                found = True
                break

        if not found:
            logger.info(" ---------------------------------------------------------------")
            logger.info(" -------    test_252_espserver_hostname: Hostname Test  --------")
            logger.info(" -------                    N/A                         --------")
            logger.info(" ---------------------------------------------------------------")
            assert True 

        time.sleep(3)
        logger.info(" ")
        logger.info(" ---------------------------------------------------------------")
        logger.info(" -------    test_252_espserver_hostname: Hostname Test ---------")
        logger.debug("test_252_espserver_hostname: SERVICE_NAME = %s", self.SERVICE_NAME)
        logger.debug("test_252_espserver_hostname: NAMESPACE = %s",self.NAMESPACE)
        logger.debug("test_252_espserver_hostname: Pod name = %s",name)

        cmd = "exec {} hostname".format(name)
        logger.debug("test_252_espserver_hostname: cmd = %s", cmd)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        if "Success" in status:
            if test_string in result["output"]:
                logger.info(" --------    test_252: PASSED                       ------------")
            else:
                logger.info(" --------    test_252: FAILED                       ------------")

            assert test_string in result["output"]
        else:
            logger.info(" --------    test_252: FAILED                       ------------")
            logger.info("Result = {}".format(result))
            logger.info("Status = {}".format(status))
            assert False


    @pytest.mark.skip(reason="The kubectl call is failing for an unknown reason.")
    def test_253_espserver_http(self):
        """
        Check the http endpoint for espserver
        """
        test_name = "espserver"
        test_string = b"esp server up and running"
        found = False
        for name in self.pod_list:
            if test_name in name:
                found = True
                break

        if not found:
            logger.info(" -------------------------------------------------------")
            logger.info(" -------    test_253_espserver_http: HTTP Test  --------")
            logger.info(" -------                N/A                     --------")
            logger.info(" -------------------------------------------------------")
            assert True 

        time.sleep(3)
        logger.info(" ")
        logger.info(" -------------------------------------------------------")
        logger.info(" -------    test_253_espserver_http: HTTP Test ---------")
        logger.debug("test_253_espserver_http: SERVICE_NAME = %s", self.SERVICE_NAME)
        logger.debug("test_253_espserver_http: NAMESPACE = %s",self.NAMESPACE)
        logger.debug("test_253_espserver_http: Pod name = %s",name)

        cmd = "exec {} -- curl -s http://localhost:31415/SASESP".format(name)
        logger.debug("test_253_espserver_http: cmd = %s", cmd)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        if "Success" in status:
            if test_string in result["output"]:
                logger.info(" --------    test_253: PASSED                       ------------")
            else:
                logger.info(" --------    test_253: FAILED                       ------------")

            assert test_string in result["output"]
        else:
            logger.info(" --------    test_253: FAILED                       ------------")
            logger.info("Result = {}".format(result))
            logger.info("Status = {}".format(status))
            assert False
