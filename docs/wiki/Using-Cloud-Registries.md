### Google Cloud Container Registry

1. Make sure that the Google Cloud SDK is installed on your host machine. For more information, see https://cloud.google.com/sdk/docs/.
	
2. Add the credential helpers (credHelpers) section to the ~/.docker/config.json file:

   ```
   gcloud auth configure-docker
   ```

3. Add the access token to the ~/.docker/config.json file:

   ```
   docker login https://gcr.io
   ``` 
   
   **Note:** You must use https (not http) in the address for gcr.io.

4. Run the `build.sh` command with the `--docker-namespace` and `--docker-registry-url` arguments. Provide your Google Cloud Platform (GCP) project name as the value for `--docker-namespace` and gcr.io as the value for `--docker-registry-url`.

   Here is an example:

   ```
   ./build.sh --docker-namespace My GCP Project Name --docker-registry-url gcr.io
   ```

### Amazon Elastic Container Registry (ECR)

1. Make sure that you have the AWS CLI installed on your host machine. For more information, see https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html.

2. Create the ECR registries for each image that is going to be built (Amazon calls this a Container Repository). For more information, see https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html.

3. If you do not have an IAM user, create one. For more information, see https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html.
	Then run `aws configure`
4. Add your access token to your ~/.docker/config.json using
	`aws ecr get-login`
	Then copy and paste the `docker login` command that was returned
5. Run the build command with the arguments

    The value specified for the required `--docker-namespace` argument will be ignored, but you must specify a dummy value. Provide the registry URI (found at https://console.aws.amazon.com/ecr/repositories) for the value of the `--docker-registry-url` argument.
    
6. If an error such as the following appears then you need to create a registry for each image that is being built.

	> The repository with the name 'sas-viya-httpproxy' does not exist in the registry with the id '12345678910'
	
	Create the registry named 'sas-viya-httpproxy' at https://console.aws.amazon.com/ecr/repositories


### Azure Container Registry (ACR)
1. Install the Azure CLI
	https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest
2. Create the resource group and container registry space
	https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-azure-cli
3. Add the auth and identity token to your ~/.docker/config.json
	`az acr login --name <registry-name>`
	Note: the registry name comes from the "--name" argument used when your resource group and container registry space was created. For example, `az acr create --resource-group myResourceGroup --name myContainerRegistry --sku Basic`
4. Run the build command with the arguments
	--docker-namespace as your registry name the --docker-registry-url as the login server name ("<name>.azurecr.io")
