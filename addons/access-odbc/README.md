# Overview

The content in this directory provides a simple way for smoke testing 
SAS/ACCESS Interface to ODBC.

# File List

* odbc_cas.settings:
    * This file contains environment variables that are required so that ODBC code is executed properly.
* odbc_sasserver.sh:
    * This file contains environment variables that are required so that 
      ODBC code is executed properly.
* acodbc.sas
    * SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Foundation to confirm that  SAS/ACCESS Interface to ODBC is configured correctly.
* dcodbc.sas
    * SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Cloud Analytic Services to validate that the SAS Data Connector to ODBC is
      configured correctly.

# How to Use

## SAS Studio

1. Log on to SAS Studio: http://_host-name-where-docker-is-running_:8081
2. Paste the code from either acodbc.sas or dcodbc.sas into the code
  window.
3. Edit the 'FIXME' text in acodbc.sas and dcodbc.sas with the
  correct values for the environment.
4. Run the code.

Here is an example of a log with no errors:

```
# Here is the log for acodbc.sas
 1          OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 72         
 73         %let dbuser=dbuser;
 74         %let dbpass=P@ssword;
 75         %let dbds=sasdb;
 76         
 77         options nodate;
 78         
 79         /*************************/
 80         /* ASSIGN LIBNAME ENGINE */
 81         /*************************/
 82         
 83         libname x odbc user=&dbuser  password=&dbpass ds=&dbds
 84         preserve_tab_names=yes preserve_col_names=yes;
 NOTE: Libref X was successfully assigned as follows: 
       Engine:        ODBC 
       Physical Name: FIXME
 85         
 86         /****************************/
 87         /* CHECK DBMS TABLE DROPPED */
 88         /****************************/
 89         
 90         proc delete data=x.smoketstdata; run;
 
 WARNING: File X.smoketstdata.DATA does not exist.
 NOTE: PROCEDURE DELETE used (Total process time):
       real time           0.08 seconds
       cpu time            0.04 seconds
       
 
 91         
 92         /***********************/
 93         /* CREATE WORK DATASET */
 94         /***********************/
 95         
 96         data work.tstdata;
 97            input fname $ age sex $ bdate mmddyy.;
 98            cards;
 
 NOTE: The data set WORK.TSTDATA has 12 observations and 4 variables.
 NOTE: DATA statement used (Total process time):
       real time           0.01 seconds
       cpu time            0.00 seconds
       
 
 111        ;
 112        run;
 113        
 114        /*********************/
 115        /* CREATE DBMS TABLE */
 116        /*********************/
 117        
 118        data x.smoketstdata;
 119          set work.tstdata;
 120        run;
 
 NOTE: There were 12 observations read from the data set WORK.TSTDATA.
 NOTE: The data set X.smoketstdata has 12 observations and 4 variables.
 NOTE: DATA statement used (Total process time):
       real time           0.13 seconds
       cpu time            0.07 seconds
       
 
 121        
 122        /*******************/
 123        /* READ DBMS TABLE */
 124        /*******************/
 125        
 126        proc print data=x.smoketstdata;
 127           format FNAME $7. sex $1. bdate date7.;
 128           title 'proc print of DBMS table';
 129        run;
 
 NOTE: PROCEDURE PRINT used (Total process time):
       real time           0.06 seconds
       cpu time            0.06 seconds
       
 
 130        
 131        /***********/
 132        /* CLEANUP */
 133        /***********/
 134        
 135        proc delete data=x.smoketstdata; run;
 
 NOTE: Deleting X.smoketstdata (memtype=DATA).
 NOTE: PROCEDURE DELETE used (Total process time):
       real time           0.06 seconds
       cpu time            0.00 seconds
       
 
 136        libname x clear;
 NOTE: Libref X has been deassigned.
 137        
 138        OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 151        
```

## SAS Batch Server

1. Edit the 'FIXME' text in acodbc.sas and dcodbc.sas to include the
  correct values for the environment.
2. From the parent directory, run the following command:

```
docker run --interactive --tty --rm --volume ${PWD}/addons/access-odbc:/sasinside --env SAS_LOGS_TO_DISK=true svc-access-odbc --batch /sasinside/acodbc.sas
Dumping contents of "/tmp/odbc_cas.settings" into /opt/sas/viya/config/etc/cas/default/cas_usermods.settings
Dumping contents of "/tmp/odbc_sasserver.sh" into /opt/sas/viya/config/etc/batchserver/default/batchserver_usermods.sh
Dumping contents of "/tmp/odbc_sasserver.sh" into /opt/sas/viya/config/etc/workspaceserver/default/workspaceserver_usermods.sh
Dumping contents of "/tmp/odbc_sasserver.sh" into /opt/sas/viya/config/etc/connectserver/default/connectserver_usermods.sh
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
Running "exec --batch /sasinside/acodbc.sas"
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

1          %let dbuser=dbuser;
2          %let dbpass=P@ssword;
3          %let dbds=sasdb;
4          
5          options nodate;
6          
7          /*************************/
8          /* ASSIGN LIBNAME ENGINE */
9          /*************************/
10         
11         libname x odbc user=&dbuser  password=&dbpass ds=&dbds
12         preserve_tab_names=yes preserve_col_names=yes;
NOTE: Libref X was successfully assigned as follows: 
      Engine:        ODBC 
      Physical Name: FIXME
13         
14         /****************************/
15         /* CHECK DBMS TABLE DROPPED */
16         /****************************/
17         
18         proc delete data=x.smoketstdata; run;

WARNING: File X.smoketstdata.DATA does not exist.
2                                                          The SAS System

NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.07 seconds
      cpu time            0.04 seconds
      

19         
20         /***********************/
21         /* CREATE WORK DATASET */
22         /***********************/
23         
24         data work.tstdata;
25            input fname $ age sex $ bdate mmddyy.;
26            cards;

NOTE: The data set WORK.TSTDATA has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      

39         ;
40         run;
41         
42         /*********************/
43         /* CREATE DBMS TABLE */
44         /*********************/
45         
46         data x.smoketstdata;
47           set work.tstdata;
48         run;

NOTE: There were 12 observations read from the data set WORK.TSTDATA.
NOTE: The data set X.smoketstdata has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.11 seconds
      cpu time            0.04 seconds
      

49         
50         /*******************/
51         /* READ DBMS TABLE */
52         /*******************/
53         
54         proc print data=x.smoketstdata;
55            format FNAME $7. sex $1. bdate date7.;
56            title 'proc print of DBMS table';
57         run;

NOTE: There were 12 observations read from the data set X.smoketstdata.
NOTE: The PROCEDURE PRINT printed page 1.
NOTE: PROCEDURE PRINT used (Total process time):
      real time           0.06 seconds
      cpu time            0.06 seconds
      

58         
59         /***********/
60         /* CLEANUP */
3                                                          The SAS System

61         /***********/
62         
63         proc delete data=x.smoketstdata; run;

NOTE: Deleting X.smoketstdata (memtype=DATA).
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.08 seconds
      cpu time            0.00 seconds
      

64         libname x clear;
NOTE: Libref X has been deassigned.

NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414
NOTE: The SAS System used:
      real time           0.47 seconds
      cpu time            0.21 seconds

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
