%let dbuser=FIXME;
%let dbpass=FIXME;
%let dbds=FIXME;

options nodate;

/*************************/
/* ASSIGN LIBNAME ENGINE */
/*************************/

libname x odbc user=&dbuser  password=&dbpass ds=&dbds 
preserve_tab_names=yes preserve_col_names=yes;

/****************************/
/* CHECK DBMS TABLE DROPPED */
/****************************/

proc delete data=x.smoketstdata; run;

/***********************/
/* CREATE WORK DATASET */
/***********************/

data work.tstdata;
   input fname $ age sex $ bdate mmddyy.;
   cards;
amy 3 f 030185
bill 12 m 121277
charlie 35 m 010253
david 19 m 101469
elinor 42 f 080845
pearl 78 f 051222
vera 96 f 101200
frank 24 m 092663
georgia 1 f 040687
henry 46 m 053042
joann 27 f 020461
buddy 66 m 101432
;
run;

/*********************/
/* CREATE DBMS TABLE */
/*********************/

data x.smoketstdata; 
  set work.tstdata;
run;

/*******************/
/* READ DBMS TABLE */
/*******************/
 
proc print data=x.smoketstdata; 
   format FNAME $7. sex $1. bdate date7.;
   title 'proc print of DBMS table';
run;

/***********/
/* CLEANUP */
/***********/
 
proc delete data=x.smoketstdata; run;
libname x clear;