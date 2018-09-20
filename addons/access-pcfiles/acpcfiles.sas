%let xlsx_filepath="/tmp/pcfiltest.xlsx";
%let id=12;
libname xlxdblib sasioxlx &xlsx_filepath;

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

/* create dbms table for dbms=xlsx */
/*---------------------------------*/

proc export data=work.SMKDAT&id.
outfile=&xlsx_filepath
dbms=xlsx replace;
putnames=yes;
run;

/* import dbms table with dbms=xlsx */
/*----------------------------------*/

proc import out=work.xlsx_SMKDAT&id.
datafile=&xlsx_filepath
dbms=xlsx replace;
getnames=Y;
run;

/* read work dataset imported with  dbms=xlsx */
/*------------------------------------------*/
proc sql;
   select count(*) from xlsx_SMKDAT&id.;
quit;

libname xlxdblib clear;