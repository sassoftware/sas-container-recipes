
libname hadoop hadoop server="hive-hadoop-host-name"  user="username";

proc datasets lib=hadoop;
  run;
