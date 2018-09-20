# Overview

The content in this directory provides a simple way to smoke test the 
SAS/ACCESS to Hadoop orderable.

# File list

* hadoop_cas.settings:
    * The contents of this file contain environment variables needed to ensure
      Java code is executed properly.
* achadoop_external.sas
    * This SAS code that can be submitted in SAS Studio or via the batchserver.
      This is exercising SAS Foundation and that the SAS/ACCESS iterface to
      Hadoop is configured correctly. This is expecting the Hadoop configuaration
      and jar files to be outside the container.
* dchadoop_external.sas
    * This SAS code that can be submitted in SAS Studio or via the batchserver.
      This is exercising Cloud Analytics Services and validating that the Data
      Connector to Hadoop is configured correctly. This is expecting the Hadoop 
      configuaration and jar files to be outside the container.
* achadoop_internal.sas
    * This SAS code that can be submitted in SAS Studio or via the batchserver.
      This is exercising SAS Foundation and that the SAS/ACCESS iterface to
      Hadoop is configured correctly. This is expecting the Hadoop configuaration
      and jar files to be inside the container.
* dchadoop_internal.sas
    * This SAS code that can be submitted in SAS Studio or via the batchserver.
      This is exercising Cloud Analytics Services and validating that the Data
      Connector to Hadoop is configured correctly. This is expecting the Hadoop
      configuaration and jar files to be inside the container.

# How to build (OPTIONAL)

NOTE: This is not a neccessary step. One can collect the Hadoop configuration
and jar files and have them in a volume that is mounted to the container at 
startup.

If one wants to create an image that has the Hadoop configuration and jar files
bake into the image, collect the configuration and jar files and place them
under the hadoop directory. This should give a directory structure like

```
${PWD}/hadoop/config
${PWD}/hadoop/jars
```

Then build the image

```
docker build --file Dockerfile . --tag svc-access-hadoop
```

This will put the files in the _/hadoop_ directory. You will want to use 
the _achadoop_internal.sas_ and _dchadoop_internal.sas_ examples when testing.

# How to Use

The _achadoop_external.sas_ and _dchadoop_external.sas_ test code work under 
the assumption that your Hadoop libraries and configs are located in the following 
location inside the container:

* JARs: /sasinside/hadoop/jars
* Configuration: /sasinside/hadoop/config

To follow along with these examples, place a directory named _hadoop_ inside
this directory containing the _jars_ and _config_ directories before starting
the container.

## SAS Studio

* Log into SAS Studio __http://\<hostname of Docker host\>:8081__
* Paste the code from either _achadoop_external.sas_ or _dchadoop_external.sas_ into the code
  window.
* Edit the 'FIXME' text in _achadoop_external.sas_ and _dchadoop_external.sas_ with the 
  correct values for the environment.
* Run code
* There should be no errors and should get something like the following as a log
```
TODO: Paste log here
```

## Batchserver

* Edit the 'FIXME' text in _achadoopi_external.sas_ and _dchadoop_external.sas_ with the 
  correct values for the environment.
* From the parent directory, run the following

```
docker run --interactive --tty --rm --volume ${PWD}/addons/access-hadoop:/sasinside svc-access-hadoop --batch /sasinside/achadoop.sas
TODO: paste log
```

When running the dcredshift code, you need to pass in a user that has a .authinfo file setup in their home directory

```
docker run --interactive --tty --rm --volume ${PWD}/addons/access-hadoop:/sasinside svc-access-hadoop --user sasdemo --batch /sasinside/dchadoop.sas
TODO: paste log
```

# Copyright

Copyright 2018 SAS Institute Inc.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

&nbsp;&nbsp;&nbsp;&nbsp;https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
