# Overview

The content in this directory provides a simple way for smoke testing SAS/ACCESS Interface to Hadoop.

# File List

* achadoop.sas
    * SAS code that can be submitted in SAS Studio or by the SAS batch server.
	  The code expects the Hadoop configuration and JAR files to be available at /sasinside/hadoop and uses SAS Foundation to confirm that SAS/ACCESS Interface to Hadoop is configured correctly.
* dchadoop.sas
    * SAS code that can be submitted in SAS Studio or by the SAS batch server.
	  The code expects the Hadoop configuration and JAR files to be available at /sasinside/hadoop and uses SAS Cloud Analytic Services to confirm that SAS Data Connector to Hadoop is configured correctly.

# (Optional) How to Build

**Note:** Although this step is not required, it is helpful to collect the Hadoop configuration
and JAR files in a volume and mount them to the container upon start-up.

To create an image that includes the Hadoop configuration and JAR files:

Collect the files and copy them to the /hadoop directory. Here is an example:

```
${PWD}/hadoop/config
${PWD}/hadoop/jars
```

Build the image:

```
docker build --file Dockerfile . --tag svc-access-hadoop
```

The files are added to the /hadoop directory. You will want to use
the achadoop_internal.sas and dchadoop_internal.sas when testing.

# How to Use

The achadoop.sas and dchadoop.sas test code work under
the assumption that your Hadoop configuration and JAR files are located in the following
location inside the container:

* Configuration files: /sasinside/hadoop/config
* JAR files: /sasinside/hadoop/jars

## SAS Studio

1. Log on to SAS Studio http://_host-name-where-docker-is-running_:8081
2. Paste the code from either achadoop.sas or dchadoop.sas into the code
   window.
3. Edit the 'FIXME' text in achadoop.sas and dchadoop.sas with the
   correct values for the environment.
4. Run the code.

Here is an example of a log with no errors:

```
 1          OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 72
 73         %let server="FIXME";
 74         %let user=FIXME;
 75
 76         option set = SAS_HADOOP_JAR_PATH =
 77           "/sasinside/hadoop/jars";
 78         option set = SAS_HADOOP_CONFIG_PATH =
 79           "/sasinside/hadoop/config";
 80
 81         libname hadoop hadoop server=&server.  user=&user;
 NOTE: HiveServer2 High Availability via ZooKeeper will not be used for this connection. Specifying the SERVER= or PORT= libname
       option overrides configuration properties.
 NOTE: Libref HADOOP was successfully assigned as follows:
       Engine:        HADOOP
       Physical Name: jdbc:hive2://FIXME:10000/default
 82
 83         proc datasets lib=hadoop;
 84           run;

 85
 86
 87         OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 100
```

## SAS Batch Server

1. Edit the 'FIXME' text in achadoop.sas and dchadoop.sas with the
  correct values for the environment.
2. From the parent directory, run the following command:

```
docker run --interactive --tty --rm --volume ${PWD}/addons/access-hadoop:/sasinside svc-access-hadoop --batch /sasinside/achadoop.sas
[INFO] : CASENV_CAS_VIRTUAL_HOST is ''
[INFO] : CASENV_CAS_VIRTUAL_PORT is ''
[INFO] : CASENV_ADMIN_USER is 'cas'
removed '/opt/sas/viya/config/etc/cas/default/start.d/05updateperms_startup.lua'
Running "--batch /sasinside/achadoop.sas"
Starting Cloud Analytic Services...
CAS Consul Health:
    Consul not present
    CAS bypassing Consul serfHealth status check of CAS nodes

/sasinside /tmp
sourcing /opt/sas/viya/config/etc/sysconfig/sas-javaesntl/sas-java

'achadoop.log' -> 'achadoop_20181003183852.log'
1                                                          The SAS System                    Wednesday, October  3, 2018 06:38:00 PM

NOTE: Copyright (c) 2016 by SAS Institute Inc., Cary, NC, USA.
NOTE: SAS (r) Proprietary Software V.03.04 (TS4M0 MBCS3170)
      Licensed to Full order for testing access engines, Site 70180938.
NOTE: This session is executing on the Linux 4.14.71-1-MANJARO (LIN X64) platform.



NOTE: Analytical products:

      SAS/STAT 14.3
      SAS/ETS 14.3
      SAS/OR 14.3
      SAS/IML 14.3
      SAS/QC 14.3

NOTE: Additional host information:

 Linux LIN X64 4.14.71-1-MANJARO #1 SMP PREEMPT Thu Sep 20 05:29:20 UTC 2018 x86_64 CentOS Linux release 7.5.1804 (Core)

NOTE: SAS initialization used:
      real time           0.03 seconds
      cpu time            0.02 seconds


NOTE: AUTOEXEC processing beginning; file is /opt/sas/viya/config/etc/batchserver/default/autoexec.sas.


NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.01 seconds



NOTE: AUTOEXEC processing completed.

1          %let server="FIXME";
2          %let user=FIXME;
3
4          option set = SAS_HADOOP_JAR_PATH =
5            "/sasinside/hadoop/jars";
6          option set = SAS_HADOOP_CONFIG_PATH =
7            "/sasinside/hadoop/config";
8
9          libname hadoop hadoop server=&server.  user=&user;
NOTE: HiveServer2 High Availability via ZooKeeper will not be used for this connection. Specifying the SERVER= or PORT= libname
      option overrides configuration properties.
NOTE: Libref HADOOP was successfully assigned as follows:
      Engine:        HADOOP
      Physical Name: jdbc:hive2://FIXME:10000/default
10
11         proc datasets lib=hadoop;
                                                             Directory

                               Libref              HADOOP
                               Engine              HADOOP
                               Physical Name       jdbc:hive2://FIXME:10000/default
                               Schema              default
                               Comment             Default Hive database

2                                                          The SAS System                    Wednesday, October  3, 2018 06:38:00 PM

                                                             Directory

                               Location            hdfs://XYZ/apps/hive/warehouse
                               DBMS Major Version  1
                               DBMS Minor Version  2


                                                                                     DBMS
                                                                             Member  Member
                                         #  Name                             Type    Type

                                         1  AAAA                             DATA    TABLE

12           run;

13
NOTE: PROCEDURE DATASETS used (Total process time):

4                                                          The SAS System                    Wednesday, October  3, 2018 06:38:00 PM

      real time           0.89 seconds
      cpu time            0.03 seconds


NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414
NOTE: The SAS System used:
      real time           2.47 seconds
      cpu time            0.15 seconds
```

# Copyright

Copyright 2018 SAS Institute Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

&nbsp;&nbsp;&nbsp;&nbsp;https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
