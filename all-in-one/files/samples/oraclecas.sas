
cas mycas;

caslib myora 
  datasource=(
    srctype="oracle",
    dataTransferMode="serial",
    username="username",
    password="password",
    path="oracle-database",
    );
    
    
proc casutil;
list files incaslib="myora";
run;
