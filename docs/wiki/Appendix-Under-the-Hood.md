## Contents

- [Addons](#addons)
    - [access-greenplum](#access-greenplum)
    - [access-hadoop](#access-hadoop)
    - [access-odbc](#access-odbc)
    - [access-oracle](#access-oracle)
    - [access-pcfiles](#access-pcfiles)
    - [access-postgres](#access-postgres)
    - [access-redshift](#access-redshift)
    - [access-teradata](#access-teradata)
    - [auth-demo](#auth-demo)
    - [auth-sssd](#auth-sssd)
    - [ide-jupyter-python3](#ide-jupyter-python3)
- [Images](#images)
  - [SAS Viya Programming-Only Single Image](#sas-viya-programming-only-single-image)
  - [SAS Viya Programming-Only Multiple Images](#sas-viya-programming-only-multiple-images)
  - [SAS Viya Full Multiple Images](#sas-viya-full-multiple-images)

## Addons

The addons that you choose depends on your needs and the software that you have licensed. For some images, addons add content and create new versions of the images. 

### access-greenplum

- **Overview**

    Use the files in the addons/access-greenplum directory to smoke test SAS/ACCESS Interface to Greenplum.

    **Note:** To see a list of images that this addon modifies, see the addons/access-greenplum/addon_config.yml file.

- **Files**

    | **File Name** | **Purpose** |
    | --- | --- |
    | greenplum_sasserver.sh | The file contains environment variables that are required so that the Greenplum code executes properly. Update this file with your Greenplum client library version number. |
    | acgreenplum.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Foundation to confirm that SAS/ACCESS Interface to Greenplum is configured correctly. |
    | addon_config.yml | This file contains the data that maps the appropriate Dockerfile or Dockerfiles to the container that it needs to modify. |

- **How To Use**

    - SAS Studio

        1. [Log on to SAS Studio](validating#log-on-to-your-version-of-sas-studio).
        1. Paste the code from either acgreenplum.sas or dcgreenplum.sas into the code window.
        1. Edit the 'FIXME' text in acgreenplum.sas and dcgreenplum.sas with the correct values for the environment.
        1. Run the code.

    - SAS Batch Server

        1. Edit the 'FIXME' text in acgreenplum.sas and dcgreenplum.sas to include the correct values for the environment.
        1. From the parent directory, run the following command:
            ```
            docker run \
            --interactive \
            --tty \
            --rm \
            --volume ${PWD}/addons/access-greenplum:/sasinside \
            sas-viya-programming \
            --batch /sasinside/acgreenplum.sas
            ````

### access-hadoop

- **Overview**
    
    Use the files in the addons/access-hadoop directory to smoke test SAS/ACCESS Interface to Hadoop.

    Before you build an image with the access-hadoop addon, collect the Hadoop configuration files (/config) and JAR files (/jars), and add them to this directory: [sas-container-recipes/addons/access-hadoop/hadoop](hadoop/README.md). When the Hadoop configuration and JAR files are in this directory, the files are added to a /hadoop directory in an image that includes the access-hadoop addon. 

    Here is an example of the directory structure:

    ```
    sas-container-recipes/addons/access-hadoop/hadoop/config
    sas-container-recipes/addons/access-hadoop/hadoop/jars
    ```

    **Note:** To see a list of images that this addon modifies, see the addons/access-hadoop/addon_config.yml file.

- **Files**

    | **File Name** | **Purpose** |
    | --- | --- |
    | achadoop.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. The code expects the Hadoop configuration and JAR files to be available at /hadoop and uses SAS Foundation to confirm that SAS/ACCESS Interface to Hadoop is configured correctly. |
    | dchadoop.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. The code expects the Hadoop configuration and JAR files to be available at /hadoop and uses SAS Cloud Analytic Services to confirm that SAS Data Connector to Hadoop is configured correctly. |
    | addon_config.yml | This file contains the data that maps the appropriate Dockerfile or Dockerfiles to the container that it needs to modify. |

- **How To Use**

    **Note:** The achadoop.sas and dchadoop.sas tests assume that your Hadoop configuration and JAR files are located in the following location inside the container:

        - Configuration files: /hadoop/config
        - JAR files: /hadoop/jars

    - SAS Studio
        1. [Log on to SAS Studio](validating#log-on-to-your-version-of-sas-studio).
        1. Paste the code from either achadoop.sas or dchadoop.sas into the code window.
        1. Edit the 'FIXME' text in achadoop.sas and dchadoop.sas with the correct values for the environment.
        1. Edit the SAS_HADOOP_JAR_PATH and SAS_HADOOP_CONFIG_PATH to /hadoop/jars and /hadoop/config, respectively.
        1. Run the code.

    - SAS Batch Server
        1. Edit the 'FIXME' text in achadoop.sas and dchadoop.sas with the correct values for the environment.
        1. Edit the SAS_HADOOP_JAR_PATH and SAS_HADOOP_CONFIG_PATH to /hadoop/jars and /hadoop/config, respectively.  
        1. From the parent directory, run the following command:
            ```
            docker run \
            --interactive \
            --tty \
            --rm \
            sas-viya-programming \
            --batch /sasinside/achadoop.sas
            ```
### access-odbc

- **Overview**

    The content in this directory provides a simple way for smoke testing SAS/ACCESS Interface to ODBC.

    **Note:** To see a list of images that this addon modifies, see the addons/access-odbc/addon_config.yml file.

- **Files**

    | **File Name** | **Purpose** |
    | --- | --- |
    | odbc_cas.settings | This file contains environment variables that are required so that ODBC code is executed properly. |
    | odbc_sasserver.sh | This file contains environment variables that are required so that ODBC code is executed properly. |
    | acodbc.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Foundation to confirm that  SAS/ACCESS Interface to ODBC is configured correctly. |
    | dcodbc.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Cloud Analytic Services to validate that the SAS Data Connector to ODBC is configured correctly. |
    | addon_config.yml | This file contains the data that maps the appropriate Dockerfile or Dockerfiles to the container that it needs to modify. |

- **How To Use**

    - SAS Studio

        1. [Log on to SAS Studio](validating#log-on-to-your-version-of-sas-studio).
        1. Paste the code from either acodbc.sas or dcodbc.sas into the code window.
        1. Edit the 'FIXME' text in acodbc.sas and dcodbc.sas with the
  correct values for the environment.
        1. Run the code.

    - SAS Batch Server

        1. Edit the 'FIXME' text in acodbc.sas and dcodbc.sas to include the correct values for the environment.
        1. From the parent directory, run the following command:
            ```
            docker run \
            --interactive \
            --tty \
            --rm \
            --volume ${PWD}/addons/access-odbc:/sasinside \
            sas-viya-programming \
            --batch /sasinside/acodbc.sas
            ```

### access-oracle

- **Overview**

    The content in this directory provides a simple way for smoke testing 
SAS/ACCESS Interface to Oracle. A user must provide:

    - Oracle client library RPMs must be placed in this directory. The Dockerfile will attempt to install any RPMs in this directory.
    - A file named tnsnames.ora is expected in this directory.

    **Note:** To see a list of images that this addon modifies, see the addons/access-oracle/addon_config.yml file.

- **Files**

    | **File Name** | **Purpose** |
    | --- | --- |
    | oracle_cas.settings | This file contains environment variables that are required so that the Oracle code executes properly. Update this file with your Oracle client library version number. |
    | oracle_sasserver.sh | This file contains environment variables that are required so that the Oracle code executes properly. Update this file with your Oracle client library version number. |
    | acoracle.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table. The code uses SAS Foundation to validate that SAS/ACCESS Interface to Oracle is configured correctly. |
    | dcoracle.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table. The code uses SAS Cloud Analytic Services (CAS) to validate that the Data Connector to Oracle is configured correctly.   |
    | addon_config.yml | This file contains the data that maps the appropriate Dockerfile or Dockerfiles to the container that it needs to modify. |

- **How To Use**

    - SAS Studio

        1. [Log on to SAS Studio](validating#log-on-to-your-version-of-sas-studio).
        1. Paste the code from either acoracle.sas or dcoracle.sas into the code window.
        1. Edit the 'FIXME' text in acoracle.sas and dcoracle.sas with the correct values for the environment.
        1. Run the code.

    - SAS Batch Server

        1. Edit the 'FIXME' text in acoracle.sas and dcoracle.sas to include the correct values for the environment.
        1. From the parent directory, run the following command:
            ```
            docker run \
            --interactive \
            --tty \
            --rm \
            --volume ${PWD}/addons/access-oracle:/sasinside \
            sas-viya-programming \
            --batch /sasinside/acoracle.sas
            ```

### access-pcfiles

- **Overview**

    The content in this directory provides a simple way for smoke testing 
SAS/ACCESS Interface to PC Files.

    **Note:** To see a list of images that this addon modifies, see the addons/access-pcfiles/addon_config.yml file.

- **Files**

    | **File Name** | **Purpose** |
    | --- | --- |
    | acpcfiles.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates a table and writes its contents to file and uses SAS Foundation to confirm that  SAS/ACCESS Interface to PC Files is working. |
    | dcpcfiles.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates a table, write its contents to file, and then reads the file contents back into SAS Cloud Analytic Services (CAS). The code uses CAS to validate that the SAS Data Connector to PC Files is working. |
    | addon_config.yml | This file contains the data that maps the appropriate Dockerfile or Dockerfiles to the container that it needs to modify. |

- **How To Use**

    - SAS Studio

        1. [Log on to SAS Studio](validating#log-on-to-your-version-of-sas-studio).
        1. Paste the code from either acpcfiles.sas or dcpcfiles.sas into the code window.
        1. Run the code.

    - SAS Batch Server

        1. From the parent directory, run the following command:
            ```
            docker run \
            --interactive \
            --tty \
            --rm \
            --volume ${PWD}/pcfilesql:/sasinside \
            sas-viya-programming \
            --batch /sasinside/acpcfiles.sas
            ```

### access-postgres

- **Overview**

    The content in this directory provides a simple way for smoke testing 
SAS/ACCESS Interface to PostgreSQL.

    **Note:** To see a list of images that this addon modifies, see the addons/access-postgres/addon_config.yml file.

- **Files**

    | **File Name** | **Purpose** |
    | --- | --- |
    | acpostgres.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Foundation to confirm that SAS/ACCESS Interface to PostgreSQL is configured correctly. |
    | dcpostgres.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Cloud Analytic Services to confirm that the SAS Data Connector to PostgreSQL is configured correctly. |
    | addon_config.yml | This file contains the data that maps the appropriate Dockerfile or Dockerfiles to the container that it needs to modify. |

- **How To Use**

    - SAS Studio

        1. [Log on to SAS Studio](validating#log-on-to-your-version-of-sas-studio).
        1. Paste the code from either acpostgres.sas or dcpostgres.sas  into the code window.
        1. Edit the 'FIXME' text in acpostgres.sas and dcpostgres.sas with the correct values for the environment.
        1. Run the code.

    - SAS Batch Server

        1. Edit the 'FIXME' text in acpostgres.sas and dcpostgres.sas with the correct values for the environment.
        1. From the parent directory, run the following 
            ```
            docker run \
            --interactive \
            --tty \
            --rm \
            --volume ${PWD}/addons/access-postgres:/sasinside \
            viya-single-container \
            --batch /sasinside/acpostgres.sas
            ```

### access-redshift

- **Overview**

    The content in this directory provides a simple way for smoke testing 
SAS/ACCESS Interface to Amazon Redshift.

    **Note:** To see a list of images that this addon modifies, see the addons/access-redshift/addon_config.yml file.

- **Files**

    | **File Name** | **Purpose** |
    | --- | --- |
    | acredshift.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Foundation to confirm that SAS/ACCESS Interface to Amazon Redshift is configured correctly. |
    | dcredshift.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Cloud Analytic Services to confirm that SAS Data Connector to Amazon Redshift is configured correctly. |
    | addon_config.yml | This file contains the data that maps the appropriate Dockerfile or Dockerfiles to the container that it needs to modify. |

- **How To Use**

    - SAS Studio

        1. [Log on to SAS Studio](validating#log-on-to-your-version-of-sas-studio).
        1. Paste the code from either acredshift.sas or dcredshift.sas into the code window.
        1. Edit the 'FIXME' text in acredshift.sas and dcredshift.sas with the correct values for the environment.
        1. Run the code.

    - SAS Batch Server

        1. Edit the 'FIXME' text in  acredshift.sas and dcredshift.sas to include the correct values for the environment.
        1. From the parent directory, run the following command:
            ```
            docker run \
            --interactive \
            --tty \
            --rm \
            --volume ${PWD}/addons/access-redshift:/sasinside \
            sas-viya-programming \
            --batch /sasinside/acredshift.sas
            ```

### access-teradata

- **Overview**

    The content in this directory provides a simple way for smoke testing SAS/ACCESS Interface to Teradata.

    **Note:** To see a list of images that this addon modifies, see the addons/access-teradata/addon_config.yml file.

- **Files**

    | **File Name** | **Purpose** |
    | --- | --- |
    | terdata_cas.settings<br/>teradata_sasserver.sh | Files for SAS Cloud Analytic Services (CAS) and the SAS Workspace Server that are required to configure ODBC and Teradata libraries. |
    | acteradata.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Foundation to confirm that  SAS/ACCESS Interface to Teradata is configured correctly. |
    | dcteradata.sas | SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses CAS to confirm that the SAS Data Connector to Teradata is configured correctly. |
    | addon_config.yml | This file contains the data that maps the appropriate Dockerfile or Dockerfiles to the container that it needs to modify. |

- **How To Use**

    - SAS Studio

        1. [Log on to SAS Studio](validating#log-on-to-your-version-of-sas-studio).
        1. Paste the code from either acteradata.sas or dcteradata.sas into the code window.
        1. Edit the 'FIXME' text in acteradata.sas and dcteradata.sas to include the correct values for the environment.
        1. Run the code.

    - SAS Batch Server

        1. Edit the 'FIXME' text in acteradata.sas and dcteradata.sas to include the correct values for the environment.
        1. From the parent directory, run the following command:
            ```
            docker run \
            --interactive \
            --tty \
            --rm \
            --volume ${PWD}/addons/access-teradata:/sasinside \
            sas-viya-programming \
            --batch /sasinside/acteradata.sas
            ```

### auth-demo
- **Overview**

    This is an example about how to add a default user to a SAS Viya programming-only Docker image. The user created will also be used for the CAS Administrator and as the default user for running Jupyter Notebook if the _ide-jupyter-python3_ example is used.

    **Note:** To see a list of images that this addon modifies, see the addons/auth-demo/addon_config.yml file.

- **Files**

    | **File Name** | **Purpose** |
    | --- | --- |
    | demo_pre_deploy.sh  | A file that ends up in /tmp and will be run by the entrypoint in the script. This will create a user upon startup of the conainer.  |
    | addon_config.yml | This file contains the data that maps the appropriate Dockerfile or Dockerfiles to the container that it needs to modify. |

- **How To Use**

    When building the image, you can pass in the following arguments:

    | **Argument** | **Definition** | **Default** |
    | --- | --- | --- |
    | BASEIMAGE | Define the namespace and image name to build from | sas-viya-programming |
    | BASETAG | The verision of the image to build from | latest |
    | CASENV_ADMIN_USER | The user to create | sasdemo |
    | ADMIN_USER_PASSWD | The password of the user in plain text | sasdemo |
    | ADMIN_USER_HOME | The home directory of the user |  /home/${CASENV_ADMIN_USER} |
    | ADMIN_USER_UID | The unique id of the user | 1003 |
    | ADMIN_USER_GROUP | The group name to assign the user to. It matches the "sas" group created during the deployment. | sas |
    | ADMIN_USER_GID | The ID of the group to assign the user to. It matches the "sas" group created during the deployment. | 1001 |

    Here is an example that will create a user named _foo_ with a password of _bar_, a UID of _1010_ belonging to a group with name of _widget_ and a GID of _1011_.

    ```
    docker run \
    --detach \
    --rm \
    --env CASENV_CAS_VIRTUAL_HOST=$(hostname) \
    --env CASENV_CAS_VIRTUAL_PORT=8081 \
    --env CASENV_ADMIN_USER=foo \
    --env ADMIN_USER_PASSWD=bar \
    --env ADMIN_USER_UID=1010 \
    --env ADMIN_USER_GROUP=widget \
    --env ADMIN_USER_GID=1011 \
    --publish-all \
    --publish 8081:80 \
    --name svc-auth-demo \
    --hostname svc-auth-demo \
    svc-auth-demo
    ```

- **Caveats**
    * The `root` user must run the contents of script as it is creating users and groups on startup.

### auth-sssd
- **Overview**

    This addon will install and configure System Security Service Daemon (sssd) inside some of the images. This is a way to connect the container's authentication system via the pluggable authentication module (PAM) to systems like Lightweight Directory Access Protocol (LDAP) or Active Directory (AD).

    **Note:** To see a list of images that this addon modifies, see the addons/auth-sssd/addon_config.yml file.

    This addon does have support to create the user's home directory if it does not exist when a user logs into SAS Studio. However, if users need to persist content in their home directories (for example, SAS programs created from SAS Studio, or Jupyter playbooks), then it is advised to re-configure the containers so that the home directories are either :
    - mounted docker volumes when using the single image on Docker
    - persistent Volumes when using Kubernetes. 

- **Files**

    | **File Name** | **Purpose** |
    | --- | --- |
    | Dockerfile | Defines the packages that need to be installed and copies other files from this directory to the image. |
    | example_sssd.conf | A file that contains a template sssd configuration, which should reflect an organization's configuration. You need to provide a valid, tested, sssd.conf for this work. |
    | sssd_mkhomedir_helper.sh | When a users's home directory does not exist, this script will create one. |
    | sssd_pre_deploy.sh | A required file that starts sssd and is called by the main entrypoint script. |
    | addon_config.yml | This file contains the data that maps the appropriate Dockerfile or Dockerfiles to the container that it needs to modify. |

- **How To Use**

    This addon will expect that there is a file in `addons/auth-sssd` directory named `sssd.conf` that reflects the organization's configuration. If it is not supplied then the `docker build` will fail. If the sssd configuration requires a TLS cert, then this can be saved as a file name sssd.cert in the `addons/auth-sssd` directory.

    When the SAS Viya container entrypoint runs, it will run the `sssd_pre_deploy.sh` script which will will launch the sssd process.

- **Caveats**
    * The `root` user must run `/usr/sbin/sssd` process
    * The sssd process is not currently logging to stdout

### ide-jupyter-python3
- **Overview**

    This is an example of how to add Jupyter Notebook with Python 3 to a SAS Viya
programming-only Docker image.

    A prerequisite is that the SAS Viya programming-only Docker
image must have already been built. It is recommended to build this on top of an image
that has host authentication (auth-demo or auth-sssd) already added.

- **How To Use**

    When building the image, you can pass in the following arguments:

    | **Argument** | **Definition** | **Default** | **Valid Values** |
    | --- | --- | --- | --- |
    | BASEIMAGE |  Define the namespace and image name to build from | sas-viya-programming |  |
    | BASETAG | The verision of the image to build from | latest |  |
    | PLATFORM | The type of host that the software is being installed on | redhat | redhat, suse |
    | SASPYTHONSWAT | The version of [SAS Scripting Wrapper for Analytics Transfer (SWAT) package](https://github.com/sassoftware/python-swat) | 1.4.0 |
    | JUPYTER_TOKEN | The value of the token that the the notebook uses to authenticate requests. By default it is empty turning off authentication. | '' |
    | ENABLE_TERMINAL | Indicates if the terminal should be accessible by the notebook. By default it will be enabled. | True | True, False (case sensitive) |
    | ENABLE_NATIVE_KERNEL | Indicates if the python3 kernel should be accessible by the notebook. By default it will be enabled. | True | True, False (case sensitive) |

    Here is an example on how to run the image once it is built:

    ```
    docker run \
    --detach \
    --rm \
    --env CASENV_CAS_VIRTUAL_HOST=$(hostname) \
    --env CASENV_CAS_VIRTUAL_PORT=8081 \
    --publish-all \
    --publish 8081:80 \
    --name svc-ide-jupyter-python3 \
    --hostname svc-ide-jupyter-python3 \
    svc-ide-jupyter-python3
    ```

## Images
## SAS Viya Programming-Only Single Image

**Overview**

This image is built using a Dockerfile that will pull down the SAS Orchestration CLI to build the Ansible playbook and run it. When the resulting image is run it will have four main applications running inside it:
* httpd
* SAS Studio
* SAS Object Spawner
* Cloud Analytic Services (CAS)

There could be additional applications depending on your order.

**Details**

- **Run-time Targets** 
    - Docker
    - Kubernetes
- **Ports**
    - 80 for http via httpd
    - 443 for https via httpd
    - 5570 for CAS (only when run via Docker)
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | SETINIT_TEXT | The contents of the license file | |
    | CASENV_ADMIN_USER | The user that has admin permissions in CAS. | |
    | CASENV_CASDATADIR | The location where CAS will store data for things like path based caslibs | |
    | CASENV_CASPERMSTORE | The location where CAS will store access permissions for caslibs | |
    | CASCFG_ | An environment variable with this prefix translates to a cas. option which ends up in the casconfig_docker.lua file. These values are a predefined set and cannot be made up. If CAS sees an option that it does not understand, it will not run. | n/a |
    | CASENV_ | An environment variable with this prefix translates to a env. option which ends up in the casconfig_docker.lua. These values can be anything. | n/a |
    | CASSET_ | An environment variable with this prefix translates to an environment variable which ends up in cas_docker.settings. These values can be anything. | n/a |
    | CASLLP_ | An environment variable with this prefix translates to setting the LD_LIBRARY_PATH in cas_docker.settings. These values can be anything.| n/a |

- **Persistence**
    - Users that log into SAS Studio should have their home directories persisted
    - The `/cas/data` directory is a location that is scratch space on Disk for CAS to use. You will want to point this to a fast-enough filesystem. It is likely that by leaving it as the default, it would end up hitting one of the internal docker paths, which would have neither the speed nor the space required. 
    - The `/cas/permstore` directory is the location where CAS will store access permissions for caslibs. In this directory it will create a  folder based on the hostname. It is important to make sure the hostname is set the same way each time the container is run.
    - The `/cas/cache` directory is the location where CAS will cache data. The better solution for this would be to map multiple volumes to the container and set CASENV_CAS_DISK_CACHE to those mounted locations.
- **Caveats**
    - The entrypoint is running as `root`
    - The container will need some level of host authentication. The [auth-demo](#auth-demo) and [auth-sssd](#auth-sssd) provide examples of how this is supported. auth-demo will only allow one user/password combination to access the containers. so it's ok if you alone use the container. auth-sssd, once configured, allows multiple simultaneous users to access the applications. 
    - The container has multiple applications running in it
    - Some process that are started in support of the application will be owned by `root`.
    - The SAS Object Spawner will start SAS Workspace Server sessions for each user that logs into SAS Studio.

## SAS Viya Programming-Only Multiple Images
### httpproxy

**Overview**

Runs httpd and directs web traffic to _SAS Studio 4_ or _CAS Monitor_. Also Jupyter if that is part of the image.

**Details**

- **Run-time Targets** 
    - Kubernetes

- **Ports**
    - 80 for http via httpd
    - 443 for https via httpd

- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |

- **Persistence**
    - None
- **Caveats**
    - The entrypoint is running as `root`
    - httpd logs are not writing to stdout or stderr

### programming

**Overview**

Contains the following processes:
- SAS Studio 4
- SAS Object Spawner

There could be additional applications depending on your order.

**Details**

- **Run-time Targets** 
    - Kubernetes.
- **Ports**
    - 7080 for SAS Studio 4
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | SETINIT_TEXT | The contents of the license file | |

- **Persistence**
    - The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.
- **Caveats**
    - The entrypoint is running as `root`
    - The container will need some level of host authentication. The [auth-demo](#auth-demo) and [auth-sssd](#auth-sssd) provide examples of how this is supported. auth-demo will only allow one user/password combination to access the containers. so it's ok if you alone use the container. auth-sssd, once configured, allows multiple simultaneous users to access the applications. 
    - The container has multiple applications running in it
    - Some process that are started in support of the application will be owned by `root`.
    - The SAS Object Spawner will start SAS Workspace Server sessions for each user that logs into SAS Studio 4

### sas-casserver-primary

**Overview**

This runs Cloud Analytic Services (CAS). This image can be run as the controller or a worker. This will support Symmetric Multi Processing (SMP) and Massive Parallel Processing (MPP). By setting environment variables it will define how the image runs, controller or worker. This image is used in the cas and cas-worker deployment manifests.

**Details**

- **Run-time Targets** 
    - Kubernetes.
- **Ports**
    - 5570 is the binary port
    - 5571 is the grid control port
    - 8777 is the REST based port
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | SETINIT_TEXT | The contents of the license file | |
    | CASENV_ADMIN_USER | The user that has admin permissions in CAS. | |
    | CASENV_CASDATADIR | The location where CAS will store data for things like path based caslibs | |
    | CASENV_CASPERMSTORE | The location where CAS will store access permissions for caslibs | |
    | CASCFG_ | An environment variable with this prefix translates to a cas. option which ends up in the casconfig_docker.lua file. These values are a predefined set and cannot be made up. If CAS sees an option that it does not understand, it will not run. | n/a |
    | CASENV_ | An environment variable with this prefix translates to a env. option which ends up in the casconfig_docker.lua. These values can be anything. | n/a |
    | CASSET_ | An environment variable with this prefix translates to an environment variable which ends up in cas_docker.settings. These values can be anything. | n/a |
    | CASLLP_ | An environment variable with this prefix translates to setting the LD_LIBRARY_PATH in cas_docker.settings. These values can be anything.| n/a |

- **Persistence**
    - Users that log into SAS Studio 4 should have their home directories persisted
    - The `/cas/data` directory is a location that is scratch space on Disk for CAS to use. You will want to point this to a fast-enough filesystem. It is likely that by leaving it as the default, it would end up hitting one of the internal docker paths, which would have neither the speed nor the space required. 
    - The `/cas/permstore` directory is the location where CAS will store access permissions for caslibs. In this directory it will create a  folder based on the hostname. It is important to make sure the hostname is set the same way each time the container is run.
    - The `/cas/cache` directory is the location where CAS will cache data. The better solution for this would be to map multiple volumes to the container and set CASENV_CAS_DISK_CACHE to those mounted locations.
- **Caveats**
    - The entrypoint is running as `root`
    - The container will need some level of host authentication. The [auth-demo](#auth-demo) and [auth-sssd](#auth-sssd) provide examples of how this is supported. auth-demo will only allow one user/password combination to access the containers. so it's ok if you alone use the container. auth-sssd, once configured, allows multiple simultaneous users to access the applications. 
    - The container has multiple applications running in it
    - Some process that are started in support of the application will be owned by `root`.

## SAS Viya Full Multiple Images

The number of images in a viya-visuals build process can vary depending on ones order. The [General](#general) section will cover the information that is common to most of the images. Specific images are listed as they have specific information that is different than defined in the [General](#general) section.

### General

**Overview**

The images that fall in this category generally have two types of process running in them:
- micro-services
- SAS operational process

Each one of these images will have several micro-service processes running in them. The number can range from the single digits in to the twenties. In addition to the micro-services, there are SAS operational components that are running as well these cover:
- Consul agent
- SAS operations agent
- SAS Log Watcher
- SAS Alert agent

Processes running in these containers will pick an ephemeral port and register in Consul running in the consul pod. As services register, a process in the httpproxy pod will update the proxy.conf file and restart the httpd service. Service discover each other by querying Consul running in the consul pod.

**Details**

- **Run-time Targets** 
    - Kubernetes
- **Ports**
    * None are exposed
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | CONSUL_SERVER_LIST | The Consul server list. This will point to the Consul service. | sas-viya-consul |
    | CONSUL_DATACENTER_NAME | Unique id inside Consul to which data is linked | viya |
    | CONSUL_TOKENS_CLIENT | A unique string value that allows clients to connect to Consul and read and write date | tobeusedfordemosonlyclnt |
    | CONSUL_TOKENS_ENCRYPTION | Allows Consul agents to encrypt data all of its network traffic | 9eV9uJXG0r8o3xTDH6+ykg== |

- **Persistence**
    * The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.
- **Caveats**
    * The entrypoint is running as `root`
    * The container has multiple applications running in it. This can range from single digits into the twenties.

### computeserver

**Overview**

This container contains the runlauncher and the SAS Compute Server. The runlauncher will launch Compute Server processes as the are requested. The processes are owned by users that launch SAS Studio V or other applications in SAS Viya.

In addition to the CAS process running, there are SAS operational components that are running as well:
- Consul agent
- SAS operations agent
- SAS Log Watcher
- SAS Alert agent

**Details**

- **Run-time Targets** 
    - Kubernetes.
- **Ports**
    - 5600 for the runlauncher
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | SETINIT_TEXT | The contents of the license file | |
    | CONSUL_SERVER_LIST | The Consul server list. This will point to the Consul service. | sas-viya-consul |
    | CONSUL_DATACENTER_NAME | Unique id inside Consul to which data is linked | viya |
    | CONSUL_TOKENS_CLIENT | A unique string value that allows clients to connect to Consul and read and write date | tobeusedfordemosonlyclnt |
    | CONSUL_TOKENS_ENCRYPTION | Allows Consul agents to encrypt data all of its network traffic | 9eV9uJXG0r8o3xTDH6+ykg== |

- **Persistence**
    - The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.
- **Caveats**
    - The entrypoint is running as `root`
    - The container will need some level of host authentication. The [auth-demo](#auth-demo) and [auth-sssd](#auth-sssd) provide examples of how this is supported. auth-demo will only allow one user/password combination to access the containers. so it's ok if you alone use the container. auth-sssd, once configured, allows multiple simultaneous users to access the applications. 
    - The container has multiple applications running in it
    - Some process that are started in support of the application will be owned by `root`.
    - The runlauncher will start SAS Compute Server sessions for each user that logs into SAS Studio V

### consul

**Overview**

Runs Consul which supports service discovery and storing key/values.

In addition to the httpd process running, there are SAS operational components that are running as well:
- SAS operations agent
- SAS Log Watcher
- SAS Alert agent

**Details**

- **Run-time Targets** 
    - Kubernetes.
- **Ports**
    - 8300
    - 8301
    - 8302
    - 8400
    - 8500
    - 8501
    - 8600
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | CONSUL_BOOTSTRAP_EXPECT | How many Consul servers to expect in the cluster | 1 |
    | CONSUL_CLIENT_ADDRESS | The address to which Consul will bind client interfaces | 0.0.0.0 | 
    | CONSUL_DATA_DIR | The location to store Consul data | /consul/data |
    | CONSUL_KEY_VALUE_DATA_ENC | base64 encoded data to load on the initial start up. | |
    | CONSUL_SERVER_FLAG | Boolean indicating if this is a Consul server or agent | true |
    | CONSUL_UI_FLAG | Boolean indicating if the Consul UI should be enabled | false |
    | CONSUL_DATACENTER_NAME | Unique id inside Consul to which data is linked | viya |
    | CONSUL_TOKENS_CLIENT | A unique string value that allows clients to connect to Consul and read and write date | tobeusedfordemosonlyclnt |
    | CONSUL_TOKENS_ENCRYPTION | Allows Consul agents to encrypt data all of its network traffic | 9eV9uJXG0r8o3xTDH6+ykg== |
    | CONSUL_TOKENS_MANAGEMENT | Used for bootstrapping the Conul environment | tobeusedfordemosonlymgmt |

- **Persistence**
    * The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.
- **Caveats**
    * The entrypoint is running as `root`

### httpproxy

**Overview**

Runs httpd and directs web traffic to _SAS Studio 4_ or _CAS Monitor_. Also Jupyter if that is part of the image.

In addition to the httpd process running, there are SAS operational components that are running as well:
- Consul agent
- SAS operations agent
- SAS Log Watcher
- SAS Alert agent

**Details**

- **Run-time Targets** 
    - Kubernetes
- **Ports**
    - 80 for http via httpd
    - 443 for https via httpd
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | CONSUL_SERVER_LIST | The Consul server list. This will point to the Consul service. | sas-viya-consul |
    | CONSUL_DATACENTER_NAME | Unique id inside Consul to which data is linked | viya |
    | CONSUL_TOKENS_CLIENT | A unique string value that allows clients to connect to Consul and read and write date | tobeusedfordemosonlyclnt |
    | CONSUL_TOKENS_ENCRYPTION | Allows Consul agents to encrypt data all of its network traffic | 9eV9uJXG0r8o3xTDH6+ykg== |

- **Persistence**
    - The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.
- **Caveats**
    - The entrypoint is running as `root`
    - As the services register with Consul running in the consul pod, httpd will restart. It will not stop the container.
    - httpd logs are not writing to stdout or stderr

### operations

**Overview**

Runs the SAS Operations server process.

In addition to the SAS Operations server process running, there are SAS operational components that are running as well:
- Consul agent
- SAS operations agent
- SAS Log Watcher
- SAS Alert agent

**Details**

- **Run-time Targets** 
    - Kubernetes.
- **Ports**
    - none exposed
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | SAS_CLIENT_CERT | The contents of the entitlement_certificate.pem file from the SAS Software Order Email | |
    | SAS_CA_CERT | The contents of the SAS_CA_Certificate.pem file from the SAS Software Order Email | |
    | SAS_LICENSE | The contents of the SASViyaV0300*.jwt file from the SAS Software Order Email | |
    | SETINIT_TEXT | The contents of the license file | |
    | CONSUL_SERVER_LIST | The Consul server list. This will point to the Consul service. | sas-viya-consul |
    | CONSUL_DATACENTER_NAME | Unique id inside Consul to which data is linked | viya |
    | CONSUL_TOKENS_CLIENT | A unique string value that allows clients to connect to Consul and read and write date | tobeusedfordemosonlyclnt |
    | CONSUL_TOKENS_ENCRYPTION | Allows Consul agents to encrypt data all of its network traffic | 9eV9uJXG0r8o3xTDH6+ykg== |

- **Persistence**
    - The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.
- **Caveats**
    - The entrypoint is running as `root`

### pgpoolc

**Overview**

Runs pgpool II.

In addition to pgpool II running, there are SAS operational components that are running as well:
- Consul agent
- SAS operations agent
- SAS Log Watcher
- SAS Alert agent

**Details**

- **Run-time Targets** 
    - Kubernetes.
- **Ports**
    - 5431
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | SASPOSTGRESDBSIZE| Defines what set of configurations should be used| large |
    | PG_VOLUME | Where to write data | /database/data |
    | SAS_DEFAULT_PGPWD | The password for the SAS database user | ChangePassword |
    | SASPOSTGRESREPLPWD | The password for the replication user | ChangePassword |
    | SAS_DATAMINING_PASSWORD | The password for the SAS Data Mining Warehouse user | ChangePassword |
    | CONSUL_SERVER_LIST | The Consul server list. This will point to the Consul service. | sas-viya-consul |
    | CONSUL_DATACENTER_NAME | Unique id inside Consul to which data is linked | viya |
    | CONSUL_TOKENS_CLIENT | A unique string value that allows clients to connect to Consul and read and write date | tobeusedfordemosonlyclnt |
    | CONSUL_TOKENS_ENCRYPTION | Allows Consul agents to encrypt data all of its network traffic | 9eV9uJXG0r8o3xTDH6+ykg== |

- **Persistence**
    - The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.
- **Caveats**
    - The entrypoint is running as `root`

### programming

**Overview**

Contains the following processes:
- SAS Studio 4
- SAS Object Spawner

There could be additional applications depending on your order.

In addition to SAS Studio 4 and SAS Object Spawner running, there are SAS operational components that are running as well:
- Consul agent
- SAS operations agent
- SAS Log Watcher
- SAS Alert agent

**Details**

- **Run-time Targets** 
    - Kubernetes.
- **Ports**
    - 7080 for SAS Studio 4
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | SETINIT_TEXT | The contents of the license file | |
    | CONSUL_SERVER_LIST | The Consul server list. This will point to the Consul service. | sas-viya-consul |
    | CONSUL_DATACENTER_NAME | Unique id inside Consul to which data is linked | viya |
    | CONSUL_TOKENS_CLIENT | A unique string value that allows clients to connect to Consul and read and write date | tobeusedfordemosonlyclnt |
    | CONSUL_TOKENS_ENCRYPTION | Allows Consul agents to encrypt data all of its network traffic | 9eV9uJXG0r8o3xTDH6+ykg== |

- **Persistence**
    - The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.
- **Caveats**
    - The entrypoint is running as `root`
    - The container will need some level of host authentication. The [auth-demo](#auth-demo) and [auth-sssd](#auth-sssd) provide examples of how this is supported. auth-demo will only allow one user/password combination to access the containers. so it's ok if you alone use the container. auth-sssd, once configured, allows multiple simultaneous users to access the applications. 
    - The container has multiple applications running in it
    - Some process that are started in support of the application will be owned by `root`.
    - The SAS Object Spawner will start SAS Workspace Server sessions for each user that logs into SAS Studio 4

### rabbitmq

**Overview**

Runs RabbitMQ.

In addition to RabbitMQ running, there are SAS operational components that are running as well:
- Consul agent
- SAS operations agent
- SAS Log Watcher
- SAS Alert agent

**Details**

- **Run-time Targets** 
    - Kubernetes.
- **Ports**
    - 5672
    - 15672
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | SETINIT_TEXT | The contents of the license file | |
    | CONSUL_SERVER_LIST | The Consul server list. This will point to the Consul service. | sas-viya-consul |
    | CONSUL_DATACENTER_NAME | Unique id inside Consul to which data is linked | viya |
    | CONSUL_TOKENS_CLIENT | A unique string value that allows clients to connect to Consul and read and write date | tobeusedfordemosonlyclnt |
    | CONSUL_TOKENS_ENCRYPTION | Allows Consul agents to encrypt data all of its network traffic | 9eV9uJXG0r8o3xTDH6+ykg== |

- **Persistence**
    - The `/rabbitmq/data` directory for persisting queue data.
    - The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.
- **Caveats**
    - The entrypoint is running as `root`

### sas-casserver-primary

**Overview**

This runs Cloud Analytic Services (CAS). This image can be run as the controller or a worker. This will support Symmetric Multi Processing (SMP) and Massive Parallel Processing (MPP). By setting environment variables it will define how the image runs, controller or worker. This image is used in the cas and cas-worker deployment manifests.

In addition to the CAS process running, there are SAS operational components that are running as well:
- Consul agent
- SAS operations agent
- SAS Log Watcher
- SAS Alert agent

**Details**

- **Run-time Targets** 
    - Kubernetes.

- **Ports**
    - 5570 is the binary port
    - 5571 is the grid control port
    - 8777 is the REST based port

- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | SETINIT_TEXT | The contents of the license file | |
    | CASENV_ADMIN_USER | The user that has admin permissions in CAS. | |
    | CASENV_CASDATADIR | The location where CAS will store data for things like path based caslibs | |
    | CASENV_CASPERMSTORE | The location where CAS will store access permissions for caslibs | |
    | CASCFG_ | An environment variable with this prefix translates to a cas. option which ends up in the casconfig_docker.lua file. These values are a predefined set and cannot be made up. If CAS sees an option that it does not understand, it will not run. | n/a |
    | CASENV_ | An environment variable with this prefix translates to a env. option which ends up in the casconfig_docker.lua. These values can be anything. | n/a |
    | CASSET_ | An environment variable with this prefix translates to an environment variable which ends up in cas_docker.settings. These values can be anything. | n/a |
    | CASLLP_ | An environment variable with this prefix translates to setting the LD_LIBRARY_PATH in cas_docker.settings. These values can be anything.| n/a |
    | CONSUL_SERVER_LIST | The Consul server list. This will point to the Consul service. | sas-viya-consul |
    | CONSUL_DATACENTER_NAME | Unique id inside Consul to which data is linked | viya |
    | CONSUL_TOKENS_CLIENT | A unique string value that allows clients to connect to Consul and read and write date | tobeusedfordemosonlyclnt |
    | CONSUL_TOKENS_ENCRYPTION | Allows Consul agents to encrypt data all of its network traffic | 9eV9uJXG0r8o3xTDH6+ykg== |

- **Persistence**
    - The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.
    - Users that log into SAS Studio 4 should have their home directories persisted
    - The `/cas/data` directory is a location that is scratch space on Disk for CAS to use. You will want to point this to a fast-enough filesystem. It is likely that by leaving it as the default, it would end up hitting one of the internal docker paths, which would have neither the speed nor the space required. 
    - The `/cas/permstore` directory is the location where CAS will store access permissions for caslibs. In this directory it will create a  folder based on the hostname. It is important to make sure the hostname is set the same way each time the container is run.
    - The `/cas/cache` directory is the location where CAS will cache data. The better solution for this would be to map multiple volumes to the container and set CASENV_CAS_DISK_CACHE to those mounted locations.

- **Caveats**
    - The entrypoint is running as `root`
    - The container will need some level of host authentication. The [auth-demo](#auth-demo) and [auth-sssd](#auth-sssd) provide examples of how this is supported. auth-demo will only allow one user/password combination to access the containers. so it's ok if you alone use the container. auth-sssd, once configured, allows multiple simultaneous users to access the applications. 
    - The container has multiple applications running in it
    - Some process that are started in support of the application will be owned by `root`.

### sasdatasvrc

**Overview**

Runs the SAS Database Server process. 

In addition to the SAS Database Server process running, there are SAS operational components that are running as well:
- Consul agent
- SAS operations agent
- SAS Log Watcher
- SAS Alert agent

**Details**

- **Run-time Targets** 
    - Kubernetes.
- **Ports**
    - 5432
- **Environment Variables**

    | **Variable** | **Purpose** | **Default Value** |
    | --- | --- | --- |
    | SAS_DEBUG | Enables `set -x` in the entrypoint | |
    | DEPLOYMENT_NAME | The name of the overall project | sas-viya |
    | SASPOSTGRESDBSIZE| Defines what set of configurations should be used| large |
    | PG_VOLUME | Where to write data | /database/data |
    | SAS_DEFAULT_PGPWD | The password for the SAS database user | ChangePassword |
    | SASPOSTGRESREPLPWD | The password for the replication user | ChangePassword |
    | SAS_DATAMINING_PASSWORD | The password for the SAS Data Mining Warehouse user | ChangePassword |
    | CONSUL_SERVER_LIST | The Consul server list. This will point to the Consul service. | sas-viya-consul |
    | CONSUL_DATACENTER_NAME | Unique id inside Consul to which data is linked | viya |
    | CONSUL_TOKENS_CLIENT | A unique string value that allows clients to connect to Consul and read and write date | tobeusedfordemosonlyclnt |
    | CONSUL_TOKENS_ENCRYPTION | Allows Consul agents to encrypt data all of its network traffic | 9eV9uJXG0r8o3xTDH6+ykg== |

- **Persistence**
    - The `/database/data` directory is where data will be written to. This is the backend storage for the micro-services.
    - The `/opt/sas/viya/config/var/log` directory is where processes will write their logs to. It is recommended to save these logs off so that if Kubernetes pods restart that the logs can provide information to understand why.

- **Caveats**
    - The entrypoint is running as `root`
