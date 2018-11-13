# What does it do

* Download and install the orchestrationCLI
* Use the orchestrationCLI to generate a playbook
* Copy information from the playbook to this project
* Fills in the container.yml based on what is in your order
* Create a Python virtual environment and acivate it
* Install ansible-container into that virtual environment
* Run ansible-container to build the Docker images defined in container.yml
* Once all images are built, run ansible-container to push the Docker images to the Docker registry with a custom tag
* Once the images are pushed, generate Kubernetes manifests tied to those images

# Pre-reqs

* Python 2.7
* Pip
* virtualenv
* Configure Docker so that it is setup to communicate with the preferred Docker registry

# How to run

```
export SAS_VIYA_DEPLOYMENT_DATA_ZIP=/path/to/SAS_Viya_deployment_data.zip
export DOCKER_REGISTRY_URL=http://docker.sas.com
export DOCKER_REGISTRY_NAMESPACE=$(echo $USER)
./new_setup_ac.sh
```

# Post run

After _new_setup_ac.sh_ has run, there are Kubernetes manifests in a directory
named _manifests_. From here you can run _kubectl_ against the manifest file in
the configmaps, secrets and deploy directories.