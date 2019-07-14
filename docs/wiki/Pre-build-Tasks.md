## Contents

- [Obtain the Required Files](#obtain-the-required-files)
- [Create a Mirror](#create-a-mirror)
- [Use a Docker Registry](#use-a-docker-registry)
- [Addons](#addons)
  - [Host Authentication](#host-authentication)
    - [sssd Authentication](#sssd-authentication)
  - [Data Sources](#data-sources)
    - [Greenplum](#greenplum)
    - [Hadoop](#hadoop)
    - [ODBC](#odbc)
    - [Oracle](#oracle)
    - [Redshift](#redshift)
    - [Teradata](#teradata)
- [Kubernetes](#kubernetes)
  - [Ingress Configuration](#ingress-configuration)
  - [Persistence](#persistence)
  - [Data Import](#data-import)
  - [Bulk Loading of Configuration Values](#bulk-loading-of-configuration-values)
  - [Kubernetes Manifest Inputs](#kubernetes-manifest-inputs)

## Obtain the Required Files

1. Locate your SAS Viya for Linux Software Order Email (SOE) and the SAS_Viya_deployment_data.zip file attachment.

1. Perform one of the following tasks to get the project files:
    
    - Download the latest release at [https://github.com/sassoftware/sas-container-recipes/releases](https://github.com/sassoftware/sas-container-recipes/releases).

    - Run the following command: `git clone git@github.com:sassoftware/sas-container-recipes.git`

## Create a Mirror

A local mirror repository can save you time whenever you run a build, and it protects against download limits.

- Each time that you build an image of the SAS Viya software, the required RPM files must be accessed.
- Setting up a local mirror repository for the RPM files can save time because you access the RPM files locally each time that you build or rebuild an image. If you do create a local mirror repository, then the RPM files are downloaded from servers that are hosted by SAS, which can take longer.
- There is a limit to how many times that you can download a SAS Viya software order from the SAS servers.

**Note:** A multi-threaded HTTP server is required to access the local mirror repository.

For more information about creating a local mirror repository, see [Create a Mirror Repository](https://go.documentation.sas.com/?docsetId=dplyml0phy0lax&amp;docsetTarget=p1ilrw734naazfn119i2rqik91r0.htm&amp;docsetVersion=3.4) in _SAS Viya for Linux: Deployment Guide_.

## Use a Docker Registry

**Note:** If you use Kubernetes as your deployment tool, you must follow these steps. Otherwise, for Docker, the following steps are optional.

A registry is a storage and content delivery system that contains Docker images, which are available in different versions, with each image having its own tag. Self-hosting a registry makes it easy to share images internally. For more information about the Docker registry, see [https://docs.docker.com/registry/introduction/](https://docs.docker.com/registry/introduction/).

The build process will use ansible-container to push the built images to the provided Docker registry. To do this, the $HOME/.docker/config.json file must contain the Docker registry URL and an authentication value. These settings allow ansible-container to connect to the Docker registry.

To update the $HOME/.docker/config.json file, run the following command: 

<code>docker login <i>docker-registry</i></code>

After you run the command, validate that the $HOME/.docker/config.json file contains the expected Docker registry URL and authentication value. 

Here is an example of the config.json file settings:

```
docker login docker-registry.company.com
cat $HOME/.docker/config.json
{
     "HttpHeaders": {
          "User-Agent": "Docker-Client/18.06.1-ce (linux)"
     },
     "auths": {
          "docker-registry.company.com": {
               "auth": "Zm9vOmZvb2Jhcg=="
          }
     }
}
```

## Addons

You can use addons to include extra components in your SAS Viya images. There are addons for authentication, data sources, and integrated development environments (IDE). Only the addons that require pre-build tasks are listed in this section. You can find the addons in sas-container-recipes/addons directory.

For more information, see [Addons](https://github.com/sassoftware/sas-container-recipes/wiki/Appendix-Under-the-Hood#addons).

### Host Authentication

Some SAS Viya containers require host-level authentication: the single programming-only container and the multiple containers, programming-only Compute Server and CAS containers. Use the addons whose names are preceded by the _auth_ prefix to set up host authentication.

#### sssd Authentication

You will use commands to copy the sas-container-recipes/addons/example_sssd.con file to a file named sssd.conf. Next, edit the sssd.conf file to set the appropriate configuration values. If an SSL certificate is needed, provide the certificate as a file named sssd.cert.

Here are the commands:

```
cp sas-container-recipes/addons/auth-sssd/example_sssd.conf sas-container-recipes/addons/auth-sssd/sssd.conf
vi sas-container-recipes/addons/auth-sssd/sssd.conf
```

### Data Sources

This section provides pre-build tasks for some of the access addons that provide data access for SAS Viya. Only the access addons that require pre-build tasks are listed in this section. 

#### Greenplum

Before you can use the access-greenplum addon, confirm that the environment variables in the greenplum_saserver.sh file specify the locations of the ODBC configurations. The default locations for the ODBC configuration files are in the /sasinside directory.

- For single containers running on Docker, this directory is mapped automatically to the running container from the Docker host.
- For containers running on Kubernetes, the /sasinside directory (or a preferred directory) should be mapped to the sas-viya-programming, sas-viya-computeserver and sas-viya-cas pods.

Here are the commands that specify the locations of the ODBC configurations:

```
export ODBCSYSINI=/sasinside/odbc
export ODBCINI=${ODBCSYSINI}/odbc.ini
export ODBCINSTINI=${ODBCSYSINI}/odbcinst.ini
export LD_LIBRARY_PATH=${ODBCSYSINI}/lib:$LD_LIBRARY_PATH
```

If you need to change locations, make sure to update the greenplum_saserver.sh file before you build the images.

#### Hadoop

Before you can use the access-hadoop addon, collect the Hadoop configuration files (/config) and JAR files (/jars), and add them to the sas-container-recipes/addons/access-hadoop/hadoop directory.

After you have included the Hadoop configuration and JAR files are in this directory, the files are added to a /hadoop directory in an image that includes the access-hadoop addon.

Here is an example of the directory structure:

```
sas-container-recipes/addons/access-hadoop/hadoop/config
sas-container-recipes/addons/access-hadoop/hadoop/jars
```

#### ODBC

Before you can use the access-odbc addon, confirm that the environment variables in the odbc_cas.settings and odbc_saserver.sh files specify the locations of the ODBC configurations. The default locations for the ODBC configuration files are in the /sasinside directory.

- For single containers running on Docker, this directory is mapped automatically to the running container from the Docker host.
- If running on Kubernetes,  the /sasinside directory (or a preferred directory) should be mapped to the sas-viya-programming, sas-viya-computeserver and sas-viya-cas pods.

Here are the commands that specify the locations of the ODBC configurations:

```
export ODBCSYSINI=/sasinside/odbc
export ODBCINI=${ODBCSYSINI}/odbc.ini
export ODBCINSTINI=${ODBCSYSINI}/odbcinst.ini
export LD_LIBRARY_PATH=${ODBCSYSINI}/lib:$LD_LIBRARY_PATH
```

If you need to change locations, make sure to update the odbc_cas.settings and odbc_saserver.sh files before you build the images.

#### Oracle

Before you can use the access-oracle addon, add the Oracle client library RPMs and a file named tnsnames.ora to the sas-container-recipes/addons/access-oracle directory.

Confirm that the environment variables in the oracle_cas.settings and oracle_saserver.sh represent the locations of the Oracle configuration. The default configuration expects that Oracle files will be available from within the image.

**Note:** The Dockerfile will attempt to install any RPMs in this directory.

#### Redshift

Before you can use the access-redshift addon, confirm that the environment variables in the redshift_cas.settings and redshift_saserver.sh files specify the locations of the ODBC configurations. 
The default locations for the ODBC configuration files are in the /sasinside directory.

- For single containers running on Docker, this directory is mapped automatically to the running container from the Docker host.
- If running on Kubernetes, the /sasinside directory (or a preferred directory) should be mapped to the sas-viya-programming, sas-viya-computeserver and sas-viya-cas pods. 

Here are the commands that specify the locations of the ODBC configurations:

```
export ODBCSYSINI=/sasinside/odbc
export ODBCINI=${ODBCSYSINI}/odbc.ini
export ODBCINSTINI=${ODBCSYSINI}/odbcinst.ini
export LD_LIBRARY_PATH=${ODBCSYSINI}/lib:$LD_LIBRARY_PATH
```

If you need to change locations, make sure to update the redshift_cas.settings and redshift_saserver.sh files before you build the images.

#### Teradata

Before you can use the access-teradata addon you need to get the compressed ZIP file that contains the Teradata Tools and Utilities. After you have this file, rename it to teradata.tgz and place it in sas-container-recipes/addons/access-teradata/ directory.

The Dockerfile expects that the teradata.tgz file is in the current directory and has the following structure:

```
|__TeradataToolsAndUtilitiesBase
   |__Readmes
   |__Linux
   |__TeraJDBC
   |__v16.10.01
   |__setup.bat
   |__.setup.sh
   |__ThirdPartyLicensesTTU.txt
```

The Dockerfile looks for the Teradata gzip file and runs the setup.bat script to install the Teradata libraries.

**Note:** Error messages about missing i386 dependencies can safely be ignored unless your environment requires them. If the i386 dependencies are required, install them by adding the necessary commands to the Dockerfile.

## Kubernetes 
### Ingress Configuration
To access SAS, you must identify endpoints that allow things outside the Kubernetes environment to talk to the correct endpoints inside the Kubernetes environment. Although this can be done different ways, the trend is to use an Ingress Controller. This document does not explain how to set up the Ingress Controller but it will explain how to set up a specific Ingress configuration to identify the proper endpoints for the SAS containers.

For the **multiple and full deployment types** we have added building the ingress configuration as part of the manifest generation. For the **single container deployment** an example configuration is provided in the *samples* directory:

```
samples
├── viya-single-container
│   ├── example_ingress.yml
│   ├── example_launchsas.sh
│   └── example_programming.yml
```

Find the example_ingress.yml file for the single container. Then, copy and edit it, as follows:

```
mkdir ${PWD}/run
cp samples/viya-single-container/example_ingress.yml ${PWD}/run/programming_ingress.yml
vi ${PWD}/run/programming_ingress.yml
```

In the copied file, find and replace all instances of @REPLACE_ME_WITH_YOUR_K8S_NAMESPACE@ and @REPLACE_ME_WITH_YOUR_DOMAIN@ with appropriate values. Here is an example

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
  name: sas-viya-programming-ingress
  namespace: sas-viya
spec:
  rules:
  - host: sas-viya.sas-viya.company.com
    http:
      paths:
      - backend:
          serviceName: sas-viya-httpproxy
          servicePort: 80
#  tls:
#  - hosts:
#    - sas-viya.sas-viya.company.com
#    secretName: @REPLACE_ME_WITH_YOUR_CERT@
```

TLS is set up by configuring the Ingress definition. For more information, see [TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls).

You will need to create a key and certificate, and then store it in a Kubernetes secret. In the following example, the tls section in the ${PWD}/run/programming_ingress.yml file is updated to include the Kubernetes secret, which is named sas-tls-secret.

```
  tls:
  - hosts:
    - sas-viya.sas-viya.company.com
    secretName: sas-tls-secret
```

Load the configuration:

```
kubectl -n sas-viya apply -f ${PWD}/run/programming_ingress.yml
```

If you cannot set this up yet, you can continue on the deployment process. However, the ingress must be configured to access the environment.

Later in this documentation, the term _ingress-path_ refers to the host value in your Ingress configuration. In the preceding example, sas-viya.company.com is the ingress path.

### Persistence

Several SAS Viya containers will need persistent storage configured to make sure that the environment can shut down and start up without losing data.

- Decide whether to set up persistent storage.
- No persistance is the default condition. The default is useful if you are evaluating SAS Viya containers. Otherwise you will want to make sure that your Kubernetes environment is configured for container persistence. For more information, see [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/). 

### Data Import

When importing data into SAS Viya, the import might fail without displaying an error or writing an error to CAS logs. This failure to import data can happen if the size of the file being imported exceeds the maximum size allowed by the Kubernetes Ingress Controller. 

To change the Ingress Controller settings, globally or for the specific Ingress rule, see [NGINX Configuration](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/).

SAS has tested using the nginx.ingress.kubernetes.io/proxy-body-size annotation as documented for **Custom max body size**. For more information, see [Custom max body size](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#custom-max-body-size).

If you know the size of files to be imported, then set **Custom max body size** to a value that will allow the files to be loaded. If a value of zero (0) is used, then checking of the file size is ignored, and no file size restrictions will be imposed by Kubernetes.

### Bulk Loading of Configuration Values

For a full deployment, you can create a sitedefault.yml file in the sas-container-recipes project directory that is used to bulk load configuration values for multiple services. After the initial deployment, you cannot simply modify sitedefault.yml to change an existing value and deploy the software again. You can modify sitedefault.yml only to set property values that have not already been set. Therefore, SAS recommends that you do not use sitedefault.yml for the initial deployment of your SAS Viya software, except where specifically described in this document.

When the sitedefault.yml file is present in the sas-container-recipes project directory, the build process will base64 encode the file and put it into the builds/full/manifests/kubernetes/configmaps/consul.yml file in the consul_key_value_data_enc variable. When the consul container starts, the key-value pairs in consul_key_value_data_enc are bulk loaded into the SAS configuration store.

Here are the steps to use sitedefault.yml to set configuration values:

1. Sign on to your build machine with administrator privileges, and locate the util/sitedefault_sample.yml file.
1. Make a copy of sitedefault_sample.yml and name it sitedefault.yml.
1. Using a text editor, open sitedefault.yml and add values that are valid for your site.
   - For information about the LDAP properties used in sitedefault.yml, see [sas.identities.providers.ldap](https://go.documentation.sas.com/?cdcId=calcdc&cdcVersion=3.4&docsetId=calconfig&docsetTarget=n08000sasconfiguration0admin.htm#n08044sasconfiguration0admin) in _SAS Viya for Linux: Deployment Guide_.
   - For information about the all the properties that can be used in sitedefault.yml, see [Configuration Properties: Reference (Services)](https://go.documentation.sas.com/?cdcId=calcdc&cdcVersion=3.3&docsetId=calconfig&docsetTarget=n08000sasconfiguration0admin.htm#!) in _SAS Viya Administration_.

    **CAUTION:**
  
    **Some properties require passwords.**<br/>
    If properties with passwords are specified in sitedefault.yml, you must secure the file appropriately. If you chose not to supply the properties in sitedefault.yml, then you can enter them using SAS Environment Manager. Sign in to SAS Environment Manager as sasboot, and follow the instructions in [Configure the Connection to Your Identity Provider](post-run-tasks#configure-the-connection-to-your-identity-provider).

1. When you are finished, save sitedefault.yml and make sure that it resides in the sas-container-recipes project directory.
When the build script is run, the data from the sitedefault.yml file will get added to the builds/full/manifests/kubernetes/configmaps/consul.yml file. On startup of the consul container, the content will get loaded into the SAS configuration store. See the post-run [(Optional) Verify Bulk Loaded Configuration](post-run-tasks#optional-verify-bulk-loaded-configuration) task for confirming the values provided were loaded.

### Kubernetes Manifest Inputs
To help with managing changes to the generated manifests, you can provide customizations that will be used when creating the Kubernetes manifests. In the `util/` directory there is a `manifests_usermods.yml` file. For your specific deployment, copy the `manifests_usermods.yml` file to the sas-container-recipes project directory and then edit the file. You can enter any of the following values and override the defaults:

```
# The directory where manifests will be created. Default is "manifests"
#SAS_MANIFEST_DIR: manifests

# The Kubernetes namespace that we are deploying into. Default is "sas-viya"
#SAS_K8S_NAMESPACE: sas-viya
```

In order to setup the Ingress paths correctly, update the following to the correct domain:

```
# Reflects the domain to use when filling in the ingress paths. Default is "company.com"
#SAS_K8S_INGRESS_DOMAIN: company.com
```

By default, the generated manifests will define a CAS SMP environment. If you want to define a CAS MPP environment initially, locate the following section in the manifests_usermods.yml file:

```
#custom_services:
#  sas-casserver-primary:
#    deployment_overrides:
#      environment:
#        - "CASCFG_MODE=mpp"
```

And, remove the preceding # for each line:

```
custom_services:
  sas-casserver-primary:
    deployment_overrides:
      environment:
        - "CASCFG_MODE=mpp"
```

After you save the file, CAS will start in MPP mode and a default of three CAS worker containers will start.

Custom volumes and volume mounts are also defined in the `custom_services` section. If the same set of volumes
and volume mounts are used across multiple services, they will need to be defined per service. This will add to
or replace defaults. The structure is that everything after the pipe '|' is added to the manifest. It is a
straight copy of what is provided to the generated manifest. For more information about Kubernetes Volumes,
see https://kubernetes.io/docs/concepts/storage/volumes/

Add entries specific to the desired storage type, using caution to preserve indentation relative to the
block above (e.g. `environment:`, `volumes:`, and `volume_mounts:` should align):

```
      volumes: |
        - name: volume_identifier
          nfs:
            server: nfs_server_hostname
            path: "/path_on_nfs_server/"
        - name: EBS-volume
          # This AWS EBS volume must already exist.
          awsElasticBlockStore:
            volumeID: <volume-id>
            fsType: ext4
      volume_mounts: |
        - name: volume_identifier
          mountPath: /path_inside_container
        - name: EBS-volume
          mountPath: /path_inside_container
```

**Note:** If customizing is not done prior to the build process, you can do it after the build to regenerate the manifests. For more information, see [(Optional) Regenerating Manifests](post-run-tasks#optional-regenerating-manifests).
