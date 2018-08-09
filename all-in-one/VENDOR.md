# How to Add vendor dependencies

Different SAS/Access Software modules often require you to load or configure vendor specific libraries before the SAS/Access Software is operational.  This "all-in-one" example has a [files/install_vendor.sh](files/install_vendor.sh) that helps automate this, but you have to put the vendor artefacts in a directory under "./vendor" - we cannot make these available from this repo - you have to get them some other way, usually directly from the vendors download page.

# Hadoop

The SAS Documentation describes how to run the hadooptracer script to produce a ./conf and ./jar folder of artefacts that match your hadoop cluster. Copy these artefacts into vendor/hadoop and the ```install_vendor.sh``` will configure SAS/Access to Hadoop for you.

```
mkdir -p $HOME/sas-container-recipes/all-in-one/vendor/hadoop
cp -r ./jar ./conf $HOME/sas-container-recipes/all-in-one/vendor/hadoop
```

# Oracle

You will need to download oracle instant client basic and optionally oracle instant client sqlplus from http://oracle.com, and copy them into vendor/oracle.  If you place a ```tnsnames.ora``` file in the same directory, the script will copy it into the image so your SAS programs can just reference the database nicknames, instead of complicated path= database connections strings.

```
mkdir -p $HOME/sas-container-recipes/all-in-one/vendor/oracle
cp instantclient* $HOME/sas-container-recipes/all-in-one/vendor/oracle
cp tnsnames.ora $HOME/sas-container-recipes/all-in-one/vendor/oracle
``` 
