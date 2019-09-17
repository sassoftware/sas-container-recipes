## Contents

- [Configure Your Environment with SAS Environment Manager](#configure-your-environment-with-sas-environment-manager)
- [(Optional) Regenerating Manifests](#optional-regenerating-manifests)
- [(Optional) Converting an Environment from CAS SMP to CAS MPP](#optional-converting-an-environment-from-cas-smp-to-cas-mpp)
- [(Optional) Verify Bulk Loaded Configuration](#optional-verify-bulk-loaded-configuration)
- [(Optional) Create a Local Copy of the Documentation](#optional-create-a-local-copy-of-the-documentation)

## Configure Your Environment with SAS Environment Manager

**Notes:** 
- The following tasks are applicable for a full deployment. Skip this section if you performed a programming-only deployment.
- The examples use *sas-viya* for the namespace. If you created a different namespace, use that value.

### Sign In as the sasboot User

Your SAS environment is deployed with an initial administrator account that is named sasboot. The password for this account has expired by default, so you must reset the password before you can sign in.

To reset the password:

1. Locate the most recent log for the SAS Logon service in /var/log/sas/viya/saslogon/default.

1. Search the log for the characters sasboot:

    ```
    kubectl -n sas-viya get pods | grep coreservices
    kubectl -n sas-viya exec -it sas-viya-coreservices-<uuid> -- ls -l /var/log/sas/viya/saslogon/default
    kubectl -n sas-viya exec -it sas-viya-coreservices-<uuid> -- grep 'sasboot' /var/log/sas/viya/saslogon/default/sas- 
    saslogon_date-and-time-stamp.log 2> /dev/null
    ```
    
    Here is a typical message:

    ```
    Reset password for initial user sasboot using link: /SASLogon/reset_password?code=xxxxxx
    ```

3. Sign in from a URL with this format:

    `https://ingress-path/SASLogon/reset_password?code=password`

    Make a note of this URL to share with any other users of your SAS Viya software.

4. Follow the instructions on the displayed web page to reset the password.

    **Note:** If the URL has expired, you will need to restart the coreservices pod:

    `kubectl -n sas-viya delete pod sas-viya-coreservices-<uuid>`
    
    Then go to the log and obtain the new URL. The URL expires 24 hours after the SAS Logon service restarts. For security purposes, the URL that is specified in a browser or in a text editor also expires, even if the password is not reset.

    After you reset the password, SAS Environment Manager automatically opens in your browser.

5. Click **Yes** for all the assumable groups so that you have the permissions to perform subsequent tasks.

### Configure the Connection to Your Identity Provider

Configure the connection to your identity provider before your users can access SAS Environment Manager and SAS Visual Analytics.

While signed in as sasboot, configure the connection to your identity provider:

**Note:** Only LDAP-based identity providers are supported. You need to have basic familiarity with LDAP administration. For more information about the properties that are relevant for this procedure, see [sas.identities.providers.ldap](http://documentation.sas.com/?cdcId=calcdc&amp;cdcVersion=3.4&amp;docsetId=calconfig&amp;docsetTarget=n08000sasconfiguration0admin.htm#n08044sasconfiguration0admin) in  _SAS Viya Administration: Configuration Properties_.

1. Select the wrench from the side menu to open the Configuration page.

1. On the Configuration page, select **Basic Services** from the list, and then select the **Identities** service from the list of services.

3. To configure user properties, in the **sas.identities.providers.ldap.user** section, click **New Configuration**:

    1. Specify a value for the **baseDN** required field. For the remaining fields, review the default values and make changes, as necessary. The default values are appropriate for most sites.

        **Note:** When using the LDAP protocol, passwords are transmitted over the network as clear-text. To secure the deployment, SAS recommends that you configure encrypted LDAP connections. For more information, see [Encrypt LDAP Connections](http://documentation.sas.com/?docsetId=calencryptmotion&amp;docsetTarget=n1xdqv1sezyrahn17erzcunxwix9.htm&amp;docsetVersion=3.4#p1bai319815977n1bzdyyxr3d5he) in _Encryption in SAS Viya: Data in Motion_.

        For each property that represents a user-level field in SAS, specify a corresponding property in the LDAP server software.

        **Tip:** Consider specifying a custom filter to limit the user accounts that SAS Viya returns from your LDAP server.
 
    2. Click **Save**.

4. To configure group properties, in the **sas.identities.providers.ldap.group** section, click **New Configuration**. In the **New Configuration** window:

    1. Specify a value for the **baseDN** required field. For the remaining fields, review the default values and make changes, as necessary. The default values are appropriate for most sites.

        For each property that represents a group-level field in SAS, specify a corresponding property in the LDAP server software.

        **Tip:** Consider specifying a custom filter to limit the accounts that SAS Viya returns from your LDAP server.

    2. Click **Save**.

5. To configure connection properties, in the **sas.identities.providers.ldap.connection** section, click **New Configuration**. In the **New Configuration** window:

    1. Specify values for the following required fields: **host** , **password** , **port** , **url** , and **userDN**. For the remaining fields, review the default values and make changes, as necessary. The default values are appropriate for most sites.

    2. Click **Save**.

6. To verify user and group information, from the SAS Environment Manager side menu, select **New** to open the Users page.

    1. On the Users page, select **Users** from the list in the toolbar. Your users should appear after a few minutes. It is not necessary to restart any servers or services. Then select **Groups** from the list to display your groups.

    2. Verify that user and group information is displayed correctly. If not, make any necessary changes to the identities service properties.

7. Restart the Identities and SAS Logon Manager services by starting a new coreservices pod:

    `kubectl -n sas-viya delete pod sas-viya-coreservices-<uuid>`

### Set Up Administrative Users

While you are signed in to SAS Environment Manager as the sasboot user, set up at least one SAS Administrator user, as follows:

1. On the Users page in SAS Environment Manager, select **Custom Groups** from the list in the toolbar.

1. In the left pane, click **SAS Administrators**.

1. In the **Members** section of the right pane, click the Edit icon, and add one or more members to the group (including your own account, if applicable).

1. Sign out from SAS Environment Manager so that you are no longer signed in as the sasboot user.

1. If you added your own account to the SAS Administrators group, you can sign on again to SAS Environment Manager using that account.

    Open SAS EnvironmentManager from a URL with the following format:

    `https://ingress-path/SASEnvironmentManager`

    **Tip:** Since SAS Administrators is an assumable group, the following prompt is displayed: **Do you want to opt in to all of your assumable groups?**. Select **Yes** if you want the extra permissions that are associated with the SAS Administrators group. The selection remains in effect until you sign out.

### Sign In Using LDAP Credentials

Open SAS Environment Manager from a URL with the following format:

`https://ingress-path/SASEnvironmentManager`

Sign in as one of the SAS Administrators that you set up in the [Set Up Administrative Users](#set-up-administrative-users).

### Configure the Connection to the Mail Service

Configure the connection to your mailservice. Complete these steps while you are signed in as one of theSAS Administrators.

1. Select the wrench icon from the side menu to open the Configuration page.

1. On the Configuration page, select **Basic Services** from the list, and then select **Mail service** from the list of services.

3. In the **sas.mail** section, click the Edit icon. In the Edit Configuration window,follow these steps:

    1. Specify a value for the following required fields: **host** and **port**. For the remaining fields, review the default values and make changes, as necessary. The default values are appropriate for most sites.

    1. Click **Save**.

4. (Optional) To enable the health check for the mail service, perform the following steps.

    1. Select the wrench icon from the side menu to open the Configuration page.

    1. On the Configuration page, select **Basic Services** from the list, and then select **Mail service** from the list of services.

    1. In the **management.health.mail** section, click the Edit icon.

    1. Set the **enabled** toggle to **on**.

    1. Click **Save**.

    When this toggle is set, health checks will be enabled after the mail service is restarted. If the mail host is not configured or is configured incorrectly, or if it cannot connect to the SMTP mail server, the mail service will indicate that it is in a failed state.

5. Restart the mail service.

    `kubectl -n sas-viya delete pod sas-viya-coreservices-<uuid>`

### Disable the Password Reset Feature and Reset the sasboot Password

After you are finished setting up LDAP and the initial administrative users, you should reset the password for the sasboot user. For additional security, you can then disable the password reset feature. This action prevents password reset links from being written to the log each time the SASLogon service is restarted.

1. Sign in to SAS Environment Manager as an administrative user and select the wrench icon from the side menu to open the Configuration page.

1. On the Configuration page, select **Definitions** from the drop-down list.

1. In the left pane, select **sas.logon.initial**. Then click **New Configuration** at the top of the right pane. If a definition already exists, you can select the Edit icon to edit the existing definition.

1. In the New sas.logon.initial Configuration window or the Edit sas.logon.initial Configuration window, set **reset.enabled** to **off**.

1. Click **Save**.

1. Restart the SAS LogonManager services:

    `kubectl -n sas-viya delete pod sas-viya-coreservices-<uuid>`

    For more information, see [General Servers and Services: Operate](http://documentation.sas.com/?cdcId=calcdc&amp;cdcVersion=3.4&amp;docsetId=calchkadm&amp;docsetTarget=n00003ongoingtasks00000admin.htm&amp;locale=en) in  _SAS Viya Administration: General Servers and Services_.

    **Note:** After you disable this feature, you can still change the sasboot password if the existing password is known. Enter the URL for SAS Viya with the path /SASLogon/change_password. If you are already signed in as another user, first sign out and then sign back in as sasboot using the current password. You can then complete the steps to change the password.

### Configure SAS Viya to Encrypt the LDAP Connection

SAS Viya supports encrypted connections between the LDAP client and server. To configure a secure LDAP connection, see [Encrypt  LDAP Connections](http://documentation.sas.com/?docsetId=calencryptmotion&amp;docsetTarget=n1xdqv1sezyrahn17erzcunxwix9.htm&amp;docsetVersion=3.4#p1bai319815977n1bzdyyxr3d5he) in _Encryption in SAS Viya: Data in Motion._

## (Optional) Regenerating Manifests

If the deployment manifests that were generated in builds/full/manifests or builds/multiple/manifests need to be updated, perform the following post-build steps to regenerate the manifests without re-running the entire build process. 

1. If you want to provide custom configuration, edit the manifests_usermods.yml file 
in the sas-container-recipes project directory. For more information, see 
[Kubernetes Manifest Inputs](Pre-build-Tasks#kubernetes-manifest-inputs) (a pre-build task).

1. If you want to provide an updated sitedefault.yml file, the file must first be base64 encoded, and then added to the `custom_services:` section of the manifests_usermods.yml file: 
    
    ```
    ## change to the container recipe folder
    cd sas-container-recipes

    ## usually present, but needed for base64 command
    sudo yum install -y coreutils

    ## encode the content of the file
    sitedefault_base64="$(base64 -w 0 sitedefault.yml)"

    ## verify that output was produced
    echo $sitedefault_base64

    ## append the section containing the encoded sitedefault content
    cat >> ./manifests_usermods.yml <<EOF

    ## appended content of sitedefault for consul
    custom_services:
      consul:
        deployment_overrides:
          environment:
            - "CONSUL_KEY_VALUE_DATA_ENC=$sitedefault_base64"
    EOF
    ```
    
    **Note:** The preceding configuration adds a new `custom_services:` section to the manifests_usermods.yml file. If the `custom_services:` section already exists, you can perform one of the following steps to update the file:
    
    * Manually add all the unique lines shown above for `custom_services:` to the existing section, and then remove the new `custom_services:` section that was added.
    * Instead of running the `cat` command, paste in the new lines, and then make sure that the value for `CONSUL_KEY_VALUE_DATA_ENC` is the encoded string from `$sitedefault_base64`.

1. Execute the build script with the `--generate-manifests-only` argument and the deployment type of the previous build.

   Here is an example of executing the script with the `--type full` deployment type.
   
   `./build.sh --generate-manifests-only --type full`
 
   **Note:** Depending on the deployment type, the new manifests will be generated in the builds/full/manifests/ or builds/multiple/manifests/ directory. The symbolic link for builds/full or builds/multiple will point 
to the most recent timestamped build directory, such as 
builds/multiple-2019-04-10-15-27-56. Regenerating the manifests will not make 
a new timestamped builds/full or builds/multiple directory. If you generate the
manifests multiple times, there will be more than one timestamped manifest 
directory in the builds/full or builds/multiple directory. 

## (Optional) Converting an Environment from CAS SMP to CAS MPP

By default, the CAS deployment is set up as SMP. If a MPP environment is needed, perform one of the following steps:

* If you have not yet deployed the environment, regenerate manifests. See [Kubernetes Manifest Inputs](Pre-build-Tasks#kubernetes-manifest-inputs) (a pre-build task) for information about editing the manifests_usermods.yml file to support MPP mode.
* If you have already deployed the environment:
    1. Scale down the CAS controller to 0: 

        `kubectl -n sas-viya scale statefulsets sas-viya-cas --replicas=0`

    1. Edit the CAS configmap and set the cascfg_mode to "mpp": 

        `kubectl -n sas-viya edit configmap sas-viya-cas`

    1. Scale up the CAS controller to 1: 

        `kubectl -n sas-viya scale statefulsets sas-viya-cas --replicas=1`

    1. Scale up the CAS workers: 

        `kubectl -n sas-viya scale deployment.v1.apps/sas-viya-cas-worker --replicas=3`

  **Important:**
  - The examples use *sas-viya* for the namespace. If you created a different namespace, use that value.
  - When scaling CAS workers, be aware that data will not automatically be reloaded to either take advantage of new CAS workers just added to the cluster or remove data before a CAS worker is removed from the cluster. If you scale up the CAS workers, you will need to reload the data in order to distribute it.
  - It is strongly recommended that you do not set up auto-scaling rules.

## (Optional) Verify Bulk Loaded Configuration

For a full deployment, if you performed the [Bulk Loading of Configuration Values](Pre-build-Tasks#bulk-loading-of-configuration-values) pre-build task, you want to confirm that the key-value pairs were loaded correctly. To do this, view the configuration properties for a configuration definition such as, SAS Logon Manager, in SAS Environment Manager to verify that the specified values are present. For more information, follow the first five steps in [Edit Configuration Instances](https://go.documentation.sas.com/?cdcId=calcdc&cdcVersion=3.4&docsetId=calconfig&docsetTarget=n03000sasconfiguration0admin.htm&locale=en#n03007sasconfiguration0admin) in _SAS Viya Administration_.

## (Optional) Create a Local Copy of the Documentation

You can configure your software to give users access to local documentation. Here are two instances where access to local documentation would be useful:

- You have customized your documentation.
- Your SAS system is highly secure, and it does not have access to the internet. Because the SAS documentation is cloud-hosted, it cannot be reached without internet access.

**Note:** The cloud-hosted SAS documentation is frequently updated. The SAS administrator should refresh the local copy on a regular basis to ensure that your users have up-to-date information.

You can download PDF versions of the documentation, or you can create customized versions of the documentation. Create an HTML page with links to all documents that make up your local documentation collection, and create a link to this page.

To configure local documentation:

1. Access SAS Environment Manager.

1. Select **Configuration** from the left navigation bar.

1. Under the **View** menu, select **Definitions**.

1. Select the sas.htmlcommons definition.

1. Click **New Configuration**.

1. On the New sas.htmlcommons Configuration pane, click **Add Property** to add the following two properties:
    - **additionalHelpMenuUrl** — Specify the path to the HTML page that contains links to your local documentation.
    - **additionalHelpMenuLabel** — Provide a meaningful label for the link that your users can access.
      If you do not provide this parameter, a default label of **Additional Help** is used.

1. Click **Save** on the New htmlcommons Configuration pane.

Users will see a new item in the **Help Menu** list, between the **Help Center** and **About** entries. Clicking this link opens the specified HTML page.