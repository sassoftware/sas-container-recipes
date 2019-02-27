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

## Obtain the Required Files

1. Locate your SAS Viya for Linux Software Order Email (SOE) and the SAS_Viya_deployment_data.zip file attachment.

1. Perform one of the following tasks to get the project files:
    
    - Download the latest release at [https://github.com/sassoftware/sas-container-recipes/releases](https://github.com/sassoftware/sas-container-recipes/releases).

    - Run the following command: `git clone git@github.com:sassoftware/sas-container-recipes.git`

## Create a Mirror

A local mirror repository can save you time each time you run a build, and it protects you from download limits.

Each time that you build an image of the SAS Viya software, the required RPM files must be accessed. Setting up a local mirror repository for the RPM files can save time because you access the RPM files locally each time that you build or rebuild an image. If you do create a local mirror repository, then the RPM files are downloaded from servers that are hosted by SAS, which can take longer. Also, there is a limit to how many times that you can download a SAS Viya software order from the SAS servers.

For more information about creating a local mirror repository, see [Create a Mirror Repository](https://go.documentation.sas.com/?docsetId=dplyml0phy0lax&amp;docsetTarget=p1ilrw734naazfn119i2rqik91r0.htm&amp;docsetVersion=3.4) in the _SAS Viya for Linux: Deployment Guide_.

## Use a Docker Registry

**Note:** If you use Kubernetes as your deployment tool, you must follow these steps. Otherwise, for Docker, the following steps are optional.

A registry is a storage and content delivery system that contains Docker images, which are available in different versions, with each image having its own tag. Self-hosting a registry makes it easy to share images internally. For more information about the Docker registry, see [https://docs.docker.com/registry/introduction/](https://docs.docker.com/registry/introduction/).

The build process will use ansible-container to push the built images to the Docker registry provided. To do this, the `$HOME/.docker/config.json` file must contain the Docker registry URL and an auth value. These settings allow ansible-container to connect to the Docker registry.

To update the `$HOME/.docker/config.json` file, run the following command: 

`docker login <docker registry>`

After you run the command, validate that the `$HOME/.docker/config.json` file contains the expected Docker registry URL and auth value. 

Here is an example that shows the settings:

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

You can use addons to include extra components in your SAS Viya images. There are addons for authentication, data sources, and integrated development environments (IDE). Only the addons that require pre-build tasks are listed in this section. You can find the addons in this directory: 

`sas-container-recipes/addons`

For more information, see [Addons](https://gitlab.sas.com/sassoftware/sas-container-recipes/wikis/Appendix:-Under-the-Hood#addons).

### Host Authentication

Some SAS Viya containers require host level authentication: the single programming-only container and the multiple containers programming-only Compute Server and CAS containers. Use the addons prefixed with _auth_ to set up host authentication.

#### sssd Authentication

Copy the `sas-container-recipes/addons/example_sssd.conf` file to a file named _sssd.conf_. Then edit the sssd.conf file and fill in the desired configuration. If a SSL cert is needed, provide it as a file named _sssd.cert_.

```
cp sas-container-recipes/addons/auth-sssd/example_sssd.conf sas-container-recipes/addons/auth-sssd/sssd.conf
vi sas-container-recipes/addons/auth-sssd/sssd.conf
```

### Data Sources

This section provides pre-build tasks for some of the access addons that provide data access for SAS Viya. Only the access addons that require pre-build tasks are listed in this section. 

#### Greenplum

Before you can use the access-greenplum addon, confirm that the environment variables in the _greenplum_saserver.sh_ will represent where ODBC configurations will live. The default configuration expects that ODBC configuration files will be available in the directory `/sasinside`. For single containers running on Docker, this directory is mapped automatically directly to the running container from the Docker host. If running on kubernetes, `/sasinside`, or a preferred directory used should be mapped to the _sas-viya-programming_, _sas-viya-computeserver_ and _sas-viya-sas-casserver-primary_ pods. 

```
export ODBCSYSINI=/sasinside/odbc
export ODBCINI=${ODBCSYSINI}/odbc.ini
export ODBCINSTINI=${ODBCSYSINI}/odbcinst.ini
export LD_LIBRARY_PATH=${ODBCSYSINI}/lib:$LD_LIBRARY_PATH
```

If this location needs to change, make sure to update _greenplum_saserver.sh_ before building the images.

#### Hadoop

Before you can use the access-hadoop addon, collect the Hadoop configuration files (/config) and JAR files (/jars), and add them to this directory: 

`sas-container-recipes/addons/access-hadoop/hadoop`

When the Hadoop configuration and JAR files are in this directory, the files are added to a /hadoop directory in an image that includes the access-hadoop addon.

Here is an example of the directory structure:

```
sas-container-recipes/addons/access-hadoop/hadoop/config
sas-container-recipes/addons/access-hadoop/hadoop/jars
```

#### ODBC

Before you can use the access-odbc addon, confirm that the environment variables in the _odbc_cas.settings_ and _odbc_saserver.sh_ will represent where ODBC configurations will live. The default configuration expects that ODBC configuration files will be available in the directory `/sasinside`. For single containers running on Docker, this directory is mapped automatically directly to the running container from the Docker host. If running on kubernetes, `/sasinside`, or a preferred directory used should be mapped to the _sas-viya-programming_, _sas-viya-computeserver_ and _sas-viya-sas-casserver-primary_ pods.

```
export ODBCSYSINI=/sasinside/odbc
export ODBCINI=${ODBCSYSINI}/odbc.ini
export ODBCINSTINI=${ODBCSYSINI}/odbcinst.ini
export LD_LIBRARY_PATH=${ODBCSYSINI}/lib:$LD_LIBRARY_PATH
```

If this location needs to change, make sure to update _odbc_cas.settings_ and _odbc_saserver.sh_ before building the images.

#### Oracle

Before you can use the access-oracle addon, add the Oracle client library RPMs and a file named tnsnames.ora in the following directory:

`sas-container-recipes/addons/access-oracle`

Confirm that the environment variables in the _oracle_cas.settings_ and _oracle_saserver.sh_ represent where the Oracle configuration exists. If not, update these files. The default configuration expects that Oracle files will be available from within the image.

**Note:** The Dockerfile will attempt to install any RPMs in this directory.

#### Redshift

Before you can use the access-redshift addon, confirm that the environment variables in the _redshift_cas.settings_ and _redshift_saserver.sh_ will represent where ODBC configurations will live. The default configuration expects that ODBC configuration files will be available in the directory `/sasinside`. For single containers running on Docker, this directory is mapped automatically directly to the running container from the Docker host. If running on kubernetes, `/sasinside`, or a preferred directory used should be mapped to the _sas-viya-programming_, _sas-viya-computeserver_ and _sas-viya-sas-casserver-primary_ pods. 

```
export ODBCSYSINI=/sasinside/odbc
export ODBCINI=${ODBCSYSINI}/odbc.ini
export ODBCINSTINI=${ODBCSYSINI}/odbcinst.ini
export LD_LIBRARY_PATH=${ODBCSYSINI}/lib:$LD_LIBRARY_PATH
```

If this location needs to change, make sure to update _redshift_cas.settings_ and _redshift_saserver.sh_ before building the images.

#### Teradata

Before you can use the access-teradata addon you need to get the compressed zip file that contains the Teradata Tools and Utilities. Once you have this file, rename it to _teradata.tgz_ and place it in `sas-container-recipes/addons/access-teradata/`. The Dockerfile expects that the teradata.tgz file is in the current directory and has the following structure:

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
In order to access SAS, we need to expose endpoints that allow things outside the Kubernetes environment to talk to the correct endpoints inside the Kubernetes environment. While this can be done different ways, the trend is to use an Ingress Controller. We will not cover how to set up the Ingress Controller but will provide how to setup a specific Ingress configuration to expose the proper endpoints for the SAS containers. We are doing this now as it is an expected value when running the build utility. 

In the _samples_ directory we have the following structure:

```
samples
├── viya-multi-container
│   └── example_ingress.yml
├── viya-single-container
│   ├── example_ingress.yml
│   ├── example_launchsas.sh
│   └── example_programming.yml
└── viya-visuals
    └── example_ingress.yml
```

Find the _*_ingress.yml_ file that matches your deployment type, copy and edit:

```
mkdir ${PWD}/run
cp samples/viya-visuals/example_ingress.yml ${PWD}/run/visuals_ingress.yml
vi ${PWD}/run/visuals_ingress.yml
```

In the copy, _visuals_ingress.yml_, find all occurrences of _@REPLACE_ME_WITH_YOUR_K8S_NAMESPACE@_ and _@REPLACE_ME_WITH_YOUR_DOMAIN@_ with appropriate values. Here is an example

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
  name: sas-viya-visuals-ingress
  namespace: sasviya
spec:
  rules:
  - host: sas-viya.company.com
    http:
      paths:
      - backend:
          serviceName: sas-viya-httpproxy
          servicePort: 80
#  tls:
#  - hosts:
#    - sas-viya.company.com
#    secretName: @REPLACE_ME_WITH_YOUR_CERT@
```

TLS is setup by configuring the Ingress definition. For more information, see [TLS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls). You will need to create a key and cert and store it in a Kubernetes secret. For the purpose of the example, we will call the secret _sas-tls-secret_. Once that is in place, update `${PWD}/run/visuals_ingress.yml` and change the `tls` section so that it looks like

```
  tls:
  - hosts:
    - sas-viya.company.com
    secretName: sas-tls-secret
```

Load the configuration:

```
kubectl -n sasviya apply -f samples/viya-visuals/visuals_ingress.yml
```

If you are not in a position to set this up yet, you can continue on with the deployment process, but the ingress will need to be configured in order to access the environment.

In later documentation, the term _ingress-path_ will refer to the _host_ value in your Ingress configuration. From the example above this would be _sas-viya.company.com_. 

### Persistence

Several of the SAS Viya containers will need persistence storage configured in order to make sure the environment can shutdown and start up with out losing data. Take this time to decide if persistence storage is something that needs to be setup or if you want to run with a default of no persistence. The default is useful if you are evaluating SAS Viya containers, otherwise you will probably want to make sure your Kuberenetes environment is configured for container persistence. For more information, see [Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/). 

### Data Import

When importing data into SAS Viya, the import might fail without displaying an error or having written an error to CAS logs. This failure to import data can happen if the size of the file being imported exceeds the maximum size allowed by the Kubernetes Ingress Controller. 

To change the Ingress controller settings, globally or for the specific Ingress rule, see [NGINX Configuration](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/).

SAS has tested using the `nginx.ingress.kubernetes.io/proxy-body-size` annotation as documented for `Custom max body size`. For more information, see [Custom max body size](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/#custom-max-body-size).

If you know the size of files to be imported, then set _Custom max body size_ to a value that will allow the files to be loaded. If a value of zero (0) is used, then checking of the file size is ignored, and no file size restrictions will be imposed by Kubernetes.