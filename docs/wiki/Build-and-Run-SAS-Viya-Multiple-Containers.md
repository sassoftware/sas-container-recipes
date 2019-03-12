## Contents

- [Configuration](#configuration)
  - [Running Using Configuration by Convention](#running-using-configuration-by-convention)
  - [Running using Environment Variables](#running-using-environment-variables)
  - [Precedence](#precedence)
- [How to Build](#how-to-build)
  - [Overview](#overview)
  - [Building on a Red Hat Enterprise Linux Image](#building-on-a-red-hat-enterprise-linux-image)
  - [Building on a SUSE Linux Image](#building-on-a-suse-linux-image)
  - [Logging](#logging)
  - [Errors During Build](#errors-during-build)
- [How to Run](#how-to-run)
  - [Kubernetes](#kubernetes)

## Configuration

Before we build the images, here is some information about the different ways that you can modify the configuration of the image.

### Running Using Configuration by Convention
You can provide configuration files that the container will process as it starts. To accomplish this task, map a volume to `/sasinside` in the container. The contents of that directory would contain any of the following files:

* casconfig_usermods.lua
* cas_usermods.settings
* casstartup_usremods.lua
* autoexec_usermods.sas
* sasv9_usermods.cfg
* batchserver_usremods.sh
* connectserver_usremods.sh
* workspaceserver_usremods.sh
* sasstudio_usermods.properties

If any of these files are found, then the contents are appended to the existing usermods file. A change to the files in the `/sasinside` directory would not change the behavior of a running system. Only on a restart would the behavior change.

### Running Using Environment Variables
For CAS, you can change the configuration of the container by using environment variables. The CAS container will look for environment variables of a certain prefix:

* CASCFG_ - An environment variable with this prefix translates to a `cas.` option which ends up in the `casconfig_docker.lua` file. These values are a predefined set and cannot be made up. If CAS sees an option that it does not understand, it will not run.
* CASENV_ - An environment variable with this prefix translates to a `env.` option which ends up in the casconfig_docker.lua. These values can be anything.
* CASSET_ - An environment variable with this prefix translates to an environment variable which ends up in `cas_docker.settings`. These values can be anything.
* CASLLP_ - An environment variable with this prefix translates to setting the _LD_LIBRARY_PATH_ in `cas_docker.settings`. These values can be anything.

### Precedence
Here is the order of precedence from least to greatest (the last listed variables winning prioritization):

* files from `/tmp`
* files from `/sasinisde`
* environment variables

## How to Build
### Overview
Use the `build.sh` script in the root of the directory: `sas-container-recipes/build.sh`. You will be able to pass in the base image and tag that you want to build from as well as providing any addons to create your custom image. The following examples use a mirror URL, which is [strongly recommended](Tips#create-a-local-mirror-repository).

To see what options `build.sh` takes, run

```
build.sh --help
```

The `build.sh` script will validate several of the settings that are needed to help with the deployment process. The _docker-registry-url_ and _docker-registry-namespace_ are expected as well as the _virtual-host_. If these values are not provided then the script will exit early until they are provided.

The _docker-registry-url_ and _docker-registry-namespace_ are used so that the process can push the containers to the Docker registry with a specific Docker tag. This same information is then used to generate the Kubernetes manifests. 

The `--virtual-host` option should point to the ingress host that is representing the end point for the sas-viya-httpproxy container. If this is not known at time of deployment, fill this value in with a place holder. The value can changed post running of `build.sh` and prior to deploying the images to Kubernetes.

Passing in `--addons` will follow a convention to automatically add the layers to the correct SAS images. 
* Addons that begin with _auth_ will be added to the computeserver, programming and cas containers
* Addons that begin with _access_ will be added to the computeserver, programming and cas  containers
* Addons that begin with _ide_ will be added to the programming containers

In some cases, addons may change the httpproxy container as well. This will only be if the addon contains a _Dockerfile_http_ file. One can see an example of this in the _ide-jpuyter-python3_ addon.

To add to the base images, see [Advanced Building Options](#advanced-building-options).

### Building on a Red Hat Enterprise Linux Image

The following example builds multiple containers for the SAS Viya programming-only deployment. This will pull down the most recent "CentOS:7" image from DockerHub and adds the `addons/auth-sssd` and  `addons/access-odbc` layers once the main SAS Viya images are built. If more addons are desired, add to the space delimited list. Make sure that the list is encapsulated in double quotes.

To change the base image from which we will build the SAS Viya image, change the values for the `--baseimage` and `--basetag` options. Only Red Hat Enterprise Linux 7 based images are supported for recipes. 

```
build.sh \
--type multiple \
--baseimage centos \
--basetag 7 \
--zip /path/to/SAS_Viya_deployment_data.zip \
--mirror-url http://host.company.com/sas_repo \
--docker-registry-url docker.registry.company.com \
--docker-registry-namespace sas \
--virtual-host sas-viya.company.com \
--addons "addons/auth-sssd addons/access-odbc"
```

Here is an example to build multiple containers for the SAS Viya full deployment.

```
build.sh \
--type full\
--baseimage centos \
--basetag 7 \
--zip /path/to/SAS_Viya_deployment_data.zip \
--mirror-url http://host.company.com/sas_repo \
--docker-registry-url docker.registry.company.com \
--docker-registry-namespace sas \
--virtual-host sas-viya.company.com \
--addons "addons/auth-sssd addons/access-odbc"
```

The building of the SAS Viya images could take several hours to complete. Once the process is done you will have 3 (programming only) to around 25 (full) Docker images local on your build machine as well as in the Docker registry that you provided. An example set of manifests are also provided which is covered in [How to Run](#how-to-run).

### Building on a SUSE Linux Image

Building multiple containers on SUSE Linux based images are not currently supported.

### Logging

The content that is displayed to the console when building is also captured in a log file named `${PWD}/logs/build_sas_container.log`. If a log file exists at the time of the run, the previous file is preserved with a name of `build_sas_container_<date-time stamp>.log`. If problems are encountered during the build process, review the log file or provide it when opening up tickets.
 
### Errors During Build

If there was an error during the build process there is a chance some intermediate build containers were left behind. To see any images that are a result of the SAS recipe build process, run:

`docker images --filter "dangling=true" --filter "label=sas.recipe.version"`

If you encounter any of these you can remove these images by running:

`docker rmi $(docker images -q --filter "dangling=true" --filter "label=sas.recipe.version")`

The command between the parentheses returns the image ids that meet the filter and then will remove those images.

See the Docker documentation for more options on cleaning up your build system. Here are some specific topics:

- To remove all unused data, see [docker system prune](https://docs.docker.com/engine/reference/commandline/system_prune/).
- To remove images, see [docker image rm](https://docs.docker.com/engine/reference/commandline/image_rm/).

## How to Run

### Kubernetes
For a programming only build, a set of Kubernetes manifests are located at `$PWD/viya-programming/viya-multi-container/working/manifests` and for full build they are at `$PWD/viya-visuals/working/manifests`. Please use the path that matches to your type of build. We will refer to this path as _$MANIFESTS_. 

For a programming only image, you can change the virtual host value from the value used in building the image. You may need to do this if you used a value when building that is no longer valid. Edit the `$MANIFESTS/kubernetes/deployments/cas.yml` file and add the following to the "env" section for the _sas-viya-cas_ container:

```
        - name: CASENV_CAS_VIRTUAL_HOST 
          value: "ingress-path" 
        - name: CASENV_CAS_VIRTUAL_PORT 
          value: "<port value of ingress controller>"
```

The manifests define several paths where data that should persist between restarts can be stored. By default, these paths point to local storage that disappears when Kubernetes pods are deleted. Please update the manifests to support how your site implements persistent storage. It is strongly suggested that you review [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) to evaluate the options for persistence. The manifests that require updates are:

* consul (only in the full build)
* rabbitmq (only in the full build)
* cas
* sasdatasvrc (only in the full build)

In the case of a full build, each of the containers will also have a volume defined to write logs to. To keep these logs around through pod restarts, this volume should also be mapped to persisted storage.

To create your deployment, use the manifests created during the build process. In this example, we are deploying into the _sas-viya_ Kubernetes namespace. For more information about _namespaces_, see [Kubernetes Namespaces](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/).

A json file was created during manifest generation to help with creating the Kubernetes name space. If your user has the ability to create *namespaces* in the Kuberetes environment, run the following, or request your Kuberenetes administrator to create you a name space in the Kubernetes environment:

```
kubectl create -f $MANIFESTS/kubernetes/namespace/sas-viya.yml
```

Once a *namespace* is available, run the manifests in the following order. Note that the examples are using *sas-viya* for the Kubernetes namespace. If you created a different *namespace*, please use that value instead of *sas-viya*:

```
kubectl -n sas-viya create -f $MANIFESTS/kubernetes/ingress
kubectl -n sas-viya create -f $MANIFESTS/kubernetes/configmaps
kubectl -n sas-viya create -f $MANIFESTS/kubernetes/secrets
kubectl -n sas-viya create -f $MANIFESTS/kubernetes/services
kubectl -n sas-viya create -f $MANIFESTS/kubernetes/deployments
```

To check the status of the containers, run `kubectl -n sas-viya get pods`. The following example reflects a programming multiple container deployment.

```
kubectl -n sas-viya get pods
NAME                                            READY   STATUS    RESTARTS   AGE
sas-viya-httpproxy-0                            1/1     Running   0          21h
sas-viya-programming-0                          1/1     Running   0          21h
sas-viya-cas-0                                  1/1     Running   0          21h
```

For a full deployment it would look something like:

```
$ kubectl -n sas-viya get pods
NAME                                                   READY   STATUS    RESTARTS   AGE
sas-viya-adminservices-6f4cb4bcc4-2gdw5                1/1     Running   0          2d8h
sas-viya-advancedanalytics-9cf44bc8d-79qkd             1/1     Running   0          2d8h
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
sas-viya-cas-0                                         1/1     Running   0          2d8h
sas-viya-cas-worker-7b4696c458-59429                   1/1     Running   0          2d7h
sas-viya-cas-worker-7b4696c458-gzbks                   1/1     Running   0          2d7h
sas-viya-cas-worker-7b4696c458-kddgj                   1/1     Running   1          2d8h
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

Depending on how ingress has been configured, either `http://ingress-path` or `https://ingress-path` are reachable. We will use the `https` URL going forward but if you did not configure the ingress for https, please substitute http in the provided examples.