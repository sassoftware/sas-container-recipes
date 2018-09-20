%let cashost=localhost;
%let casport=5570;

%let pghost=FIXME;
%let pguser=FIXME;
%let pgpass=FIXME;
%let pgdb=FIXME;
%let pgport=5432;

%macro randomnum(input);
%let mygen=%sysfunc(getoption(notes));
options nonotes;
%global &input;
    data _null_;
    call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
    run;
options &mygen;
%mend randomnum;

%randomnum(id);


/* macro variables */      
/*-----------------*/
%let sess = mysess;
%let caslib_alias = datalib;
%let dataset = mydata;
%let datasetout = smokeout_&id;
%let datasetin = smokein_&id;

%let DCCONOPT=%STR(datasource=(srctype="postgres",server="&pghost.",user="&pguser.",password="&pgpass.",database="&pgdb."));


/* options */
/*---------*/
options cashost="&cashost." casport=&casport.;

/* create cas session */
/*--------------------*/
cas &sess.;


/* create new caslib to SAS Data Connector */
/*-----------------------------------------*/
caslib &caslib_alias. sessref=&sess. &DCCONOPT.; 


/* creates data in WORK */
/*----------------------*/
data &dataset.;
    DO i = 1 TO 1000;
            j = I-50;
            w = I/10;
            OUTPUT;
    END;
run; 


/* loads data in cas */
/*-------------------*/
proc casutil;
 load data=&dataset.;
quit;


/* saves data from cas to data source */
/*------------------------------------*/
proc casutil;
  save casdata="&dataset." casout="&datasetout.";
quit;


/* count the record for quick validation */
/*---------------------------------------*/
proc cas;
    session &sess.;
    action recordcount table={casLib="&caslib_alias.",name="&datasetout."};
    ;
run;


/* load the data from data source to cas */
/*---------------------------------------*/
proc casutil;
  load casdata="&datasetout." casout="&datasetin.";
quit;


/* count the record for quick validation */
/*---------------------------------------*/
proc cas;
    session &sess.;
    action recordcount table={casLib="&caslib_alias.",name="&datasetin."};
    ;
run;


/* delete the table from datasource that was created */
/*---------------------------------------------------*/
proc casutil;
  deletesource casdata="&datasetout.";
quit;


/* drop the table(s) from CAS server */
/*-----------------------------------*/
proc casutil;
  droptable casdata="&datasetout." quiet;
  droptable casdata="&dataset." quiet;
  droptable casdata="&datasetin." quiet;
quit;


/* removes cas session */
/*---------------------*/
cas &sess. terminate;