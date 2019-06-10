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
   ./build.sh --docker-namespace <my-gcp-project-name> --docker-registry-url gcr.io
   ```

### Amazon Elastic Container Registry (ECR)

1. Make sure that you have the AWS CLI installed on your host machine. For more information, see https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html.

2. Create the ECR repositories for each image that will be built. For more information, see https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html.

3. If you do not have an dentity and Access Management IAM user, create one. For more information, see https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html.

4. Run the following command: 

   ```
   aws configure
   ```

5. Add the access token to the ~/.docker/config.json file:

	```
    aws ecr get-login
    ```

6. Copy the `docker login` command that was returned, paste it into a terminal, and run the command.

7. Run the `build.sh` command with the `--docker-namespace` and `--docker-registry-url` arguments. Provide a dummy value for `--docker-namespace` and the repository URI as the value for `--docker-registry-url`.

   Here is an example:

   ```
   ./build.sh --docker-namespace dummy-value --docker-registry-url 1234567890123.dkr.ecr.us-east-1.amazonaws.com/my-repo-name
   ```   

   **Note:**

   - The value for the `--docker-namespace` argument will be ignored, but you must specify a dummy value.
   - For information about the repository URI, see https://console.aws.amazon.com/ecr/repositories.
    
    If the following error occurs, then you need to create a repository for each image that will be built.

	> The repository with the name 'sas-viya-httpproxy' does not exist in the registry with the id '12345678910'
	
	Create the repository named sas-viya-httpproxy at https://console.aws.amazon.com/ecr/repositories.


### Azure Container Registry (ACR)

1. Make sure that you have the Azure CLI installed on your host machine. For more information, see https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest.

2. Create the resource group and container registry space. For more information, see https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-azure-cli.

3. Add the auth and identity token to the ~/.docker/config.json file:

	```
    az acr login --name <registry-name>
    ```
	
   **Note:** The registry name comes from the `--name` argument that was used when the resource group and container registry space were created. For example, `az acr create --resource-group myResourceGroup --name myContainerRegistry --sku Basic`

4. Run the `build.sh` command with the `--docker-namespace` and `--docker-registry-url` arguments. Provide the registy name as the value for `--docker-namespace` and the login server name as the value for `--docker-registry-url`.  

   Here is an example:

   ```
   ./build.sh --docker-namespace registry-name --docker-registry-url login-server-name.azurecr.io
   ```
