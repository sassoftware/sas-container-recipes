## Ulimits on Kubernetes
If your Kubernetes provider permits, Ulimits can be set on the nodes
by adding or modifying the following in `/etc/security/limits.conf`:

```
  *               -       nofile          500000
  *               -       nproc           131072
```

The `NOFILES` limit can be increased for the Kublet service by appending a
LimitNOFILE line below the '[Service]' section header in `/etc/systemd/system/kubelet.service`.

```
[Service]

  LimitNOFILE=500000

  User=root
```


## CAS_DISK_CACHE Location Customization
The CAS disk cache location can be customized by specifying the following settings
in the manifests_usermods.yml file.

```
sas-casserver-primary:
    deployment_overrides:
      environment:
        - "CAS_DISK_CACHE ='/path/to/cas_disk_cache'"

sas-casserver-worker:
    deployment_overrides:
      environment:
        - "CAS_DISK_CACHE ='/path/to/cas_disk_cache'"
```


## Resource Customization
Memory resources can be specified by adding requests and limits settings to the
manifests_usermods.yml file. Here is an example:

```
custom_services:
  sas-casserver-primary:
    deployment_overrides:
      resources: |
        requests:
          memory: 50048Mi
        limits:
          memory: 75048Mi

  sas-casserver-worker:
    deployment_overrides:
      resources: |
        requests:
          memory: 40048Mi
          cpu: 25
        limits:
          memory: 60048Mi
          cpu: 30
```