*option set=SAS_HADOOP_CONFIG_PATH="path-to-config-files";
*option set=SAS_HADOOP_JAR_PATH="path-to-jar-files";

libname hadoop hadoop server="hive-hadoop-host-name"  user="username";

proc datasets data=hadoop;
  run;
