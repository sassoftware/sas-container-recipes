
cas mycas;

caslib hdlib 
  datasource=(
    srctype="hadoop",
    dataTransferMode="serial",
    username="username",
    server="hive-hadoop-host-name",
    hadoopjarpath="/opt/sas/viya/config/data/hadoop/lib",
    hadoopconfigdir="/opt/sas/viya/config/data/hadoop/conf",
    schema="default");
    
    
proc casutil;
list files incaslib="hdlib";
run;
