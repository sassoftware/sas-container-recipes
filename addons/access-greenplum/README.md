# Overview

The content in this directory provides a simple way to smoke test the
SAS/ACCESS to Greenplum orderable.

# File list

* greenplum_sasserver.sh:
    * The contents of this file contain environment variables needed to ensure
      greenplum code is executed properly. Update this file with your Greenplum client
      library version number.
* acgreenplum.sas
    * This SAS code that can be submitted in SAS Studio or via the batchserver
      which will create and drop a table. This is exercising SAS Foundation and
      that the SAS/ACCESS iterface to Greenplum is configured correctly.

# How to Use

## SAS Studio

* Log into SAS Studio __http://\<hostname of Docker host\>:8081__
* Paste the code from either _acgreenplum.sas_ or _dcgreenplum.sas_ into the code
  window.
* Edit the 'FIXME' text in _acgreenplum.sas_ and _dcgreenplum.sas_ with the
  correct values for the environment.
* Run code
* There should be no errors and should get something like the following as a log

```
# Here is the log for acgreenplum.sas
 
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
 90         libname dblib greenplum path=&path. user=&username. password=&password.;
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
 117        /*-------------------*/oracle
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

## Batchserver

* Edit the 'FIXME' text in _acgreenplum.sas_ and _dcgreenplum.sas_ with the
  correct values for the environment.
* From the parent directory, run the following

```
docker run --interactive --tty --rm --volume ${PWD}/addons/access-greenplum:/sasinside --env SAS_LOGS_TO_DISK=true svc-access-greenplum --batch /sasinside/acgreenplum.sas

Dumping contents of "/tmp/greenplum_cas.settings" into /opt/sas/viya/config/etc/cas/default/cas_usermods.settings
Dumping contents of "/tmp/greenplum_sasserver.sh" into /opt/sas/viya/config/etc/batchserver/default/batchserver_usermods.sh
Dumping contents of "/tmp/greenplum_sasserver.sh" into /opt/sas/viya/config/etc/workspaceserver/default/workspaceserver_usermods.sh
Dumping contents of "/tmp/greenplum_sasserver.sh" into /opt/sas/viya/config/etc/connectserver/default/connectserver_usermods.sh
removed '/opt/sas/viya/config/var/log/cas/default_audit/cas_2018-09-26_febcc27c7307_7995.log'
removed '/opt/sas/viya/config/var/log/all-services/default/all-services_2018-09-26_18-32-47.log'
removed '/opt/sas/viya/config/var/log/all-services/default/all-services_2018-09-26_18-27-30.log'
removed '/opt/sas/viya/config/var/log/connect/default/unregister_connect.log'
removed '/opt/sas/viya/config/var/log/connect/default/connectspawner_console_2018-09-26_18-16-26.log'
removed '/opt/sas/viya/config/var/log/connect/default/register_connect.log'
removed '/opt/sas/viya/config/var/log/connect/default/ConnectSpawner_2018-09-26_febcc27c7307_18027.log'
[INFO] : CASENV_CAS_VIRTUAL_HOST is ''
[INFO] : CASENV_CAS_VIRTUAL_PORT is ''
[INFO] : CASENV_ADMIN_USER is 'cas'
removed '/opt/sas/viya/config/etc/cas/default/start.d/05updateperms_startup.lua'
Running "--batch /sasinside/acgreenplum.sas"
Starting Cloud Analytic Services...
CAS Consul Health:
    Consul not present
    CAS bypassing Consul serfHealth status check of CAS nodes

/sasinside /tmp
sourcing /opt/sas/viya/config/etc/sysconfig/sas-javaesntl/sas-java

'acgreenplum.log' -> 'acgreenplum_20180927193949.log'
1                                                          The SAS System                   Thursday, September 27, 2018 07:39:00 PM

NOTE: Copyright (c) 2016 by SAS Institute Inc., Cary, NC, USA. 
NOTE: SAS (r) Proprietary Software V.03.04 (TS4M0 MBCS3170) 
      Licensed to Full order for testing access engines, Site 70180938.
NOTE: This session is executing on the Linux 4.14.70-1-MANJARO (LIN X64) platform.



NOTE: Analytical products:
      
      SAS/STAT 14.3
      SAS/ETS 14.3
      SAS/OR 14.3
      SAS/IML 14.3
      SAS/QC 14.3

NOTE: Additional host information:

 Linux LIN X64 4.14.70-1-MANJARO #1 SMP PREEMPT Sat Sep 15 20:38:15 UTC 2018 x86_64 CentOS Linux release 7.5.1804 (Core)  

NOTE: SAS initialization used:
      real time           0.03 seconds
      cpu time            0.02 seconds
      

NOTE: AUTOEXEC processing beginning; file is /opt/sas/viya/config/etc/batchserver/default/autoexec.sas.


NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      


NOTE: AUTOEXEC processing completed.

1          %let server=FIXME;
2          %let password=FIXME;
3          %let username=FIXME;
4          %let db=FIXME;
5          %let port=5432;
6          
7          %let server=wintergreen.unx.sas.com;
8          %let username=smktst;
9          %let password=Smktst1!;
10         %let port=5432;
11         %let db=sbosmk;
12         
13         %macro randomnum(input);
14         %let mygen=%sysfunc(getoption(notes));
15         /* options nonotes; */
16         %global &input;
17             data _null_;
18             call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
19             run;
20         options &mygen;
21         %mend randomnum;
22         
23         %randomnum(id);

2                                                          The SAS System                   Thursday, September 27, 2018 07:39:00 PM


NOTE: Numeric values have been converted to character values at the places given by: (Line):(Column).
      23:60   
NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      

24         
25         %let ENGCONNOPT=%STR(server="&server."
26                              port=&port.
27                              user="&username."
28                              password="&password."
29                              db="&db"
30                              preserve_tab_names=yes
31                              preserve_col_names=yes);
32         /* assign libname engine */
33         /*-----------------------*/
34         libname dblib greenplm &ENGCONNOPT;
NOTE: Libref DBLIB was successfully assigned as follows: 
      Engine:        GREENPLM 
      Physical Name: wintergreen.unx.sas.com
35         
36         
37         /* check dbms table dropped */
38         /*--------------------------*/
39         proc delete data=dblib.SMKTAB&id.;run;

WARNING: File DBLIB.SMKTAB52736.DATA does not exist.
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.06 seconds
      cpu time            0.02 seconds
      

40         
41         
42         /* create work dataset */
43         /*---------------------*/
44         data work.SMKDAT&id.;
45            input name $ age sex $ bdate mmddyy.;
46            cards;

NOTE: The data set WORK.SMKDAT52736 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.01 seconds
      

59         ;
60         run;
61         
62         
63         /* create dbms table */
64         /*-------------------*/
65         data dblib.SMKTAB&id.;
66            set work.SMKDAT&id.;
67         run;


3                                                          The SAS System                   Thursday, September 27, 2018 07:39:00 PM

NOTE: There were 12 observations read from the data set WORK.SMKDAT52736.
NOTE: The data set DBLIB.SMKTAB52736 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.18 seconds
      cpu time            0.03 seconds
      

68         
69         
70         /* read dbms table */
71         /*-----------------*/
72         proc sql;
73            select count(*) from dblib.SMKTAB&id.;
74         quit;
NOTE: The PROCEDURE SQL printed page 1.
NOTE: PROCEDURE SQL used (Total process time):
      real time           0.13 seconds
      cpu time            0.05 seconds
      

75         
76         
77         /* cleanup */
78         /*---------*/
79         proc delete data=dblib.SMKTAB&id.; run;

NOTE: Deleting DBLIB.SMKTAB52736 (memtype=DATA).
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.05 seconds
      cpu time            0.00 seconds
      

80         libname dblib clear;
NOTE: Libref DBLIB has been deassigned.

NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414
NOTE: The SAS System used:
      real time           0.57 seconds
      cpu time            0.18 seconds

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
