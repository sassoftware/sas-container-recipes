### Google Kubernetes Engine (GKE)
1. Make sure that the Google Cloud SDK is installed on your host machine.
	For more information, see https://cloud.google.com/sdk/docs/.

2. Create a Kubernetes cluster in GKE
	A cluster must have a minimum of approximately 32 vCPUS and 128GB RAM total for a full VA deployment.
	The minimum requirement may be higher depending on your software order.
	This command creates 3 nodes, each with 16 vCPUs and 60GB RAM:

	```
	gcloud container clusters create sas-viya-cluster \
		--num-nodes 3 --machine-type n1-standard-16 --zone us-central1-a
	```

	Note: You can use any `--zone` argument. If you provide a `--region` argument
	then the gcloud tool will multiply your `--num-nodes` argument by the number
	of zones in that region. For example, if the argument
	`--num-nodes 3 --region us-central1` is provided then 9 total nodes will be
	created, 3 in each of the 3 zones available in the us-central1 region.
	This may lead to over-allocation of resources and an increase in your
	Google Kubernetes Engine bill.

	If you do not reserve adequate machine specs then you will see the message
	"Does not have minimum availability" message in the GKE Workloads page.

3. Add the cluster's config to your Kubernetes config file
	`gcloud container clusters get-credentials sas-viya-cluster --zone us-central1-a`

	Use the same `--zone` argument as the previous step.

4. Add the credential helpers (credHelpers) section to the ~/.docker/config.json file:
	`gcloud auth configure-docker`

5. Add the access token to the ~/.docker/config.json file:
	`docker login https://gcr.io` (Note: you must add "https://" to the URL)

6. Run the `build.sh` command with the `--docker-namespace` and `--docker-registry-url` arguments.
	Provide your Google Cloud Platform (GCP) project name as the value for
	`--docker-namespace` and gcr.io as the value for `--docker-registry-url`.

   Here is an example:

   ```
   ./build.sh --docker-namespace <my-gcp-project-name> --docker-registry-url gcr.io
	```

7. Apply the Kubernetes manifest using the output from the build result script

### Amazon Elastic Container Service for Kubernetes (EKS)
1. Install the AWS CLI so ECR registries can be created
	https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

1. Make sure that you have the AWS CLI installed on your host machine.
	For more information, see https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html.

2. Make sure that you have the EKS CLI installed on your host machine so a Kubernetes cluster can be created.
	For more information, see https://docs.aws.amazon.com/eks/latest/userguide/eksctl.html#installing-eksctl

3. Create ECR registries for each image that is going to be built
	https://docs.aws.amazon.com/AmazonECR/latest/userguide/repository-create.html

4. If you do not have an Identity and Access Management (IAM) user, create one.
	For more information, see https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html.

5. Run the following command:

   ```
   aws configure
   ```

6. Add the access token to the ~/.docker/config.json file:

	```
    aws ecr get-login
    ```

7. Copy the `docker login` command that was returned, paste it into a terminal, and run the command.

8. Get a Security Token Service

	Run the command `aws sts get-caller-identity`

	Example response (**do not copy**):
	```
	{
		"UserId": "OJOAY7OMEKNKP33U2DTJI:my.name@domain.com",
		"Account": "00000000000",
		"Arn": "arn:aws:sts::00000000000:assumed-role/sandbox/my.name@domain.com"
	}
	```

9. Import your SSH key into EC2 if you have not already
	For more information, see https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#KeyPairs:sort=keyName

10. Ceate a Kubernetes cluster in EKS
	A cluster must have a minimum of approximately 32 vCPUS and 128GB RAM total for a full VA deployment.
	The minimum requirement may be higher depending on your software order.
	This command creates 4 nodes, each with 8 vCPUs and 32GB RAM:

	```
	eksctl create cluster --ssh-public-key <my_ec2_key> --name sas-viya --node-type m5.2xlarge --nodes 4
	```

	Where `<my_ec2_key>` is the name of the key imported in the previous step.

11. Add the cluster's config to your Kubernetes config file

	```
	aws eks update-kubeconfig --name sas-viya
	```

12. Run the `build.sh` command with the `--docker-namespace` and `--docker-registry-url` arguments. Provide a dummy value for `--docker-namespace` and the repository URI as the value for `--docker-registry-url`.

   Here is an example:

   ```
   ./build.sh --docker-namespace dummy-value --docker-registry-url 1234567890123.dkr.ecr.us-east-1.amazonaws.com
   ```

   **Note:**

   - The value for the `--docker-namespace` argument will be ignored, but you must specify a dummy value.
   - For information about the repository URI, see https://console.aws.amazon.com/ecr/repositories.

    If the following error occurs, then you need to create a repository for each image that will be built.

	> The repository with the name 'sas-viya-httpproxy' does not exist in the registry with the id '12345678910'

13. Apply the Kubernetes manifest using the output from the build result script


### Azure Kubernetes Service (AKS)
1. Make sure that you have the Azure CLI installed on your host machine. For more information, see https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest.

2. Create the resource group and container registry space. For more information, see https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-azure-cli.

3. Add the auth and identity token to the ~/.docker/config.json file:

	```
    az acr login --name <registry-name>
    ```
	The registry name can be found on the "Resource Groups" page.

4. Run the `build.sh` command with the `--docker-namespace` and `--docker-registry-url` arguments. Provide the registy name as the value for `--docker-namespace` and the login server name as the value for `--docker-registry-url`.

   Here is an example:

   ```
   ./build.sh --docker-namespace registry-name --docker-registry-url login-server-name.azurecr.io
   ```
