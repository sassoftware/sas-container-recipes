%let server="FIXME";
%let user=FIXME;

%let sess=mysess;

cas &sess;

caslib hdlib sessref=&sess
  datasource=(
    srctype="hadoop",
    dataTransferMode="serial",
    username=&server,
    server=&server.,
    hadoopjarpath="/hadoop/jars",
    hadoopconfigdir="/hadoop/config",
    schema="default");
    
    
proc casutil;
list files incaslib="hdlib";
run;
quit;

/* removes cas session */
cas &sess terminate;
