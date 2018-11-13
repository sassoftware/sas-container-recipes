# Overview

The content in this directory provides a simple way for smoke testing 
SAS/ACCESS Interface to Amazon Redshift.

# File List

* acredshift.sas
    * SAS code that can be submitted in SAS Studio or by the SAS batch server. This code
      creates and drops a table and uses SAS Foundation to confirm that SAS/ACCESS Interface to Amazon Redshift is configured correctly.
* dcredshift.sas
    * SAS code that can be submitted in SAS Studio or by the SAS batch server. This code creates and drops a table and uses SAS Cloud Analytic Services to confirm that SAS Data Connector to Amazon Redshift is
      configured correctly.

# How to Use

## SAS Studio

1. Log on to SAS Studio: http://_host-name-where-docker-is-running_:8081
2. Paste the code from either acredshift.sas or dcredshift.sas into the code
  window.
3. Edit the 'FIXME' text in acredshift.sas and dcredshift.sas with the
  correct values for the environment.
4. Run the code.

Here is an example of a log with no errors:

```
# Here is the log for acredshift.sas

 
 1          OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 72         
 73         %let server=10.0.0.1;
 74         %let username=dbuser;
 75         %let password=P@ssword;
 76         %let database=sasdb;
 77         %let port=5439;
 78         
 79         options yearcutoff=1900;
 80         
 81         %macro randomnum(input);
 82             %let mygen=%sysfunc(getoption(notes));
 83             options nonotes;
 84             %global &input;
 85                 data _null_;
 86                 call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
 87                 run;
 88             options &mygen;
 89         %mend randomnum;
 90         
 91         %randomnum(id);
 92         
 93         %let engine=SASIORST;
 94         
 95         /* assign libname engine */
 96         /*-----------------------*/
 97         libname dblib redshift server="&server."
 98                             port=&port.
 99                             user="&username."
 100                            password="&password."
 101                            database="&database."
 102                            preserve_tab_names=yes
 103                            preserve_col_names=yes
 104                            ;
 NOTE: Libref DBLIB was successfully assigned as follows: 
       Engine:        REDSHIFT 
       Physical Name: FIXME
 105        
 106        
 107        /* check dbms table dropped */
 108        /*--------------------------*/
 109        proc delete data=dblib.SMKTAB&id.;run;
 
 WARNING: File DBLIB.SMKTAB91097.DATA does not exist.
 NOTE: PROCEDURE DELETE used (Total process time):
       real time           0.18 seconds
       cpu time            0.03 seconds
       
 
 110        
 111        
 112        /* create work dataset */
 113        /*---------------------*/
 114        data work.SMKDAT&id.;
 115           input name $ age sex $ bdate mmddyy.;
 116           cards;
 
 NOTE: The data set WORK.SMKDAT91097 has 12 observations and 4 variables.
 NOTE: DATA statement used (Total process time):
       real time           0.00 seconds
       cpu time            0.01 seconds
       
 
 129        ;
 130        run;
 131        
 132        
 133        /* create dbms table */
 134        /*-------------------*/
 135        data dblib.SMKTAB&id.;
 136           set work.SMKDAT&id.;
 137        run;
 
 NOTE: There were 12 observations read from the data set WORK.SMKDAT91097.
 NOTE: The data set DBLIB.SMKTAB91097 has 12 observations and 4 variables.
 NOTE: DATA statement used (Total process time):
       real time           0.54 seconds
       cpu time            0.03 seconds
       
 
 138        
 139        
 140        /* read dbms table */
 141        /*-----------------*/
 142        proc sql;
 143           select count(*) from dblib.SMKTAB&id.;
 144        quit;
 NOTE: PROCEDURE SQL used (Total process time):
       real time           0.28 seconds
       cpu time            0.06 seconds
       
 
 145        
 146        
 147        /* cleanup */
 148        /*---------*/
 149        proc delete data=dblib.SMKTAB&id.; run;
 
 NOTE: Deleting DBLIB.SMKTAB91097 (memtype=DATA).
 NOTE: PROCEDURE DELETE used (Total process time):
       real time           0.13 seconds
       cpu time            0.00 seconds
       
 
 150        libname dblib clear;
 NOTE: Libref DBLIB has been deassigned.
 151        
 152        
 153        OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 166               
```

## SAS Batch Server

1. Edit the 'FIXME' text in  acredshift.sas and dcredshift.sas to include the
  correct values for the environment.
2. From the parent directory, run the following command:

```
docker run --interactive --tty --rm --volume ${PWD}/addons/access-redshift:/sasinside --env SAS_LOGS_TO_DISK=true svc-access-redshift --batch /sasinside/acredshift.sas
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
Running "exec --batch /sasinside/acredshift.sas"
Starting Cloud Analytic Services...
CAS Consul Health:
    Consul not present
    CAS bypassing Consul serfHealth status check of CAS nodes

/sasinside /tmp/sas
sourcing /opt/sas/viya/config/etc/sysconfig/sas-javaesntl/sas-java

1                                                          The SAS System                    Tuesday, September 11, 2018 05:12:00 PM

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

1          %let server=10.0.0.1;
2          %let username=dbuser;
3          %let password=P@ssword;
4          %let database=sasdb;
5          %let port=5439;
6          
7          options yearcutoff=1900;
8          
9          %macro randomnum(input);
10             %let mygen=%sysfunc(getoption(notes));
11             options nonotes;
12             %global &input;
13                 data _null_;
14                 call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
15                 run;
16             options &mygen;
17         %mend randomnum;
18         
19         %randomnum(id);
20         
21         %let engine=SASIORST;
22         
23         /* assign libname engine */

2                                                          The SAS System                    Tuesday, September 11, 2018 05:12:00 PM

24         /*-----------------------*/
25         libname dblib redshift server="&server."
26                             port=&port.
27                             user="&username."
28                             password="&password."
29                             database="&database."
30                             preserve_tab_names=yes
31                             preserve_col_names=yes
32                             ;
NOTE: Libref DBLIB was successfully assigned as follows: 
      Engine:        REDSHIFT 
      Physical Name: FIXME
33         
34         
35         /* check dbms table dropped */
36         /*--------------------------*/
37         proc delete data=dblib.SMKTAB&id.;run;

WARNING: File DBLIB.SMKTAB25631.DATA does not exist.
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.37 seconds
      cpu time            0.03 seconds
      

38         
39         
40         /* create work dataset */
41         /*---------------------*/
42         data work.SMKDAT&id.;
43            input name $ age sex $ bdate mmddyy.;
44            cards;

NOTE: The data set WORK.SMKDAT25631 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      

57         ;
58         run;
59         
60         
61         /* create dbms table */
62         /*-------------------*/
63         data dblib.SMKTAB&id.;
64            set work.SMKDAT&id.;
65         run;

NOTE: There were 12 observations read from the data set WORK.SMKDAT25631.
NOTE: The data set DBLIB.SMKTAB25631 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.60 seconds
      cpu time            0.04 seconds
      

66         
67         
68         /* read dbms table */

3                                                          The SAS System                    Tuesday, September 11, 2018 05:12:00 PM

69         /*-----------------*/
70         proc sql;
71            select count(*) from dblib.SMKTAB&id.;
72         quit;
NOTE: The PROCEDURE SQL printed page 1.
NOTE: PROCEDURE SQL used (Total process time):
      real time           0.17 seconds
      cpu time            0.06 seconds
      

73         
74         
75         /* cleanup */
76         /*---------*/
77         proc delete data=dblib.SMKTAB&id.; run;

NOTE: Deleting DBLIB.SMKTAB25631 (memtype=DATA).
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.14 seconds
      cpu time            0.00 seconds
      

78         libname dblib clear;
NOTE: Libref DBLIB has been deassigned.
79         
80         
81         /*------------------------------------------------------------------
82          *  NAME     : accredshift.sas
83          *  COMMENTS : 20aug18. Peng Li (Oliver). Created.
84          *  UPDATE   :
85          *------------------------------------------------------------------*/

NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414
NOTE: The SAS System used:
      real time           1.74 seconds
      cpu time            0.22 seconds

# When running the dcredshift code, you need to pass in a user that has a 
# .authinfo file setup in their home directory

docker run --interactive --tty --rm --volume ${PWD}/addons/access-redshift:/sasinside --env SAS_LOGS_TO_DISK=true svc-access-redshift --user sasdemo --batch /sasinside/acredshift.sas
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
