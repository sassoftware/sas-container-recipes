# Overview

The content in this directory provides a simple way to smoke test the
SAS/ACCESS to PostgreSQL orderable.

# File list

* acpostgres.sas
    * This SAS code that can be submitted in SAS Studio or via the batchserver
      which will create and drop a table. This is exercising SAS Foundation and
      that the SAS/ACCESS interface to PostgreSQL is configured correctly.
* dcpostgres.sas
    * This SAS code that can be submitted in SAS Studio or via the batchserver
      which will create and drop a table. This is exercising Cloud Analytics
      Services and validating that the Data Connector to PostgreSQL is
      configured correctly.

# How to Use

## SAS Studio

* Log into SAS Studio __http://\<hostname of Docker host\>:8081__
* Paste the code from either _acpostgres.sas_ or _dcpostgres.sas_ into the code
  window.
* Edit the 'FIXME' text in _acpostgres.sas_ and _dcpostgres.sas_ with the
  correct values for the environment.
* Run code
* There should be no errors and should get something like the following as a log

```
# Here is the log for dcpostgres.sas

 1          OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 72
 73
 74         %let cashost=localhost;
 75         %let casport=5570;
 76
 77         %let pghost=pungo.unx.sas.com;
 78         %let pgdb=tktstst4;
 79         %let pguser=tktstst4;
 80         %let pgpass=Tester4;
 81         %let pgport=5432;
 82
 83         %macro randomnum(input);
 84         %let mygen=%sysfunc(getoption(notes));
 85         options nonotes;
 86         %global &input;
 87             data _null_;
 88             call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
 89             run;
 90         options &mygen;
 91         %mend randomnum;
 92
 93         %randomnum(id);
 94
 95
 96         /* macro variables */
 97         /*-----------------*/
 98         %let sess = mysess;
 99         %let caslib_alias = datalib;
 100        %let dataset = mydata;
 101        %let datasetout = smokeout_&id;
 102        %let datasetin = smokein_&id;
 103
 104        %let
 104      ! DCCONOPT=%STR(datasource=(srctype="postgres",server="&pghost.",user="&pguser.",password="&pgpass.",database="&pgdb."));
 105
 106
 107        /* options */
 108        /*---------*/
 109        options cashost="&cashost." casport=&casport.;
 110
 111        /* create cas session */
 112        /*--------------------*/
 113        cas &sess.;
 NOTE: The session MYSESS connected successfully to Cloud Analytic Services localhost using port 5570. The UUID is
       60fd3a31-5fdb-904a-a550-a96aa0e89fe7. The user is sasdemo and the active caslib is CASUSER(sasdemo).
 NOTE: The SAS option SESSREF was updated with the value MYSESS.
 NOTE: The SAS macro _SESSREF_ was updated with the value MYSESS.
 NOTE: The session is using 0 workers.
 114
 115
 116        /* create new caslib to SAS Data Connector */
 117        /*-----------------------------------------*/
 118        caslib &caslib_alias. sessref=&sess. &DCCONOPT.;
 NOTE: 'DATALIB' is now the active caslib.
 NOTE: Cloud Analytic Services added the caslib 'DATALIB'.
 NOTE: Action to ADD caslib DATALIB completed for session MYSESS.
 119
 120
 121        /* creates data in WORK */
 122        /*----------------------*/
 123        data &dataset.;
 124            DO i = 1 TO 1000;
 125                    j = I-50;
 126                    w = I/10;
 127                    OUTPUT;
 128            END;
 129        run;

 NOTE: The data set WORK.MYDATA has 1000 observations and 3 variables.
 NOTE: DATA statement used (Total process time):
       real time           0.00 seconds
       cpu time            0.00 seconds


 130
 131
 132        /* loads data in cas */
 133        /*-------------------*/
 134        proc casutil;
 NOTE: The UUID '60fd3a31-5fdb-904a-a550-a96aa0e89fe7' is connected using session MYSESS.
 135         load data=&dataset.;
 NOTE: WORK.MYDATA was successfully added to the "DATALIB" caslib as "MYDATA".
 136        quit;

 NOTE: PROCEDURE CASUTIL used (Total process time):
       real time           0.21 seconds
       cpu time            0.01 seconds


 137
 138
 139        /* saves data from cas to data source */
 140        /*------------------------------------*/
 141        proc casutil;
 NOTE: The UUID '60fd3a31-5fdb-904a-a550-a96aa0e89fe7' is connected using session MYSESS.
 142          save casdata="&dataset." casout="&datasetout.";
 NOTE: Performing serial SaveTable action using SAS Data Connector to PostgreSQL.
 NOTE: Cloud Analytic Services saved the file smokeout_35437 in caslib DATALIB.
 NOTE: The Cloud Analytic Services server processed the request in 62.441284 seconds.
 143        quit;

 NOTE: PROCEDURE CASUTIL used (Total process time):
       real time           1:02.44
       cpu time            0.02 seconds


 144
 145
 146        /* count the record for quick validation */
 147        /*---------------------------------------*/
 148        proc cas;
 149            session &sess.;
 150            action recordcount table={casLib="&caslib_alias.",name="&datasetout."};
 151            ;
 152        run;
 NOTE: Active Session now mysess.
 NOTE: Performing serial LoadTable action using SAS Data Connector to PostgreSQL.

 153
 154
 155        /* load the data from data source to cas */
 156        /*---------------------------------------*/

 NOTE: PROCEDURE CAS used (Total process time):
       real time           0.16 seconds
       cpu time            0.05 seconds


 157        proc casutil;
 NOTE: The UUID '60fd3a31-5fdb-904a-a550-a96aa0e89fe7' is connected using session MYSESS.
 158          load casdata="&datasetout." casout="&datasetin.";
 NOTE: Performing serial LoadTable action using SAS Data Connector to PostgreSQL.
 NOTE: Cloud Analytic Services made the external data from smokeout_35437 available as table SMOKEIN_35437 in caslib DATALIB.
 NOTE: The Cloud Analytic Services server processed the request in 0.034893 seconds.
 159        quit;

 NOTE: PROCEDURE CASUTIL used (Total process time):
       real time           0.03 seconds
       cpu time            0.01 seconds


 160
 161
 162        /* count the record for quick validation */
 163        /*---------------------------------------*/
 164        proc cas;
 165            session &sess.;
 166            action recordcount table={casLib="&caslib_alias.",name="&datasetin."};
 167            ;
 168        run;
 NOTE: Active Session now mysess.

 169
 170
 171        /* delete the table from datasource that was created */
 172        /*---------------------------------------------------*/

 NOTE: PROCEDURE CAS used (Total process time):
       real time           0.02 seconds
       cpu time            0.01 seconds


 173        proc casutil;
 NOTE: The UUID '60fd3a31-5fdb-904a-a550-a96aa0e89fe7' is connected using session MYSESS.
 174          deletesource casdata="&datasetout.";
 NOTE: Cloud Analytic Services removed the source data smokeout_35437 from caslib DATALIB.
 NOTE: The Cloud Analytic Services server processed the request in 0.074274 seconds.
 175        quit;

 NOTE: PROCEDURE CASUTIL used (Total process time):
       real time           0.07 seconds
       cpu time            0.01 seconds


 176
 177
 178        /* drop the table(s) from CAS server */
 179        /*-----------------------------------*/
 180        proc casutil;
 NOTE: The UUID '60fd3a31-5fdb-904a-a550-a96aa0e89fe7' is connected using session MYSESS.
 181          droptable casdata="&datasetout." quiet;
 NOTE: The Cloud Analytic Services server processed the request in 0.000578 seconds.
 182          droptable casdata="&dataset." quiet;
 NOTE: The Cloud Analytic Services server processed the request in 0.000685 seconds.
 183          droptable casdata="&datasetin." quiet;
 NOTE: The Cloud Analytic Services server processed the request in 0.00045 seconds.
 184        quit;

 NOTE: PROCEDURE CASUTIL used (Total process time):
       real time           0.00 seconds
       cpu time            0.00 seconds


 185
 186
 187        /* removes cas session */
 188        /*---------------------*/
 189        cas &sess. terminate;
 NOTE: Deletion of the session MYSESS was successful.
 NOTE: The default CAS session MYSESS identified by SAS option SESSREF= was terminated. Use the OPTIONS statement to set the
       SESSREF= option to an active session.
 NOTE: Request to TERMINATE completed for session MYSESS.
 190
 191
 192        /*-------------------------------------------------------------------
 193         *  NAME     : dcpostgres_s.sas
 194         *  COMMENTS : 14aug18. Kevin Kantesaria. Created.
 195         *  UPDATE   :
 196        *------------------------------------------------------------------*/
 197
 198        OPTIONS NONOTES NOSTIMER NOSOURCE NOSYNTAXCHECK;
 211
```

## Batchserver

* Edit the 'FIXME' text in _acpostgres.sas_ and _dcpostgres.sas_ with the
  correct values for the environment.
* From the parent directory, run the following

```
docker run --interactive --tty --rm --volume ${PWD}/addons/access-postgres:/sasinside --env SAS_LOGS_TO_DISK=true viya-single-container --batch /sasinside/acpostgres.sas
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
Running "exec --batch /sasinside/acpostgres.sas"
Starting Cloud Analytic Services...
CAS Consul Health:
    Consul not present
    CAS bypassing Consul serfHealth status check of CAS nodes

/sasinside /tmp/sas
sourcing /opt/sas/viya/config/etc/sysconfig/sas-javaesntl/sas-java

1                                                          The SAS System                        Friday, August 31, 2018 06:39:00 PM

NOTE: Copyright (c) 2016 by SAS Institute Inc., Cary, NC, USA.
NOTE: SAS (r) Proprietary Software V.03.04 (TS4M0 MBCS3170)
      Licensed to lots o stuff, Site 70180938.
NOTE: This session is executing on the Linux 3.10.0-693.el7.x86_64 (LIN X64) platform.

NOTE: Analytical products:

      SAS/STAT 14.3
      SAS/ETS 14.3
      SAS/OR 14.3
      SAS/IML 14.3
      SAS/QC 14.3

NOTE: Additional host information:

 Linux LIN X64 3.10.0-693.el7.x86_64 #1 SMP Thu Jul 6 19:56:57 EDT 2017 x86_64 CentOS Linux release 7.5.1804 (Core)

NOTE: SAS initialization used:
      real time           0.03 seconds
      cpu time            0.03 seconds


NOTE: AUTOEXEC processing beginning; file is /opt/sas/viya/config/etc/batchserver/default/autoexec.sas.


NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.00 seconds



NOTE: AUTOEXEC processing completed.

1
2
3          %let pghost=postgresql.server.com;
4          %let pgdb=database;
5          %let pguser=user;
6          %let pgpass=password;
7          %let pgport=5432;
8          %let engine=postgres;
9
10         %macro randomnum(input);
11         %let mygen=%sysfunc(getoption(notes));
12         options nonotes;
13         %global &input;
14             data _null_;
15             call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
16             run;
17         options &mygen;
18         %mend randomnum;
19
20         %randomnum(id);
21
22
23         options yearcutoff=1900;
♀2                                                          The SAS System                        Friday, August 31, 2018 06:39:00 PM

24
25         %let ENGCONNOPT=%STR(server="&pghost." port=&pgport. user="&pguser." password="&pgpass." database="&pgdb.");
26
27         /* assign libname engine */
28         /*-----------------------*/
29         libname dblib &engine &ENGCONNOPT;
NOTE: Libref DBLIB was successfully assigned as follows:
      Engine:        POSTGRES
      Physical Name: postgresql.server.com

30
31
32         /* check dbms table dropped */
33         /*--------------------------*/
34         proc delete data=dblib.SMKTAB&id.;run;

WARNING: File DBLIB.SMKTAB44947.DATA does not exist.
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.01 seconds
      cpu time            0.01 seconds

35
36
37         /* create work dataset */
38         /*---------------------*/
39         data work.SMKDAT&id.;
40            input name $ age sex $ bdate mmddyy.;
41            cards;

NOTE: The data set WORK.SMKDAT44947 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.00 seconds
      cpu time            0.01 seconds

54         ;
55         run;
56
57
58         /* create dbms table */
59         /*-------------------*/
60         data dblib.SMKTAB&id.;
61            set work.SMKDAT&id.;
62         run;

NOTE: There were 12 observations read from the data set WORK.SMKDAT44947.
NOTE: The data set DBLIB.SMKTAB44947 has 12 observations and 4 variables.
NOTE: DATA statement used (Total process time):
      real time           0.03 seconds
      cpu time            0.00 seconds

63
64
65         /* read dbms table */
66         /*-----------------*/
67         proc sql;
68            select count(*) from dblib.SMKTAB&id.;
♀3                                                          The SAS System                        Friday, August 31, 2018 06:39:00 PM

69         quit;
NOTE: The PROCEDURE SQL printed page 1.
NOTE: PROCEDURE SQL used (Total process time):
      real time           0.04 seconds
      cpu time            0.04 seconds

70
71
72         /* cleanup */
73         /*---------*/
74         proc delete data=dblib.SMKTAB&id.; run;

NOTE: Deleting DBLIB.SMKTAB44947 (memtype=DATA).
NOTE: PROCEDURE DELETE used (Total process time):
      real time           0.05 seconds
      cpu time            0.00 seconds


75         libname dblib clear;
NOTE: Libref DBLIB has been deassigned.
76
77
78         /*------------------------------------------------------------------
79          *  NAME     : accpostgres.sas
80          *  COMMENTS : 10aug18. Peng Li (Oliver). Created.
81          *  UPDATE   :
82          *------------------------------------------------------------------*/

NOTE: SAS Institute Inc., SAS Campus Drive, Cary, NC USA 27513-2414
NOTE: The SAS System used:
      real time           0.29 seconds
      cpu time            0.16 seconds

/tmp/sas

Shutting down!

    Stop httpd
httpd (no pid file) not running
    Stop SAS services

# When running the dcpostgres code, you need to pass in a user that has a 
# .authinfo file setup in their home directory

docker run --interactive --tty --rm --volume ${PWD}/addons/access-postgres:/sasinside --env SAS_LOGS_TO_DISK=true viya-single-container --user sasdemo --batch /sasinside/dcpostgres.sas
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
