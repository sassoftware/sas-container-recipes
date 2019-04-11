#!/usr/bin/env python
"""A smoke test for containers"""

import json
import logging
import os
import pytest
import requests
import time

from kubetest_stdlib import testutils
from requests.packages.urllib3.exceptions import InsecureRequestWarning

# Supress warnings
requests.packages.urllib3.disable_warnings(InsecureRequestWarning)

logger = logging.getLogger(__name__)


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
        # Initial setup
        test_target = "httpproxy"
        test_vars = testutils.k8s_test_setup(test_target)

        # This is incorrect
        server_ip = 'saspzb-programming.devok8s.sas.com'

        # Expose variables to test functions
        cls.TARGET_BASE_NAME = test_target
        cls.TARGET_POD_NAME  = test_vars.get("target_pod_name")
        cls.NAMESPACE        = test_vars.get("namespace")
        cls.kubeutilobj      = test_vars.get("kubeutilobj")
        cls.SERVER_IP = server_ip

    def test_01_pod_user_not_root(self):
        """
        Check user not running as root
        """
        time.sleep(1)
        cmd = "exec {} whoami".format(self.TARGET_POD_NAME)
        status,result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        error_flag = False
        if "failure" in status.lower() or b"root" in result["output"]:
            error_flag = True
        assert error_flag == False

    def test_02_hostname(self):
        """
        Check hostname matches container name
        """
        cmd = "exec {} hostname".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        assert self.TARGET_BASE_NAME in result["output"].decode("utf-8")

    def test_03_tini_running_pid_1(self):
        """
        Ensure tini is pid 1
        """
        cmd = "exec {} -- ps --pid 1 h c".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"tini" in result["output"]

    def test_04_http_process_running(self):
        """
        Ensure http process is running
        """
        cmd = "exec {} -- ps xh c".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"http" in result["output"]

    @pytest.mark.skip(reason="Cannot work out correct URL to establish the connection.")
    def test_05_cas_monitor_deployed(self):
        """
        Verify cas server monitor deployed
        """
        url = "http://{}:80/cas-shared-default-http/healthCheck".format(self.SERVER_IP)
        req = requests.get(url, verify=False)
        status = str(req.status_code)
        assert req.status_code == 200

    def test_06_check_package_installed(self):
        """
        Ensure common package is installed
        """
        cmd = "exec {} -- rpm -q initscripts".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"initscripts" in result["output"]

    def test_07_check_package_installed(self):
        """
        Ensure common package is installed
        """
        cmd = "exec {} -- rpm -q which".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"which" in result["output"]

    def test_08_check_package_installed(self):
        """
        Ensure common package is installed
        """
        cmd = "exec {} -- rpm -q acl".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"acl" in result["output"]

    def test_09_check_package_installed(self):
        """
        Ensure common package is installed
        """
        cmd = "exec {} -- rpm -q libpng12".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"libpng12" in result["output"]

    def test_10_check_package_installed(self):
        """
        Ensure common package is installed
        """
        cmd = "exec {} -- rpm -q libXp".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"libXp" in result["output"]

    def test_11_check_package_installed(self):
        """
        Ensure common package is installed
        """
        cmd = "exec {} -- rpm -q libXmu".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"libXmu" in result["output"]

    def test_12_check_package_installed(self):
        """
        Ensure common package is installed
        """
        cmd = "exec {} -- rpm -q net-tools".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"net-tools" in result["output"]

    def test_13_check_package_installed(self):
        """
        Ensure common package is installed
        """
        cmd = "exec {} -- rpm -q xterm".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"xterm" in result["output"]

    def test_14_check_package_installed(self):
        """
        Ensure common package is installed
        """
        cmd = "exec {} -- rpm -q numactl".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        print(status, result)
        assert status == 'Success' and b"numactl" in result["output"]
