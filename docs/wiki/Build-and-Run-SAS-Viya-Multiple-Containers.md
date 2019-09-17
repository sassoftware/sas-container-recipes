## Contents

- [Optional Configuration](#optional-configuration)
  - [Using Configuration Files](#using-configuration-files)
  - [Using Environment Variables](#using-environment-variables)
  - [Order of Configuration](#order-of-configuration)
- [How to Build](#how-to-build)
  - [Overview](#overview)
  - [Building on an Image Based on Red Hat Enterprise Linux](#building-on-an-image-based-on-red-hat-enterprise-linux)
  - [Building on a SUSE Linux Image](#building-on-a-suse-linux-image)
  - [Logging](#logging)
  - [Errors During the Build](#errors-during-the-build)
- [How to Run](#how-to-run)

## Optional Configuration

Before you build the images and run the containers, read about the different ways that you can modify the configuration.

### Using Configuration Files

You can provide configuration files that the container will process as it starts. To use configuration files, map a volume to the /sasinside directory in the container. The contents of that directory can include one or more of the following files:

* casconfig_usermods.lua
* cas_usermods.settings
* casstartup_usermods.lua
* autoexec_usermods.sas
* sasv9_usermods.cfg
* batchserver_usermods.sh
* connectserver_usermods.sh
* workspaceserver_usermods.sh
* sasstudio_usermods.properties

When the container starts, the content of each file is appended to the existing usermods file.

**Note:** A change to the files in the /sasinside directory does not change the configuration of a running system. A restart is required to change the configuration of a running system.

### Using Environment Variables
You can change the configuration of the CAS server by using environment variables. The CAS container will look for environment variables whose names are preceded by a particular prefix:

**CASCFG_**

This prefix indicates a _cas._ option, which is included in the casconfig_docker.lua file. These values are a predefined set and cannot be user-created. If an option is not recognized by the CAS server, it will not run.

**CASENV_**

This prefix indicates an _env._ option, which is included in the casconfig_docker.lua file.

**CASSET_**

This prefix indicates an environment variable that is included in the cas_docker.settings file.

**CASLLP_**

This prefix indicates setting the LD_LIBRARY_PATH variable in the cas_docker.settings file.

### Order of Configuration
The configuration of software follows the order of the methods (configuration files or environment variables) shown below, where the last method used sets the configuration:  

* files in the /tmp directory
* files in the /sasinside the directory
* environment variables

## How to Build
### Overview

Use the `build.sh` script in the root of the directory: sas-container-recipes/build.sh. You will be able to pass in the base image, tag what you want to build from, and provide any addons to create your custom images. 

**Note:** The following examples use a mirror repository, which is [strongly recommended](Tips#create-a-local-mirror-repository).

To see what arguments can be used, run the following:

```
build.sh --help
```

The `build.sh` script will validate several of the settings that are needed to help with the deployment process. The `docker-registry-url` and `docker-namespace` arguments are expected. If these arguments are not provided, then the script will exit early until they are provided.

* The `docker-registry-url` and `docker-namespace` arguments are used so that the process can push the containers to the Docker registry with a specific Docker tag. This same information is then used to generate the Kubernetes manifests. 
* The `virtual-host` argument points to the ingress hostname that represents the end point for the sas-viya-httpproxy container. This is an optional parameter for the programming-only deployment. The value can be changed or added after `build.sh` is run but before the images are deployed to Kubernetes.

**Note:** If the value for `virtual-host` is not updated after the build, then the user-interface links between SAS Studio and CAS Server Monitor will not work for a programming-only deployment. The `virtual-host` argument has no impact on a full deployment.

Passing in `--addons` will follow a convention to automatically add the layers to the correct SAS images. 

* Addons that begin with _auth_ will be added to the computeserver, programming, and cas containers
* Addons that begin with _access_ will be added to the computeserver, programming, and cas containers
* Addons that begin with _ide_ will be added to the programming containers

In some cases, addons might change the httpproxy container. The httpproxy container might change only if the addon contains a _Dockerfile_http_ file. An example is the ide-jpuyter-python3 addon.

To add to the base images, see [Advanced Building Options](#advanced-building-options).

### Building on an Image Based on Red Hat Enterprise Linux ###

The instructions in this section are for Red Hat Enterprise Linux (RHEL) 7 or derivatives, such as CentOS 7.

**Note:** Only images that are based on RHEL 7 can be used for recipes.

In the following example, the most recent "CentOS:7" image is pulled from DockerHub and multiple images of a programming-only deployment are built, including the addons/auth-sssd and  addons/access-odbc layers. If you decide to use more addons, add them to the space-delimited list, and make sure that the list is enclosed in double quotation marks.

To change the base image from which the SAS image will be built to any RHEL 7 derivative, change the values for the `--base-image` and `--base-tag` arguments. 

```
build.sh \
--type multiple \
--base-image centos \
--base-tag 7 \
--zip /path/to/SAS_Viya_deployment_data.zip \
--mirror-url http://host.company.com/sas_repos \
--docker-registry-url docker.registry.company.com \
--docker-namespace sas-viya \
--addons "auth-sssd access-odbc"
```

Here is an example to build multiple containers for a full deployment.

```
build.sh \
--type full\
--base-image centos \
--base-tag 7 \
--zip /path/to/SAS_Viya_deployment_data.zip \
--mirror-url http://host.company.com/sas_repos \
--docker-registry-url docker.registry.company.com \
--docker-namespace sas-viya \
--addons "auth-sssd access-odbc"
```

Building multiple images could take several hours to complete. After the process has completed, you will have 3 (programming-only) to around 25 (full) Docker images that are local on your build machine, as well as in the Docker registry that you provided. An example set of manifests is also provided, which is covered in [How to Run](#how-to-run).

### Building on a SUSE Linux Image

Building multiple containers on SUSE Linux-based images are not currently supported.

### Logging

When building images, the content that is displayed to the console is captured in one of the following files:

- builds/multiple/build.log for a `--type multiple` build
- builds/full/build.log for a `--type full` build

If problems are encountered during the build process, review the log file or provide it when opening up tickets.

### Errors During the Build

If there was an error during the build process, it is possible that some intermediate build containers were left behind. To see any images that are a result of the SAS recipe build process, run the following:

```
docker images --filter "dangling=true" --filter "label=sas.recipe.version"
```

If you encounter any of these errors, you can remove these images by running:

```
docker rmi $(docker images -q --filter "dangling=true" --filter "label=sas.recipe.version")
```

The command between the parentheses returns the image IDs that meet the filter criteria, and then will remove those images.

**Tip:** For information about how to clean up your build system, see the following Docker documentation:

- To remove all unused data, see [docker system prune](https://docs.docker.com/engine/reference/commandline/system_prune/).
- To remove images, see [docker image rm](https://docs.docker.com/engine/reference/commandline/image_rm/).

## How to Run

Locate the Kubernetes manifests, which were created during the build.

- For a programming-only deployment, the manifests are located at $PWD/builds/multiple/manifests/.
- For a full deployment the manifests are located at $PWD/builds/full/manifests/.

**Note:** In this documentation, the path to the manifests is referred to as $MANIFESTS. When you run commands that include the path, make sure that you use the path that matches your deployment type, as shown above.

For a programming-only deployment, you must update the virtual host information. Edit the $MANIFESTS/kubernetes/configmaps/cas.yml file, and update the following line by replacing _sas-viya.sas-viya.company.com_ with the ingress host or desired virtual-host information:

```
  casenv_cas_virtual_host: "sas-viya.sas-viya.company.com"
```

The manifests define several paths where data that should persist between restarts can be stored. By default, these paths point to local storage that will be removed after Kubernetes pods are deleted. Update the manifests to support how your site implements persistent storage

**Tip:** Review [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) to evaluate the options for persistence.

The following manifests that must be updated:

* consul (only in the full build)
* rabbitmq (only in the full build)
* cas
* cas-worker
* sasdatasvrc (only in the full build)

For a full deployment, each of the containers will also have a volume defined to which logs are written. To retain these logs through pod restarts, this volume should also be mapped to persistent storage.

To create your deployment, use the manifests that are created during the build process. In the following example, you are deploying into the sas-viya Kubernetes namespace. For more information about namespaces, see [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/).

During the manifest generation, a YML file was created that helps with creating the Kubernetes namespace. If your user has the ability to create namespaces in the Kubernetes environment, run the following command, or request that your Kubernetes administrator create a namespace for you in the Kubernetes environment:

```
kubectl apply -f $MANIFESTS/kubernetes/namespace/sas-viya.yml
```

After a namespace is available, run the manifests in the following order: 

```
kubectl -n sas-viya apply -f $MANIFESTS/kubernetes/ingress
kubectl -n sas-viya apply -f $MANIFESTS/kubernetes/configmaps
kubectl -n sas-viya apply -f $MANIFESTS/kubernetes/secrets
kubectl -n sas-viya apply -f $MANIFESTS/kubernetes/services
kubectl -n sas-viya apply -f $MANIFESTS/kubernetes/deployments
```

**Notes:**

- The examples use _sas-viya_ for the namespace. If you created a different namespace, use that value. 
- Make sure that the file in the $MANIFESTS/kubernetes/ingress directory contains the correct Ingress domain. An example value _company.com_ is used by default, which will not work in your environment. To change the value, see [Kubernetes Manifest Inputs](Pre-build-Tasks#kubernetes-manifest-inputs) (a pre-build task) for information about how to set it, and then see [(Optional) Regenerating Manifests](post-run-tasks#optional-regenerating-manifests) (a post-run task) for information about how to regenerate the manifests.
- If you are setting up TLS, make sure that the TLS section of the file in the $MANIFESTS/kubernetes/ingress directory is configured correctly. For more information, see the [Ingress Configuration](Pre-build-Tasks#ingress-configuration) (a pre-build task). 
- By default, the user account for the CAS administrator (the casenv_admin_user variable) is sasdemo. If you built the images with the auth-sssd addon or customized the user in the auth-demo addon, make sure to specify a valid user name for the casenv_admin_user variable, which is in one of the following files:
  - builds/multiple/manifests/kubernetes/configmaps/cas.yml for a `--type multiple` build
  - builds/full/manifests/kubernetes/configmaps/cas.yml for a `--type full` build

To check the status of the containers, run `kubectl -n sas-viya get pods`

Here is an example for a programming-only deployment:

```
kubectl -n sas-viya get pods
NAME                                            READY   STATUS    RESTARTS   AGE
sas-viya-httpproxy-0                            1/1     Running   0          21h
sas-viya-programming-0                          1/1     Running   0          21h
sas-viya-cas-0                                  1/1     Running   0          21h
```

Here is an example for a full deployment:

```
$ kubectl -n sas-viya get pods
NAME                                                   READY   STATUS    RESTARTS   AGE
sas-viya-adminservices-6f4cb4bcc4-2gdw5                1/1     Running   0          2d8h
sas-viya-advancedanalytics-9cf44bc8d-79qkd             1/1     Running   0          2d8h
sas-viya-cas-0                                         1/1     Running   0          2d8h
sas-viya-cas-worker-7b4696c458-59429                   1/1     Running   0          2d7h
sas-viya-cas-worker-7b4696c458-gzbks                   1/1     Running   0          2d7h
sas-viya-cas-worker-7b4696c458-kddgj                   1/1     Running   1          2d8h
sas-viya-casservices-867587f58-2d9sw                   1/1     Running   0          2d8h
sas-viya-cognitivecomputingservices-5967948d9b-4lgs5   1/1     Running   0          2d8h
sas-viya-computeserver-0                               1/1     Running   0          2d8h
sas-viya-computeservices-764f7bffd6-jc99t              1/1     Running   0          2d8h
sas-viya-configuratn-755c55d8-6hh9j                    1/1     Running   0          2d8h
sas-viya-consul-0                                      1/1     Running   0          2d8h
sas-viya-coreservices-75dfbbd9b4-9x85p                 1/1     Running   0          2d8h
sas-viya-datamining-7b9866977b-4cnbc                   1/1     Running   0          2d8h
sas-viya-dataservices-6566d9d548-k8x42                 1/1     Running   0          2d8h
sas-viya-graphbuilderservices-bc7bb7bd8-55vcs          1/1     Running   0          2d8h
sas-viya-homeservices-56f76dcf88-9l6zv                 1/1     Running   0          2d8h
sas-viya-httpproxy-0                                   1/1     Running   0          2d8h
sas-viya-modelservices-79f478c878-s7vkw                1/1     Running   0          2d8h
sas-viya-operations-77bcd8f7c9-jc59p                   1/1     Running   0          2d8h
sas-viya-pgpoolc-0                                     1/1     Running   0          2d8h
sas-viya-programming-0                                 1/1     Running   0          2d8h
sas-viya-rabbitmq-0                                    1/1     Running   0          2d8h
sas-viya-reportservices-86f8459f6-chh6l                1/1     Running   1          2d8h
sas-viya-reportviewerservices-79f45fbd5b-nqkf2         1/1     Running   0          2d8h
sas-viya-sasdatasvrc-0                                 1/1     Running   0          2d8h
sas-viya-scoringservices-6f97f7df86-bc4dh              1/1     Running   0          2d8h
sas-viya-studioviya-fc7fb4c9b-8wtp4                    1/1     Running   0          2d8h
sas-viya-themeservices-98dd99654-pzdp5                 1/1     Running   0          2d8h
```

Check that all the services are started:

```
$ kubectl -n sas-viya exec -it sas-viya-coreservices-75dfbbd9b4-9x85p -- /etc/init.d/sas-viya-all-services status
Getting service info from consul...
  Service                                            Status     Host               Port     PID
  sas-viya-consul-default                            up         N/A                 N/A     140
  sas-viya-alert-track-default                       up         10.254.2.52           0     242
  sas-viya-authorization-default                     up         10.254.2.52       34968     393
  sas-viya-cachelocator-default                      up         10.254.2.52       42294     444
  sas-viya-cacheserver-default                       up         10.254.2.52       40228     499
  sas-viya-identities-default                        up         10.254.2.52       34862     773
  sas-viya-ops-agent-default                         up         10.254.2.52           0    9178
  sas-viya-saslogon-default                          up         10.254.2.52       36169    1140
  sas-viya-watch-log-default                         up         10.254.2.52           0    1393
  sas-viya-files-default                             up         10.254.2.52       46109     671
  sas-viya-folders-default                           up         10.254.2.52       40650     717
  sas-viya-preferences-default                       up         10.254.2.52       35369    1038
  sas-viya-relationships-default                     up         10.254.2.52       36450    1091
  sas-viya-types-default                             up         10.254.2.52       38288    1356
  sas-viya-audit-default                             up         10.254.2.52       38647     343
  sas-viya-credentials-default                       up         10.254.2.52       33828     568
  sas-viya-crossdomainproxy-default                  up         10.254.2.52       43111     620
  sas-viya-mail-default                              up         10.254.2.52       33266     931
  sas-viya-notifications-default                     up         10.254.2.52       44958     990
  sas-viya-scheduler-default                         up         10.254.2.52       40383    1193
  sas-viya-templates-default                         up         10.254.2.52       39569    1248
  sas-viya-jobflowexecution-default                  up         10.254.2.52       45847     825
  sas-viya-jobflowscheduling-default                 up         10.254.2.52       39512     873
  sas-viya-tenant-default                            up         10.254.2.52       36599    1301

sas-services completed in 00:00:17
```

Depending on how ingress has been configured, either `http://ingress-path` or `https://ingress-path` can be reached. The examples in this documentation use https. However, if you did not configure the ingress for https, use http.
