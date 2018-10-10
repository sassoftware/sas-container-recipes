# Overview

The content in this directory provides a simple way for smoke testing SAS/ACCESS Interface to Teradata.

# Requirements
To build the Teradata layer, the Dockerfile expects that the teradata.tgz file is in the current directory and has the following stucture:

```
|____TeradataToolsAndUtilitiesBase
| |____Readmes
| |____Linux
| |____TeraJDBC
| |____v16.10.01
| |____setup.bat
| |____.setup.sh
| |____ThirdPartyLicensesTTU.txt
```

The Dockerfile looks for the teradata.tgz file and runs the setup.bat script to install all 
the Teradata libraries.

# File List

* terdata_cas.settings/teradata_sasserver.sh
    * Files for SAS Cloud Analytic Services (CAS) and the SAS Workspace Server that are required to configure ODBC and Teradata libraries.
* acteradata.sas
    * SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Foundation to confirm that  SAS/ACCESS Interface to Teradata is configured correctly.
* dcteradata.sas
    * SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses CAS to confirm that the SAS Data Connector to Teradata is
      configured correctly.

# How to Use

## SAS Studio

1. Log on to SAS Studio: http://_host-name-where-docker-is-running_:8081
2. Paste the code from either acteradata.sas or dcteradata.sas into the code
  window.
3. Edit the 'FIXME' text in acteradata.sas and dcteradata.sas to include the
  correct values for the environment.
4. Run the code.

Here is an example of a log with no errors:

```
# Here is the log for acteradata.sas
1          OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 72         
 73         %let server=FIXME;
 74         %let username=FIXME;
 75         %let password=FIXME;
 76         %let database=FIXME;
 77         %let engine=teradata;
 78         
 79         options yearcutoff=1900;
 80         
 81         %macro randomnum(input);
 82         %let mygen=%sysfunc(getoption(notes));
 83         /* options nonotes; */
 84         %global &input;
 85             data _null_;
 86             call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
 87             run;
 88         options &mygen;
 89         %mend randomnum;
 90         
 91         %randomnum(id);
 
 NOTE: Numeric values have been converted to character values at the places given by: (Line):(Column).
       91:60   
 NOTE: DATA statement used (Total process time):
       real time           0.00 seconds
       cpu time            0.00 seconds
       
 
 92         
 93         /* Engine specific variables */
 94         %let ENGCONNOPT=%STR(server="&server." user="&username." password="&password." database="&database.");
 95         
 96         /* Data Connector specific variables */
 97         %let dtm=serial;
 98         %let srctype=teradata;
 99         %let DCCONOPT=%STR(datasource=(srctype="&srctype.",
 100                                                        server="&server.",
 101                                                        user="&username.",
 102                                                        password="&password.",
 103                                                        database="&database."
 104                                                        dataTransferMode="&dtm"));
 105        
 106        
 107        /* assign libname engine */
 108        /*-----------------------*/
 109        libname dblib &engine &ENGCONNOPT;
 NOTE: Libref DBLIB was successfully assigned as follows: 
       Engine:        TERADATA 
       Physical Name: FIXME
 110        
 111        
 112        /* check dbms table dropped */
 113        /*--------------------------*/
 114        proc delete data=dblib.SMKTAB&id.;run;
 
 WARNING: File DBLIB.SMKTAB31250.DATA does not exist.
 NOTE: PROCEDURE DELETE used (Total process time):
       real time           0.09 seconds
       cpu time            0.03 seconds
       
 
 115        
 116        
 117        /* create work dataset */
 118        /*---------------------*/
 119        data work.SMKDAT&id.;
 120           input name $ age sex $ bdate mmddyy.;
 121           cards;
 
 NOTE: The data set WORK.SMKDAT31250 has 12 observations and 4 variables.
 NOTE: DATA statement used (Total process time):
       real time           0.00 seconds
       cpu time            0.00 seconds
       
 
 134        ;
 135        run;
 136        
 137        
 138        /* create dbms table */
 139        /*-------------------*/
 140        data dblib.SMKTAB&id.;
 141           set work.SMKDAT&id.;
 142        run;
 
 NOTE: There were 12 observations read from the data set WORK.SMKDAT31250.
 NOTE: The data set DBLIB.SMKTAB31250 has 12 observations and 4 variables.
 NOTE: DATA statement used (Total process time):
       real time           0.31 seconds
       cpu time            0.02 seconds
       
 
 143        
 144        /* read dbms table */
 145        /*-----------------*/
 146        proc sql;
 147           select count(*) from dblib.SMKTAB&id.;
 148        quit;
 NOTE: PROCEDURE SQL used (Total process time):
       real time           0.28 seconds
       cpu time            0.10 seconds
       
 
 149        
 150        
 151        /* cleanup */
 152        /*---------*/
 153        proc delete data=dblib.SMKTAB&id.; run;
 
 NOTE: Deleting DBLIB.SMKTAB31250 (memtype=DATA).
 NOTE: PROCEDURE DELETE used (Total process time):
       real time           0.08 seconds
       cpu time            0.01 seconds
       
 
 154        libname dblib clear;
 NOTE: Libref DBLIB has been deassigned.
 155        
 156        OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 169        

```

## SAS Batch Server

1. Edit the 'FIXME' text in acteradata.sas and dcteradata.sas to include the
  correct values for the environment.
2. From the parent directory, run the following command:

```
docker run --interactive --tty --rm --volume ${PWD}/addons/access-teradata:/sasinside --env SAS_LOGS_TO_DISK=true svc-access-teradata --batch /sasinside/acteradata.sas
removed '/opt/sas/viya/config/var/log/all-services/default/all-services_2018-08-31_13-51-24.log'
removed '/opt/sas/viya/config/var/log/all-services/default/all-services_2018-08-31_13-41-36.log'
removed '/opt/sas/viya/config/var/log/cas/default_audit/cas_2018-08-31_e8c8ab0df875_6748.log'
removed '/opt/sas/viya/config/var/log/connect/default/ConnectSpawner_2018-08-31_e8c8ab0df875_16491.log'
removed '/opt/sas/viya/config/var/log/connect/default/connectspawner_console_2018-08-31_13-20-11.log'
removed '/opt/sas/viya/config/var/log/connect/default/register_connect.log'
removed '/opt/sas/viya/config/var/log/connect/default/unregister_connect.log'
removed '/opt/sas/viya/config/etc/sysconfig/cas/default/cas_grid_vars'
[INFO] : CASENV_CAS_VIRTUAL_HOST is 'localhost'
[INFO] : CASENV_CAS_VIRTUAL_PORT is '443'
[INFO] : CASENV_ADMIN_USER is 'cas'
Sourcing /opt/sas/viya/home/share/cas/docconvjars.cascfg
removed '/opt/sas/viya/config/etc/cas/default/start.d/05updateperms_startup.lua'
Running "exec --batch /sasinside/acteradata.sas"
Starting Cloud Analytic Services...
CAS Consul Health:
    Consul not present
    CAS bypassing Consul serfHealth status check of CAS nodes

/sasinside /tmp/sas
sourcing /opt/sas/viya/config/etc/sysconfig/sas-javaesntl/sas-java

1                                                          The SAS System                     Monday, September 10, 2018 02:21:00 PM

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
      cpu time            0.02 seconds
      

NOTE: AUTOEXEC processing beginning; file is /opt/sas/viya/config/etc/batchserver/default/autoexec.sas.


NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      


NOTE: AUTOEXEC processing completed.

1          %let server=FIXME;
2          %let username=FIXME;
3          %let password=FIXME;
4          %let database=FIXME;
5          %let engine=teradata;
6          
7          options yearcutoff=1900;
8          
9          %macro randomnum(input);
10         %let mygen=%sysfunc(getoption(notes));
11         /* options nonotes; */
12         %global &input;
13             data _null_;
14             call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
15             run;
16         options &mygen;
17         %mend randomnum;
18         
19         %randomnum(id);

NOTE: Numeric values have been converted to character values at the places given by: (Line):(Column).
      19:60   
NOTE: DATA statement used (Total process time):

2                                                          The SAS System                     Monday, September 10, 2018 02:21:00 PM

      real time           0.00 seconds
      cpu time            0.00 seconds
      

20         
21         /* Engine specific variables */
22         %let ENGCONNOPT=%STR(server="&server." user="&username." password="&password." database="&database.");
23         
24         /* Data Connector specific variables */
25         %let dtm=serial;
26         %let srctype=teradata;
27         %let DCCONOPT=%STR(datasource=(srctype="&srctype.",
28                                                         server="&server.",
29                                                         user="&username.",
30                                                         password="&password.",
31                                                         database="&database."
32                                                         dataTransferMode="&dtm"));
33         
34         
35         /* assign libname engine */
36         /*-----------------------*/
37         libname dblib &engine &ENGCONNOPT;
NOTE: Libref DBLIB was successfully assigned as follows: 
      Engine:        TERADATA 
      Physical Name: FIXME
38         
39         
40         /* check dbms table dropped */
41         /*--------------------------*/
42         proc delete data=dblib.SMKTAB&id.;run;

WARNING: File DBLIB.SMKTAB65445.DATA does not exist.
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.09 seconds
      cpu time            0.02 seconds
      

43         
44         
45         /* create work dataset */
46         /*---------------------*/
47         data work.SMKDAT&id.;
48            input name $ age sex $ bdate mmddyy.;
49            cards;

NOTE: The data set WORK.SMKDAT65445 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.01 seconds
      

62         ;
63         run;
64         
65         
66         /* create dbms table */
67         /*-------------------*/
68         data dblib.SMKTAB&id.;

3                                                          The SAS System                     Monday, September 10, 2018 02:21:00 PM

69            set work.SMKDAT&id.;
70         run;

NOTE: There were 12 observations read from the data set WORK.SMKDAT65445.
NOTE: The data set DBLIB.SMKTAB65445 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.19 seconds
      cpu time            0.03 seconds
      

71         
72         /* read dbms table */
73         /*-----------------*/
74         proc sql;
75            select count(*) from dblib.SMKTAB&id.;
76         quit;
NOTE: The PROCEDURE SQL printed page 1.
NOTE: PROCEDURE SQL used (Total process time):
      real time           0.30 seconds
      cpu time            0.11 seconds
      

77         
78         
79         /* cleanup */
80         /*---------*/
81         proc delete data=dblib.SMKTAB&id.; run;

NOTE: Deleting DBLIB.SMKTAB65445 (memtype=DATA).
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.06 seconds
      cpu time            0.00 seconds
      

82         libname dblib clear;
NOTE: Libref DBLIB has been deassigned.

NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414
NOTE: The SAS System used:
      real time           1.07 seconds
      cpu time            0.30 seconds
```      

When running the dcteradata code, you must pass in a user that has an 
.authinfo file in their home directory.

```
docker run --interactive --tty --rm --volume ${PWD}/addons/access-teradata:/sasinside --env SAS_LOGS_TO_DISK=true svc-access-teradata --user sasdemo --batch /sasinside/dcteradata.sas
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
