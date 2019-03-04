# THIS CONTENT HAS BEEN MIGRATED
# Please use the project's GitHub wiki: https://github.com/sassoftware/sas-container-recipes/wiki

---

### How do I push Docker images to my AWS repository?

If building multiple containers, ansible-container does not support pushing to a AWS based registry. One will need to do a `docker tag` and `docker push` for each image built. To get the list of images run the following from the root of the project:

```
docker images --filter "label=sas.recipe.version=$(cat VERSION)" | grep latest
```

For each image that meets that criteria run the `docker tag` and `docker push` commands. Make sure the tag is the same for each image pushed. If the tag is not the same, then one will need to edit the Kubernetes manifests to apply the correct tag.

### How do I deploy to my Kubernetes cluster?

Running the root level build.sh will generate a set of Kubernetes manifests. One can do this by hand as well. Navigate to the `viya-programming/viya-multi-container/working/` directory. From there one can run:

__Note:__ The call _deactivates_ the virtual environment if you have one.

```
deactivate; ansible-playbook generate_manifests.yml -e 'docker_tag=<your value>'
```

This will create content in _${PWD}/manifests/kubernetes_. 

To use these manifests,you will need to install and configure  _[kubectl](#how-do-i-install-kubectl)_. The Kubernetes configuration file will need to come from your Kuberenetes administrator.

Once _kubectl_ is configured, run the following to deploy into the Kubernetes environment.

```
kubectl create -f manifests/kubernetes/configmaps/
kubectl create -f manifests/kubernetes/secrets/
kubectl create -f manifests/kubernetes/deployments-smp/
or
kubectl create -f manifests/kubernetes/deployments-mpp/
```

### How do I change the information associated with the users created by the auth-demo add on?

In the 18m11 release, the `auth-demo` add on was modified so that it creates two users. There is the _DEMO_USER_ and the _CASENV_ADMIN_USER_. To change the values of the _DEMO_USER_, add the following to the _programming_ and _sas-casserver-primary_ manifest (values shown are the defaults): 

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
To change the _CASENV_ADMIN_USER_ information, add the following to the _sas-casserver-primary_ manifest (values shown are the defaults): 
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
If these changes are made post pod deployment, then run `kubectl replace -f path/to/manifest` on the appropriate manifest to update the pod. Then run `kubectl delete pod <pod>` and when the new pod is deployed the new values will be applied.

### How do I build Jupyter Notebook in a multiple container setup?

There are two Docker files to as part of the _ide-jupyter-python3_ add on. These are needed in order to support configuring the distinct images of _httpproxy_ and _programming_ that are built. The _httpproxy_ image supports the redirect to the Jupyter Notebook URL and _programming_ is where the Jupyter Notebook server is running. When using the root level `build.sh`, if you pass in `addons/ide-jupyter-python3` as one of the add on components, the build process will do everything for you. However, if you want to add on the layers yourself because you want to set the token or maybe disable the terminal or native kernel, follow these steps.

To add to the _httpproxy_ image, run the following. This is assuming that you have already changed to the `addons/ide-jupyter-python3` directory.

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

To add Jupyter to the _programming_ image, run:

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

If you follow the above then you should be able to use ansible-container to tag and push the images to the Docker registry. The following assumes you have changed to the _viya-programming/viya-multi-container_ directory:

```
# Source the virtualenv
source env/bin/activate
ansible-container --push --push-to docker-registry --tag $(cat ${PWD}/../../VERSION)-$(date "+%Y%m%d%H%M%S")-$(git rev-parse --short HEAD)
# Exit out of the virtualenv
deactivate
```

If you Docker tag and push the images without using ansible-container, double check the manifests to make sure they have the correct image.

### How do I configure tokens for Jupyter Notebook?

By default the Docker build process sets the Jupyter token to empty. In order to set the token to create greater security, you add the following to the _env_ section in the _programming_ manifest:

```
        - name: JUPYTER_TOKEN
          value: "Unique Value Here"
```

If this is being set post deployment or maybe changed after the pod is deployed, then you need to run `kubectl replace -f path/to/programming` to update the pod. Then run `kubectl delete pod sas-viya-programming-0` and when the new pod is deployed the token value will be applied.

### How do I set the RUN_USER for Jupyter Notebook?

By default the RUN_USER is set to the CASENV_ADMIN_USER. You can change the user name of RUN_USER by setting a different environment variable. To use a user name from LDAP, the user's home directory must contain an `authinfo.txt` file and an `.authinfo` file to help with authentication to the CAS server.