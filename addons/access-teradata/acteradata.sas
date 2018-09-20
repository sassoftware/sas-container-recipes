%let server=FIXME;
%let username=FIXME;
%let password=FIXME;
%let database=FIXME;
%let engine=teradata;

options yearcutoff=1900;

%macro randomnum(input);
%let mygen=%sysfunc(getoption(notes));
/* options nonotes; */
%global &input;
    data _null_;
    call symput ("&input", substr( reverse( ranuni(0) ),1,5 ) );
    run;
options &mygen;
%mend randomnum;

%randomnum(id);

/* Engine specific variables */
%let ENGCONNOPT=%STR(server="&server." user="&username." password="&password." database="&database."); 

/* assign libname engine */
/*-----------------------*/
libname dblib &engine &ENGCONNOPT;


/* check dbms table dropped */
/*--------------------------*/
proc delete data=dblib.SMKTAB&id.;run;


/* create work dataset */
/*---------------------*/
data work.SMKDAT&id.;
   input name $ age sex $ bdate mmddyy.;
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


/* create dbms table */
/*-------------------*/
data dblib.SMKTAB&id.;
   set work.SMKDAT&id.;
run;

/* read dbms table */
/*-----------------*/
proc sql;
   select count(*) from dblib.SMKTAB&id.;
quit;


/* cleanup */
/*---------*/
proc delete data=dblib.SMKTAB&id.; run;
libname dblib clear;