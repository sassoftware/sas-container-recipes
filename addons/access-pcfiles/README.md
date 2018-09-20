# Overview

The content in this directory provides a simple way to smoke test the
SAS/ACCESS to PC Files orderable.

# File list

* acpcfiles.sas
    * This SAS code that can be submitted in SAS Studio or via the batchserver
      which will create a table and write its contents to file. This is
      exercising SAS Foundation and that the SAS/ACCESS interface to PC Files
      is working.
* dcpcfiles.sas
    * This SAS code that can be submitted in SAS Studio or via the batchserver
      which will create a table, write its contents to file, and then read that
      files contents back into CAS. This is exercising Cloud Analytics Services
      and validating that the Data Connector to PC Files is working.

# How to Use

## SAS Studio

* Log into SAS Studio __http://\<hostname of Docker host\>:8081__
* Paste the code from either _acpcfiles.sas_ or _dcpcfiles.sas_ into the code
  window.
* Edit the 'FIXME' text in _acpcfiles.sas_ and _dcpcfiles.sas_ with the
  correct values for the environment.
* Run code
* There should be no errors and should get something like the following as a log

```
# Here is the log for acpcfiles.sas


 1          OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 72         
 73         %let xlsx_filepath="/tmp/pcfiltest.xlsx";
 74         %let id=12;
 75         libname xlxdblib sasioxlx &xlsx_filepath;
 NOTE: Libref XLXDBLIB was successfully assigned as follows: 
       Engine:        XLSX 
       Physical Name: /tmp/pcfiltest.xlsx
 76         
 77         /* create work dataset */
 78         /*---------------------*/
 79         data work.SMKDAT&id.;
 80            input name $ age sex $ bdate mmddyy.;
 81            cards;
 
 NOTE: The data set WORK.SMKDAT12 has 12 observations and 4 variables.
 NOTE: DATA statement used (Total process time):
       real time           0.00 seconds
       cpu time            0.00 seconds
       
 
 94         ;
 95         run;
 96         
 97         /* create dbms table for dbms=xlsx */
 98         /*---------------------------------*/
 99         
 100        proc export data=work.SMKDAT&id.
 101        outfile=&xlsx_filepath
 102        dbms=xlsx replace;
 103        putnames=yes;
 104        run;
 
 NOTE: The export data set has 12 observations and 4 variables.
 NOTE: "/tmp/pcfiltest.xlsx" file was successfully created.
 NOTE: PROCEDURE EXPORT used (Total process time):
       real time           0.00 seconds
       cpu time            0.00 seconds
       
 
 105        
 106        /* import dbms table with dbms=xlsx */
 107        /*----------------------------------*/
 108        
 109        proc import out=work.xlsx_SMKDAT&id.
 110        datafile=&xlsx_filepath
 111        dbms=xlsx replace;
 112        getnames=Y;
 113        run;
 
 NOTE: One or more variables were converted because the data type is not supported by the V9 engine. For more details, run with 
       options MSGLEVEL=I.
 NOTE: The import data set has 12 observations and 4 variables.
 NOTE: WORK.XLSX_SMKDAT12 data set was successfully created.
 NOTE: PROCEDURE IMPORT used (Total process time):
       real time           0.00 seconds
       cpu time            0.00 seconds
       
 
 114        
 115        /* read work dataset imported with  dbms=xlsx */
 116        /*------------------------------------------*/
 117        proc sql;
 118           select count(*) from xlsx_SMKDAT&id.;
 119        quit;
 NOTE: PROCEDURE SQL used (Total process time):
       real time           0.01 seconds
       cpu time            0.02 seconds
       
 
 120        
 121        libname xlxdblib clear;
 NOTE: Libref XLXDBLIB has been deassigned.
 122        
 123        OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 136     
```

## Batchserver

* Edit the 'FIXME' text in _acpcfiles.sas_ and _dcpcfiles.sas_ with the
  correct values for the environment.
* From the parent directory, run the following

```
docker run --interactive --tty --rm --volume ${PWD}/pcfilesql:/sasinside --env SAS_LOGS_TO_DISK=true viya-single-container --batch /sasinside/acpcfiles.sas
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
Running "exec --batch /sasinside/acpcfiles.sas"
Starting Cloud Analytic Services...
CAS Consul Health:
    Consul not present
    CAS bypassing Consul serfHealth status check of CAS nodes

/sasinside /tmp/sas
sourcing /opt/sas/viya/config/etc/sysconfig/sas-javaesntl/sas-java

1                                                          The SAS System                     Monday, September 10, 2018 01:52:00 PM

NOTE: Copyright (c) 2016 by SAS Institute Inc., Cary, NC, USA. 
NOTE: SAS (r) Proprietary Software V.03.04 (TS4M0 MBCS3170) 
      Licensed to vdmml+access, Site 70180938.
NOTE: This session is executing on the Linux 4.14.60-1-MANJARO (LIN X64) platform.


NOTE: SAS initialization used:
      real time           0.01 seconds
      cpu time            0.01 seconds
      

NOTE: AUTOEXEC processing beginning; file is /opt/sas/viya/config/etc/batchserver/default/autoexec.sas.


NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      


NOTE: AUTOEXEC processing completed.

1          %let xlsx_filepath="/tmp/pcfiltest.xlsx";
2          %let id=12;
3          libname xlxdblib sasioxlx &xlsx_filepath;
NOTE: Libref XLXDBLIB was successfully assigned as follows: 
      Engine:        XLSX 
      Physical Name: /tmp/pcfiltest.xlsx
4          
5          /* create work dataset */
6          /*---------------------*/
7          data work.SMKDAT&id.;
8             input name $ age sex $ bdate mmddyy.;
9             cards;

NOTE: The data set WORK.SMKDAT12 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      

22         ;
23         run;
24         
25         /* create dbms table for dbms=xlsx */

2                                                          The SAS System                     Monday, September 10, 2018 01:52:00 PM

26         /*---------------------------------*/
27         
28         proc export data=work.SMKDAT&id.
29         outfile=&xlsx_filepath
30         dbms=xlsx replace;
31         putnames=yes;
32         run;

NOTE: The export data set has 12 observations and 4 variables.
NOTE: "/tmp/pcfiltest.xlsx" file was successfully created.
NOTE: PROCEDURE EXPORT used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      

33         
34         /* import dbms table with dbms=xlsx */
35         /*----------------------------------*/
36         
37         proc import out=work.xlsx_SMKDAT&id.
38         datafile=&xlsx_filepath
39         dbms=xlsx replace;
40         getnames=Y;
41         run;

NOTE: One or more variables were converted because the data type is not supported by the V9 engine. For more details, run with 
      options MSGLEVEL=I.
NOTE: The import data set has 12 observations and 4 variables.
NOTE: WORK.XLSX_SMKDAT12 data set was successfully created.
NOTE: PROCEDURE IMPORT used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds
      

42         
43         /* read work dataset imported with  dbms=xlsx */
44         /*------------------------------------------*/
45         proc sql;
46            select count(*) from xlsx_SMKDAT&id.;
47         quit;
NOTE: The PROCEDURE SQL printed page 1.
NOTE: PROCEDURE SQL used (Total process time):
      real time           0.01 seconds
      cpu time            0.01 seconds
      

48         
49         libname xlxdblib clear;
NOTE: Libref XLXDBLIB has been deassigned.

NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414
NOTE: The SAS System used:
      real time           0.05 seconds
      cpu time            0.06 seconds

docker run --interactive --tty --rm --volume ${PWD}/addons/access-pcfiles:/sasinside --env SAS_LOGS_TO_DISK=true viya-single-container --user sasdemo --batch /sasinside/dcpcfiles.sas
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
