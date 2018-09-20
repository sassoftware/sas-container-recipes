%let dbuser=FIXME;
%let dbpass=FIXME;
%let dbdb=FIXME;

%let cashost=localhost;
%let casport=5570;
options cashost="&cashost." casport=&casport.;
%let sess = mysess;
%let caslib_alias = datalib;

/* creates cas session */
cas &sess;

/* creates new caslib */
caslib &caslib_alias sessref=&sess
        datasource=(srctype="odbc",
                    username=&dbuser,
                    password=&dbpass,
                    database=&dbdb,
                    catalog="*");

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
%let dataset = mydata;
%let datasetout = smokeout_&id;
%let datasetin = smokein_&id;

/* creates data in cas */

proc cas;
session &sess;
action runCode submit /
code = "data &dataset;
    DO i = 1 TO 1000;
            j = I-50;
            w = I/10;
            OUTPUT;
    END;
    run; "
    single="yes";
;

run;
quit;

/* saves data from cas to data source */
proc cas ;
   save
   caslib="&caslib_alias"
   name="&datasetout"
   table={caslib="&caslib_alias" ,name="&dataset"};
run;
quit;

/* count the record for quick validation */
proc cas;
    session &sess;
    action recordcount table={casLib="&caslib_alias",name="&datasetout"};
    ;
run;

/* load the data from data source to cas */
proc cas;
    session &sess;
    action loadtable
    caslib="&caslib_alias"
    path="&datasetout"
    casout={caslib="&caslib_alias", name="&datasetin"}
    ;
run;
quit;

/* count the record for quick validation */
proc cas;
    session &sess;
    action recordcount table={casLib="&caslib_alias",name="&datasetin"};
    ;
run;


/* delete the table from datasource that was created */
proc cas;
    session &sess;
    action deleteSource
    caslib="&caslib_alias"
    source="&datasetout"
    ;
run;
quit;

/* removes cas session */
cas &sess terminate;
