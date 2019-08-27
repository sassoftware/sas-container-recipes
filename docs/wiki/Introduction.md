## Contents

- [Before You Begin](#before-you-begin)
- [The Basics for Running and Building SAS Viya](#the-basics-for-running-and-building-sas-viya)
- [Considerations for Using Recipes](#considerations-for-using-recipes)
- [SAS Products and Supporting Components](#sas-products-and-supporting-components)
- [Get Support](#get-support)

### Before You Begin

- You must have purchased SAS software in order to use the SAS container recipes. If you are not sure if your organization has purchased SAS software, [contact us](https://www.sas.com/en_us/software/how-to-buy.html) or get [SAS license assistance](https://support.sas.com/en/technical-support/license-assistance.html).

- Instead of using a recipe, you can use a predefined Docker image to run a SAS Viya programming-only container on a single machine. For more information, see the following websites:

  - [SAS for Containers](http://support.sas.com/rnd/containers/)
  - [SAS Product Support for Virtualization Environments](https://support.sas.com/techsup/pcn/virtualization.html)

- To use this guide successfully, you should have a working knowledge of Docker or Kubernetes, and git.

### The Basics for Running and Building SAS Viya 

- Your software can be built using one of two deployment types: full or programming-only.

  - A full deployment enables you to build and run the full suite of SAS Viya products and user interfaces that you ordered. A full deployment is built by using multiple images and Kubernetes.

  - A programming-only deployment supports data scientists and programmers who use SAS Studio or direct programming interfaces such as Python or REST APIs. A programming-only deployment can be built and run by using a single Docker image or by using multiple images. 

    **Note:** A programming-only deployment does not include SAS Drive, SAS Environment Manager, and the complete suite of services that are included with a full deployment. Therefore, make sure that you are providing your users with the features that they require.

- You can use addons found in the addons directory to enhance the base SAS Viya image with SAS/ACCESS, LDAP configuration, and more. For each addon that you plan to include in the build, review the information in [Pre-build Tasks](Pre-build-Tasks) for any prerequisites.

- Your software can be built and run with a single CAS server or multiple CAS servers.

  - Distributing the CAS server across multiple containers allows for massively parallel processing (MPP) by users. To take advantage of MPP, SAS Viya must be built by using multiple containers. An advantage to MPP is that, whenever possible, data is loaded into memory in parallel, which can result in faster load times. Also, the distributed CAS server can be configured for fault tolerance. For example, if a CAS worker fails, another CAS worker can use a redundant copy of the data to continue data analysis.
  - If MPP is not available, the CAS server allows for symmetric multi-processing (SMP) by users, which provides serial loads of data into memory from a supported data source. SMP is a feature of SAS Viya that is available in both a single image or multiple images. 

- A local mirror repository can save you time whenever you run a build, and it protects against download limits.

  - Each time that you build an image of the SAS Viya software, the required RPM files must be accessed. Setting up a local mirror repository for the RPM files can save time because you access the RPM files locally each time that you build or rebuild an image.
  -  If you do not create a local mirror repository, then the RPM files are downloaded from servers that are hosted by SAS, which can take longer. Also, there is a limit to how many times that you can download a SAS Viya software order from the SAS servers.
  - For more information about creating a local mirror repository, see [Create a Mirror Repository](https://go.documentation.sas.com/?docsetId=dplyml0phy0lax&amp;docsetTarget=p1ilrw734naazfn119i2rqik91r0.htm&amp;docsetVersion=3.4) in _SAS Viya for Linux: Deployment Guide_.

### Considerations for Using Recipes
  
  - A programming-only deployment is supported. A full deployment is experimental and includes limited support from SAS.
  - A SAS Viya multi-tenant environment is not supported.
  - High availability is not currently supported for full and multiple deployments using Kubernetes.
  - Persistence is not currently functional when scaling. Scaling down to 0 and back up from 0 will result in the loss of data.

### SAS Products and Supporting Components

This wiki provides information about how to build and run the following SAS Viya software:

- SAS Cloud Analytic Services for SAS Viya 3.4
- SAS Econometrics 8.4
- SAS Optimization 8.4
- SAS Studio 5.1
- SAS Studio 4.4
- SAS Visual Analytics (on SAS Viya) 8.4
- SAS Visual Data Mining and Machine Learning 8.4
- SAS Visual Forecasting 8.4
- SAS Visual Statistics (on SAS Viya) 8.4
- SAS/ACCESS (multiple data sources options) 
- SAS/CONNECT (on SAS Viya)
- SAS/IML (on SAS Viya)
- SAS/QC (on SAS Viya)

**Notes:**
- Your Software Order Email (SOE) lists products and supporting components to which you are entitled. Other software to which you are entitled, such as SAS Studio, might not be listed in the SOE.
- If you ordered SAS/ACCESS Interface to PC Files or SAS/ACCESS Interface to PostgreSQL, each is automatically included when you build and run SAS Viya. 
- Currently, testing has focused on SAS Visual Analytics (on SAS Viya), SAS Visual Data Mining and Machine Learning, SAS Visual Statistics (on SAS Viya), and a subset of the SAS/ACCESS engines supported by SAS Viya. The process described in this guide should also work with other SAS offerings and all supported SAS/ACCESS engines. If you have problems, you can open issues at GitHub for SAS to consider. 

### Get Support

GitHub is used for tracking bugs and feature requests. Please enter tickets via the [GitHub Project Issues Page](https://github.com/sassoftware/sas-container-recipes/issues) for questions and project improvements.
