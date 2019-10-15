### Inotify Settings
The error `InotifyInit: too many open files` in standard output
indicates that the maximum number of file system event monitors has been
reached. Inotify settings on the Kubernetes nodes need to be adjusted to
accommodate the `sas-viya-watch-log-default` service. These are system wide settings so all
watches in all containers will be limited by these settings.

##### Change the maximum amount of user instances
```
echo fs.inotify.max_user_instances=640 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
```

#### Change the maximum amount of user watches
```
echo fs.inotify.max_user_watches=1048576 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
```


### Docker fails to push the newly built images to my registry, what are some common causes?

You must first authenticate with your Docker registry using `docker login <my-registry>.mydomain.com`. This will prompt you for a username and password (with LDAP, if configured) and a file at ~/.docker/config.json is created to store that credential.

For information about registries, see [Docker Registry](https://docs.docker.com/registry/).

If a Docker error is related to a timeout issue, then you might have to set a longer timeout, such as `export DOCKER_CLIENT_TIMEOUT=700`. The Docker error might also be an issue with ansible-container, which require a change in the conductor template: `echo 'ENV DOCKER_CLIENT_TIMEOUT=600' >> ansible-container/container/docker/templates/conductor-local-dockerfile.j2`

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

### Why do addon installs fail for SuSE-based images? 

During the addon phase for SuSE-based images, an install error such as the following can display:

```
r\nerror]
\n\x1b[91mRepository \'openSUSE BuildService - devel:languages:python\' is invalid.
\n[openSUSE BuildService - devel:languages:python|https://download.opensuse.org/repositories/devel:/languages:/python:/Factory/openSUSE_Leap_42.3/] Valid metadata not found at specified URL
\nPlease check if the URIs defined for this repository are pointing to a valid repository.
\nSome of the repositories have not been refreshed because of an error.
```

This error indicates that the ide-jupyter-python3 Docker file is defining a repository that is no longer needed, which causes issues for any layer that requires installing software after the ide-jupyter-python3 is added to the image.

To solve this, in the addons/ide-jupyter-python3/Dockerfile, change the SuSE block to the following: 

```
    elif [ "$PLATFORM" = "suse" ]; then \
        rpm --rebuilddb; \
        set +e; zypper install --no-confirm python3 python3-devel curl gcc-c++; set -e; \
        rm --verbose --recursive --force /var/cache/zypp; \
        curl --silent --remote-name https://bootstrap.pypa.io/get-pip.py; \
        python3 get-pip.py; \
        rm --verbose --force get-pip.py; \
        zypper clean ; \
    else \

```

Next, re-run the Docker build step using the previous base. This should resolve the issue for later layers.

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