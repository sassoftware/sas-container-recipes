## Contents

- [Remove with Docker](#remove-with-docker)
- [Remove with Kubernetes](#remove-with-kubernetes)
- [(Optional) Clean Up the Docker Registry](#optional-clean-up-the-docker-registry)
- [(Optional) Clean Up Docker Images on the Build Machine](#optional-clean-up-docker-images-on-the-build-machine)

## Remove with Docker

1. Stop the container.

    `docker stop container-name`

2. Determine if the container is still listed.

    ```
    docker ps -a \
    --filter name=container-name --format "table {{.ID}}\t{{.Names}}\t{{.Image}}" | \
    grep container-name
    ```

    Here is an example of the output:

    ```
    0180fa635ac2 container-name
    container-name:3.4.9-201
    80827.1535411348184
    ```
    If the output is empty, skip to step 4.

3. Remove the container.

    `docker rm container-name`

4. (Optional) If the image is no longer needed, then remove it.

    `docker rmi image-name`

## Remove with Kubernetes

1. Verify that the images are still running.

    `kubectl -n sasviya get pods | grep sas`

    The output is a list of pods and their status.

2. Remove the service and pod.

    Delete the viya-programming/viya-single-container objects

    ```
    kubectl -n sasviya delete -f run/programming.yml
    ```

    Delete the viya-programming/viya-multi-container objects

    ```
    kubectl -n sasviya delete -f viya-programming/viya-multi-container/working/manifests/kubernetes/deployments-mpp/
    kubectl -n sasviya delete -f viya-programming/viya-multi-container/working/manifests/kubernetes/secrets/
    kubectl -n sasviya delete -f viya-programming/viya-multi-container/working/manifests/kubernetes/configmaps/
    ```

    Delete the viya-visuals objects

    ```
    kubectl -n sasviya delete -f viya-visuals/working/manifests/kubernetes/deployments-mpp/
    kubectl -n sasviya delete -f viya-visuals/working/manifests/kubernetes/secrets/
    kubectl -n sasviya delete -f viya-visuals/working/manifests/kubernetes/configmaps/
    ```

    As the service and pod are removed, messages that indicate success are displayed. Here is an example:

    ```
    service "container-name" deleted
    statefulset "container-name" deleted
    ```

3. (Optional) Verify that the service and pod are removed.

    `kubectl -n sasviya get pods | grep sas`
    
    `kubectl -n sasviya get svc | grep sas`

    No results indicate a successful removal of the service and pod.

## (Optional) Clean Up the Docker Registry

If you do not plan to use the images, follow the processes implemented by your company or organization to clean up the Docker registry.

## (Optional) Clean Up Docker Images on the Build Machine

- To remove all unused data, see [docker system prune](https://docs.docker.com/engine/reference/commandline/system_prune/).
- To remove images, see [docker image rm](https://docs.docker.com/engine/reference/commandline/image_rm/).