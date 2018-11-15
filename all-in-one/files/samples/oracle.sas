
libname myora oracle path="database"  user="scott" password="tiger";

proc datasets lib=oracle;
  run;
