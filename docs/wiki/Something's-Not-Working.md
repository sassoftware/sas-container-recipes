### Docker fails to push the newly built images to my registry, what are some common causes?

You must first authenticate with your Docker registry using `docker login <my-registry>.mydomain.com`. This will prompt you for a username and password (with LDAP, if configured) and a file at ~/.docker/config.json is created to store that credential.

For information about registries, see [Docker Registry](https://docs.docker.com/registry/).

If a Docker error is related to a timeout issue, then you might have to set a longer timeout, such as `export DOCKER_CLIENT_TIMEOUT=700`. The Docker error might also be an issue with ansible-container, which require a change in the conductor template: `echo 'ENV DOCKER_CLIENT_TIMEOUT=600' >> ansible-container/container/docker/templates/conductor-local-dockerfile.j2`


### When building Docker images, I see a HTTP Error Code 410

A message such as `HTTPS Error 410 - Gone` or `[Errno 256] No more mirrors to try.`

means you have exceeded the maximum download count on your SAS order. [Contact SAS Technical Support](https://support.sas.com/en/technical-support/contact-sas.html)

for futher assistance, then [create a local mirror repository](https://go.documentation.sas.com/?docsetId=dplyml0phy0lax&docsetTarget=p1ilrw734naazfn119i2rqik91r0.htm&docsetVersion=3.4)

to avoid exceeding the maximum download count again.


### When building the Docker image, I see an error about not connecting to the Docker daemon. What should I do?

If the following error occurs 'ERRO[0000] failed to dial gRPC: cannot connect to the Docker daemon', for Linux hosts, make sure that the Docker daemon is running:

```
sudo systemctl status docker
● docker.service - Docker Application Container Engine
   Loaded: loaded (/usr/lib/systemd/system/docker.service; disabled; vendor preset: disabled)
   Active: active (running) since Wed 2018-08-08 06:57:53 EDT; 1 months 12 days ago
     Docs: https://docs.docker.com
 Main PID: 24833 (dockerd)
    Tasks: 104
```

If the process is running, then you might need to run the Docker commands using sudo. For information on running the Docker commands without using sudo, see the [Docker documentation](https://docs.docker.com/v17.12/install/linux/linux-postinstall/).

### What should I do about a warning that displays when building the Docker image?

The following warning can be ignored: 'warning: /var/cache/yum/x86_64/7/**/*.rpm: Header V3 RSA/SHA256 Signature, key ID \<key\>: NOKEY'

This warning indicates that the Gnu Privacy Guard (gpg) key is not available on the host, and it is followed by a call to retrieve the missing key.

### Running the docker build command displays an error about no such file or directory. Why?

The following can occur: 'COPY failed: stat /var/lib/docker/tmp/docker-builderXXXXXXXXXX/\<file name\>: no such file or directory'

The reason is that the `docker build` command expects a Dockerfile and a build "context," which is a set of files in a specified path or URL. If the files are not present, the Docker build will display the error message. To resolve it, make sure that the files are in the directory where the Docker build takes place.

**Notes:**

- For this project, the build context is where the files are copied from. In the examples, `.` represents the build context.
- In some recipes, the user is expected to copy the files into the current directory before running the `docker build` command. For example, copying files is required for building the viya-single-container image and some of the addon images.

### Docker fails to push the newly built images to my registry, what are some common causes?

You must first authenticate with your docker registry using `docker login <my-registry>.mydomain.com`. This will prompt you for a username and password (with LDAP if configured) and a file at ~/.docker/config.json is created to store that credential.

### Why is the Ansible playbook failing?

This error might indicate that Docker is running out of space on the host where the Docker daemon is running. To find out if more space is needed, look in the Ansible output for a message similar to the following example:

```
        "Error Summary",
        "-------------",
        "Disk Requirements:",
        "  At least 6344MB more space needed on the / filesystem."
```

If more space is needed, try pruning the Docker system:

```
docker system prune --force --volumes
```

If the error persists after the pruning, check to see if the Device Mapper storage driver is used:

```
docker system info 2>/dev/null | grep "Storage Driver"
```

If the output is _Storage Driver: devicemapper_, then the Device Mapper storage driver is used. The Device Mapper storage driver has a default layer size of 10 GB, and the SAS Viya
image is typically larger. Possible workarounds to free up space are to change the layer size or to switch to
the [overlay2 storage driver](https://docs.docker.com/storage/storagedriver/overlayfs-driver/).

### Why are there "none" Docker images in my Docker image list?
One or more images with "none" in the name and tag, called "dangling images", may be created as a result of a Docker image build failure.

Running `docker images` may show a list similar to the following:
```
REPOSITORY   TAG                 IMAGE ID            CREATED             SIZE
<none>       <none>              ac16e336a5ca        20 hours ago        842MB
<none>       <none>              c2ece66e6108        20 hours ago        842MB
<none>       <none>              b6c3548e6234        20 hours ago        842MB
```

The command `docker image prune --force` may be run to remove all dangling images.
