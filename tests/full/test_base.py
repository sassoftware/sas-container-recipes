#!/usr/bin/env python
"""Common smoke tests for k8s containers"""

import json
import logging
import os
import pytest
import requests
import time

from kubetest_stdlib import kubeutils
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
        namespace = os.environ.get('NAMESPACE', "default")
        container_test_targets = os.environ.get('TARGET_PODS', "ALL")
        kubeutilobj = kubeutils.KubeUtils()
        # Expose variables to test functions
        cls.container_test_targets = container_test_targets
        cls.NAMESPACE = namespace
        cls.kubeutilobj = kubeutilobj


    def test_01_pod_user_not_root(self):
        """
        Check user root
        """
        time.sleep(1)
        cmd = "exec {} whoami".format(self.TARGET_POD_NAME)
        status,result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        assert b"root" not in result["output"]

    def test_02_hostname(self):
        """
        Check consul in hostname
        """
        cmd = "exec {} hostname".format(self.TARGET_POD_NAME)
        status, result = self.kubeutilobj.kubectl(cmd, self.NAMESPACE)
        assert self.TARGET_BASE_NAME in result["output"].decode("utf-8")
