%let id=10;

%let cashost=localhost;
%let casport=5570;

/* macro variables */      
/*-----------------*/
%let sess = mysess;
%let caslib_alias = datalib;
%let dataset = mydata;
%let datasetout = smokeout_&id;
%let datasetin = smokein_&id;


/* options */
/*---------*/
options cashost="&cashost." casport=&casport.;

/* create cas session */
/*--------------------*/
cas &sess.;

/* creates data in WORK */
/*----------------------*/
data &dataset.;
    DO i = 1 TO 500;
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

proc cas ;
table.save / table="&dataset."
name="&datasetout..xlsx"
exportoptions={fileType="excel", sheet="&dataset."} ;
replace=true;
run; quit;


/* count the record for quick validation */  
/*---------------------------------------*/
proc cas;
    session &sess.;
    action recordcount table={name="&datasetout..xlsx"};
    run; 

/* load the data from data source to cas */
/*---------------------------------------*/
proc casutil; 
load casdata="&datasetout..xlsx" casout="&datasetin." 
importOptions=(filetype="excel", sheet="&dataset."); /*load the sheet*/
quit;


/* count the record for quick validation */
/*---------------------------------------*/
proc cas;
    session &sess.;
    action recordcount table={name="&datasetin"};
    ;
run;


/* delete the table from datasource that was created */
/* delete the table(xlsx file) that was created      */
/*---------------------------------------------------*/
proc casutil;
  deletesource casdata="&datasetout..xlsx";
quit;


/* drop the table(s) from CAS server */
/*-----------------------------------*/
proc casutil;
  droptable casdata="&dataset." quiet;
  droptable casdata="&datasetin." quiet;
quit;


/* removes cas session */
/*---------------------*/
cas &sess. terminate;