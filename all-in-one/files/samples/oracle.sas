
libname myora oracle path="database"  user="scott" password="tiger";

proc datasets data=oracle;
  run;
