# Overview

The content in this directory provides a simple way for smoke testing 
SAS/ACCESS Interface to Oracle.

# Requirements

* Oracle client library RPMs must be placed in this directory. The Dockerfile will
attempt to install any RPMs in this directory.
* A file named tnsnames.ora is expected in this directory.

# File List

* oracle_cas.settings:
    * This file contains environment variables that are required so that the Oracle code executes properly. Update this file with your Oracle client library version number.
* oracle_sasserver.sh:
    * This file contains environment variables that are required so that the Oracle code executes properly. Update this file with your Oracle client library version number.
* acoracle.sas
    * SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table. The code uses SAS Foundation to validate that SAS/ACCESS Interface to Oracle is configured correctly.
* dcoracle.sas
    * SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table. The code uses SAS Cloud Analytic Services (CAS) to validate that the Data Connector to Oracle is configured correctly.

# How to Use

## SAS Studio

1. Log on to SAS Studio: http://_host-name-where-docker-is-running_:8081
2. Paste the code from either acoracle.sas or dcoracle.sas into the code window.
3. Edit the 'FIXME' text in acoracle.sas and dcoracle.sas with the correct values for the environment.
4. Run the code.

Here is an example of a log with no errors:

```
# Here is the log for acoracle.sas
 
 1          OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 72         
 73         %let password=FIXME;
 74         %let username=FIXME;
 75         %let schema=FIXME;
 76         %let path=FIXME;
 77         
 78         %macro randomnum(input);
 79         %let mygen=%sysfunc(getoption(notes));
 80         /* options nonotes; */
 81         %global &input;
 82             data _null_;
 83             call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
 84             run;
 85         options &mygen;
 86         %mend randomnum;
 87         
 88         %randomnum(id);
 
 NOTE: Numeric values have been converted to character values at the places given by: (Line):(Column).
       88:60   
 NOTE: DATA statement used (Total process time):
       real time           0.00 seconds
       cpu time            0.00 seconds
       
 
 89         
 90         libname dblib oracle path=&path. user=&username. password=&password.;
 NOTE: Libref DBLIB was successfully assigned as follows: 
       Engine:        ORACLE 
       Physical Name: exadat
 91         
 92         proc delete data=dblib.SMKTAB&id.;run;
 
 WARNING: File DBLIB.SMKTAB32029.DATA does not exist.
 NOTE: PROCEDURE DELETE used (Total process time):
       real time           0.04 seconds
       cpu time      exadat
       
 
 93         
 94         
 95         /* createexadat
 96         /*-------exadat
 97         data workexadat
 98            input exadat
 99            cards;exadat
 
 NOTE: The data set WORK.SMKDAT32029 has 12 observations and 4 variables.
 NOTE: DATA statement used (Total process time):
       real time           0.00 seconds
       cpu time            0.02 seconds
       
 
 112        ;
 113        run;
 114        
 115        
 116        /* create dbms table */
 117        /*-------------------*/
 118        data dblib.SMKTAB&id.;
 119           set work.SMKDAT&id.;
 120        run;
 
 NOTE: There were 12 observations read from the data set WORK.SMKDAT32029.
 NOTE: The data set DBLIB.SMKTAB32029 has 12 observations and 4 variables.
 NOTE: DATA statement used (Total process time):
       real time           0.06 seconds
       cpu time            0.00 seconds
       
 
 121        
 122        
 123        /* read dbms table */
 124        /*-----------------*/
 125        proc sql;
 126           select count(*) from dblib.SMKTAB&id.;
 127        quit;
 NOTE: PROCEDURE SQL used (Total process time):
       real time           0.04 seconds
       cpu time            0.03 seconds
       
 
 128        
 129        
 130        /* cleanup */
 131        /*---------*/
 132        proc delete data=dblib.SMKTAB&id.; run;
 
 NOTE: Deleting DBLIB.SMKTAB32029 (memtype=DATA).
 NOTE: PROCEDURE DELETE used (Total process time):
       real time           0.03 seconds
       cpu time            0.00 seconds
       
 
 133        libname dblib clear;
 NOTE: Libref DBLIB has been deassigned.
 134        
 135        OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 148        
```

## SAS Batch Server

1. Edit the 'FIXME' text in acoracle.sas and dcoracle.sas to include the correct values for the environment.
2. From the parent directory, run the following command:

```
docker run --interactive --tty --rm --volume ${PWD}/addons/access-oracle:/sasinside --env SAS_LOGS_TO_DISK=true svc-access-oracle --batch /sasinside/acoracle.sas
Dumping contents of "/tmp/oracle_cas.settings" into /opt/sas/viya/config/etc/cas/default/cas_usermods.settings
Dumping contents of "/tmp/oracle_sasserver.sh" into /opt/sas/viya/config/etc/batchserver/default/batchserver_usermods.sh
Dumping contents of "/tmp/oracle_sasserver.sh" into /opt/sas/viya/config/etc/workspaceserver/default/workspaceserver_usermods.sh
Dumping contents of "/tmp/oracle_sasserver.sh" into /opt/sas/viya/config/etc/connectserver/default/connectserver_usermods.sh
removed '/opt/sas/viya/config/var/log/cas/default_audit/cas_2018-08-31_0a6627c19f0d_6526.log'
removed '/opt/sas/viya/config/var/log/all-services/default/all-services_2018-08-31_18-34-24.log'
removed '/opt/sas/viya/config/var/log/all-services/default/all-services_2018-08-31_18-31-38.log'
removed '/opt/sas/viya/config/var/log/connect/default/connectspawner_console_2018-08-31_18-26-55.log'
removed '/opt/sas/viya/config/var/log/connect/default/unregister_connect.log'
removed '/opt/sas/viya/config/var/log/connect/default/register_connect.log'
removed '/opt/sas/viya/config/var/log/connect/default/ConnectSpawner_2018-08-31_0a6627c19f0d_16330.log'
removed '/opt/sas/viya/config/etc/sysconfig/cas/default/cas_grid_vars'
[INFO] : CASENV_CAS_VIRTUAL_HOST is 'localhost'
[INFO] : CASENV_CAS_VIRTUAL_PORT is '443'
[INFO] : CASENV_ADMIN_USER is 'sasdemo'
Sourcing /opt/sas/viya/home/share/cas/docconvjars.cascfg
Running "exec --batch /sasinside/acoracle.sas"
Starting Cloud Analytic Services...
CAS Consul Health:
    Consul not present
    CAS bypassing Consul serfHealth status check of CAS nodes

/sasinside /tmp/sas
sourcing /opt/sas/viya/config/etc/sysconfig/sas-javaesntl/sas-java

1                                                          The SAS System                    Tuesday, September  4, 2018 02:00:00 PM

NOTE: Copyright (c) 2016 by SAS Institute Inc., Cary, NC, USA. 
NOTE: SAS (r) Proprietary Software V.03.04 (TS4M0 MBCS3170) 
      Licensed to vdmml+access, Site 70180938.
NOTE: This session is executing on the Linux 4.14.60-1-MANJARO (LIN X64) platform.



NOTE: Analytical products:
      
      SAS/STAT 14.3
      SAS/ETS 14.3
      SAS/OR 14.3
      SAS/IML 14.3
      SAS/QC 14.3

NOTE: Additional host information:

 Linux LIN X64 4.14.60-1-MANJARO #1 SMP PREEMPT Fri Aug 3 12:49:45 UTC 2018 x86_64 CentOS Linux release 7.5.1804 (Core)  

NOTE: SAS initialization used:
      real time           0.02 seconds
      cpu time            0.01 seconds
      

NOTE: AUTOEXEC processing beginning; file is /opt/sas/viya/config/etc/batchserver/default/autoexec.sas.


NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.01 seconds
      


NOTE: AUTOEXEC processing completed.

1          %let password=FIXME;
2          %let username=FIXME;
3          %let schema=FIXME;
4          %let path=FIXME;
5          
6          %macro randomnum(input);
7          %let mygen=%sysfunc(getoption(notes));
8          /* options nonotes; */
9          %global &input;
10             data _null_;
11             call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
12             run;
13         options &mygen;
14         %mend randomnum;
15         
16         %randomnum(id);

NOTE: Numeric values have been converted to character values at the places given by: (Line):(Column).
      16:60   
NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      

2                                                          The SAS System                   Thursday, September 27, 2018 07:19:00 PM


17         
18         libname dblib oracle path=&path. user=&username. password=&password.;
NOTE: Libref DBLIB was successfully assigned as follows: 
      Engine:        ORACLE 
      Physical Name: exadat
19         
20         proc delete data=dblib.SMKTAB&id.;run;

WARNING: File DBLIB.SMKTAB67319.DATA does not exist.
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.03 seconds
      cpu time            0.00 seconds
      

21         
22         
23         /* create work dataset */
24         /*---------------------*/
25         data work.SMKDAT&id.;
26            input name $ age sex $ bdate mmddyy.;
27            cards;

NOTE: The data set WORK.SMKDAT67319 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      

40         ;
41         run;
42         
43         
44         /* create dbms table */
45         /*-------------------*/
46         data dblib.SMKTAB&id.;
47            set work.SMKDAT&id.;
48         run;

NOTE: There were 12 observations read from the data set WORK.SMKDAT67319.
NOTE: The data set DBLIB.SMKTAB67319 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.06 seconds
      cpu time            0.06 seconds
      

49         
50         
51         /* read dbms table */
52         /*-----------------*/
53         proc sql;
54            select count(*) from dblib.SMKTAB&id.;
55         quit;
NOTE: The PROCEDURE SQL printed page 1.
NOTE: PROCEDURE SQL used (Total process time):
      real time           0.03 seconds
      cpu time            0.01 seconds
      

3                                                          The SAS System                   Thursday, September 27, 2018 07:19:00 PM


56         
57         
58         /* cleanup */
59         /*---------*/
60         proc delete data=dblib.SMKTAB&id.; run;

NOTE: Deleting DBLIB.SMKTAB67319 (memtype=DATA).
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.03 seconds
      cpu time            0.00 seconds
      

61         libname dblib clear;
NOTE: Libref DBLIB has been deassigned.

NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414
NOTE: The SAS System used:
      real time           1.30 seconds
      cpu time            0.16 seconds

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
