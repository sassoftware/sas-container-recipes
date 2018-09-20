%let server="FIXME";
%let user=FIXME;

option set = SAS_HADOOP_JAR_PATH =
  "/sasinside/hadoop/jars";
option set = SAS_HADOOP_CONFIG_PATH =
  "/sasinside/hadoop/config";
  
libname hadoop hadoop server=&server.  user=&user;

proc datasets lib=hadoop;
  run;
