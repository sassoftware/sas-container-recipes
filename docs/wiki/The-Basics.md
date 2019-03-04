### Why do I need a local mirror repository?

A local mirror repository can save you time each time you run a build, and it protects you from download limits.

Each time that you build an image of the SAS Viya software, the required RPM files must be accessed. Setting up a local mirror repository for the RPM files can save time because you access the RPM files locally each time that you build or rebuild an image. If you do not create a local mirror repository, then the RPM files are downloaded from servers that are hosted by SAS, which can take longer. Also, there is a limit to how many times that you can download a SAS Viya software order from the SAS servers.

For more information about creating a local mirror repository, see [Create a Mirror Repository](https://go.documentation.sas.com/?docsetId=dplyml0phy0lax&docsetTarget=p1ilrw734naazfn119i2rqik91r0.htm&docsetVersion=3.4) in the _SAS Viya for Linux: Deployment Guide_.

### Where can I find information about installing Docker on CentOS?

Check out the Docker documentation:
*  [Community Edition on CentOS](https://docs.docker.com/install/linux/docker-ce/centos/). Links for other operating systems are also on that page.
*  [Enterprise Edition](https://docs.docker.com/install/linux/docker-ee/centos/).

### How do I install kubectl?

kubectl is the Kubernetes command-line tool to deploy and manage applications on Kubernetes. Go to the [kubectl website](https://kubernetes.io/docs/tasks/tools/install-kubectl/) in order to get instructions on how to install the utility. It will also require a Kubernetes environment and configuration file.

### How do I find Docker images that contain a particular layer?

Starting with the 18m10, the Docker images built contain specific Docker labels. These are:

    * sas.recipe.version
    * sas.layer.<addon layer>

To find images that are for the 18m10 release, you can run

```
docker images --filter "label=sas.recipe.version=18.10.0"
```

If you are not sure of the version, run `docker inspect` on one of the images to see the label values for that image.

To find images that support the access-odbc layer you can run

```
docker images --filter "label=sas.layer.access-odbc"
```

### How do I build with updated SAS Viya software?

To include any future updates of the SAS Viya 3.4 software, you must rebuild recipes with the updated SAS Viya 3.4 software that is available from the SAS servers, or from a local mirror repository of the updated software.

### How do I remove `<none>` images?

An error during the build process could result in dangling images which represent intermediate build containers. If you encounter these, see [Single Container Errors During Build](Build-and-Run-SAS-Viya-Multiple-Containers#errors-during-build) or [Multiple Container Errors During Build](Build-and-Run-SAS-Viya-Multiple-Containers#errors-during-build).