#!/usr/bin/env python
"""A smoke test for containers"""

import json
import logging
import os
import pytest
import requests
import time

from kubetest_stdlib import dkrutils

from requests.packages.urllib3.exceptions import InsecureRequestWarning

# Supress warnings
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

logger = logging.getLogger(__name__)


class TestSmoke():
    """ Use pytest to execute rest api operations against a container. """

    @classmethod
    def setup_class(cls):
        """
        Setup environment for upcoming tests.

        - Get IP of server container.
        - Build base URL.
        """
        # Detect if running in container else use local host
        time.sleep(20)
        if "True" in os.environ.get('RUNNING_IN_DOCKER', "False"):
            server_ip = os.environ.get('DOCKER_NETWORK', 'testnet')
        elif "False" in os.environ.get('RUNNING_IN_DOCKER', "False"):
            server_ip = os.environ.get('localhost', '0.0.0.0')
        else:
            server_ip = '0.0.0.0'
        # Build base url
        cls.SERVER_IP = server_ip
        cls.BASE_URL = "http://{}:80/SASStudio".format(server_ip)
        cls.dkrutilsobj = dkrutils.DockerUtils()
        cls.CONTAINER_NAME = os.environ.get("container_name", "programming")


    def test_01_tini_running_pid_1(self):
        """ Ensure tini is pid 1 """
        cmd = ["ps", "--pid", "1", "h", "c"]
        status, result = self.dkrutilsobj.exec_cmd(self.CONTAINER_NAME, cmd)
        print(status, result)
        assert status == 0 and b"tini" in result

    def test_02_http_process_running(self):
        """ Ensure http process started """
        cmd = ["ps", "xh", "c"]
        status, result = self.dkrutilsobj.exec_cmd(self.CONTAINER_NAME, cmd)
        assert status == 0 and b"http" in result

    def test_03_cas_monitor_deployed(self):
        """ Ensure cas monitor deployed """
        url = "http://{}:80/cas-shared-default-http".format(self.SERVER_IP)
        req = requests.get(url, verify=False)
        status = str(req.status_code)
        assert req.status_code == 200

    def test_04_sasstudio_login_status(self):
        """
        Check return code from ESP service is 200
        """
        time.sleep(15)
        req = requests.get(self.BASE_URL, verify=False)
        status = str(req.status_code)
        assert req.status_code == 200
