### How do I push Docker images to my AWS repository?

If you are building multiple containers, ansible-container does not support pushing to an AWS-based registry. Therefore, `docker tag` and `docker push` commands are required for each image built.

To get the list of images run the following command from the root of the project:

```
docker images --filter "label=sas.recipe.version=$(cat VERSION)" | grep latest
```

For each image that meets that criteria, run the `docker tag` and `docker push` commands. Make sure that the tag is the same for each image pushed. If the tag is not the same, then edit the Kubernetes manifests to apply the correct tag.

### How do I change the information associated with the users created by the auth-demo addon?

In the 18m11 release, the auth-demo addon was modified so that it creates two users. There is the DEMO_USER and the CASENV_ADMIN_USER. To change the values of the DEMO_USER, add the following lines to the programming and cas manifests (values shown are the defaults): 

```
        - name: DEMO_USER
          value: "sasdemo"
        - name: DEMO_USER_PASSWD
          value: "sasdemo"
        - name: DEMO_USER_UID
          value: "1004"
        - name: DEMO_USER_HOME
          value: "/home/${DEMO_USER}"
        - name: DEMO_USER_GROUP
          value: "sas"
        - name: DEMO_USER_GID
          value: "1001"
```
To change the CASENV_ADMIN_USER information, add the following to the cas manifest (values shown are the defaults): 
```
        - name: CASENV_ADMIN_USER=
          value: "sasdemo"
        - name: ADMIN_USER_PASSWD
          value: "sasdemo"
        - name: ADMIN_USER_UID
          value: "1003"
        - name: ADMIN_USER_HOME
          value: "/home/${CASENV_ADMIN_USER}"
        - name: ADMIN_USER_GROUP
          value: "sas"
        - name: ADMIN_USER_GID
          value: "1001"
```
If these changes are made post pod deployment, then run `kubectl -n sas-viya replace -f <path/to/manifest>` on the appropriate manifest to update the pod. Next, run `kubectl -n sas-viya delete pod <pod>` and the new values will be applied when the new pod is deployed.

**Notes:** 

- The example commands use *sas-viya* for the namespace. If you created a different namespace, use that value.
- For a SAS Viya programming-only deployment, the manifests are located at `builds/multiple/manifests/`.
- For a SAS Viya full deployment, the manifests are located at `builds/full/manifests/`.

### How do I build Jupyter Notebook in a multiple-container environment?

The ide-jupyter-python3 addon includes two Docker files that support the configuration of the httpproxy and programming images. The httpproxy image supports the redirect to the Jupyter Notebook URL, and the programming image is where the Jupyter Notebook server is running.

When building images by using the ide-jupyter-python3 addon with the `build.sh` command, the build process updates everything for you. However, if you want to add on the layers to set the token or to disable the terminal or native kernel, see the following examples.

To add to the httpproxy image, make sure that you are in the addons/ide-jupyter-python3 directory, and run the following commands:

```
# Preserve the built httpproxy image
docker tag sas-viya-httpproxy sas-viya-httpproxy-base
# Now add Jupyter proxy configuration to the httpproxy image 
docker build \
--file Dockerfile_http \
--build-arg BASEIMAGE=sas-viya-httpproxy-base \
--build-arg BASETAG=latest \
. \
--tag sas-viya-httpproxy
```

To add Jupyter to the programming image, run the following commands:

```
# Preserve the built programming image
docker tag sas-viya-programming sas-viya-programming-base
# Now add Jupyter to the programming image 
docker build \
--file Dockerfile \
--build-arg BASEIMAGE=sas-viya-programming-base \
--build-arg BASETAG=latest \
--build-arg JUPYTER_TOKEN="Replace this value" \
--build-arg ENABLE_TERMINAL=False\
--build-arg ENABLE_NATIVE_KERNEL=False\
. \
--tag sas-viya-programming
```

If you follow the preceding instructions, then you should be able to use ansible-container to tag and push the images to the Docker registry. Make sure that you are in the builds/multiple directory, and run the following commands:

```
# Source the virtualenv
source env/bin/activate
ansible-container --push --push-to docker-registry --tag $(cat ${PWD}/../../VERSION)-$(date "+%Y%m%d%H%M%S")-$(git rev-parse --short HEAD)
# Exit out of the virtualenv
deactivate
```

To tag and push the images without using ansible-container, double check the manifests to make sure that they have the correct image.

### How do I configure tokens for Jupyter Notebook?

By default the Docker build process sets the Jupyter token to empty. To set the token to create greater security, add the following to the env section in the programming manifest:

```
        - name: JUPYTER_TOKEN
          value: "Unique Value Here"
```

If this is being set post deployment or maybe changed after the pod is deployed, then you need to run `kubectl -n sas-viya replace -f <path/to/programming>` to update the pod. Then run `kubectl -n sas-viya delete pod sas-viya-programming-0` and the token value will be applied when the new pod is deployed.

**Notes:** 

- The example commands use *sas-viya* for the namespace. If you created a different namespace, use that value.
- For a SAS Viya programming-only deployment, the default path for `<path/to/programming>` is builds/multiple/manifests/deployments/programming.yml. 
- For a SAS Viya full deployment, the default path for `<path/to/programming>` is builds/full/manifests/deployments/programming.yml.

### How do I set the RUN_USER for Jupyter Notebook?

By default the RUN_USER is set to the CASENV_ADMIN_USER. You can change the user name of RUN_USER by setting a different environment variable. To use a user name from LDAP, the user's home directory must contain an authinfo.txt file and an .authinfo file to help with authentication to the CAS server.