# Kubernetes

This directory contains example manifests for deploying Helix Core Server and the `loginhook` extension within a local [Kubernetes](https://kubernetes.io) cluster. This document describes the overall setup and provides additional tips and information. Familiarity with the `kubectl` command is assumed.

**Note:** This document and these manifests are intended for development and testing purposes. Running Helix Core Server in a container in production is strongly discouraged and **not supported** by Perforce. If you were to try, the first problem you would encounter is that the IP address will change whenever the pod is restarted, rendering an IP-based license invalid. Putting that aside, it may not even be worthwhile to use k8s since `p4d` by itself does not scale horizontally, rendering the very thing k8s is known for completely useless. Lastly, the performance overhead of cluster-based storage will likely be untenable -- popular storage drivers often introduce a 40% overhead, with OpenEBS+Mayastor being a notable exception.

## Initial Setup

### Create the Cluster

The instructions here assume you are comfortable with provisioning system software and constructing a local cluster from scratch. The procedure for doing this is not documented here as that is well outside of the scope of this document. As a point of reference, the manifests contained herein were developed and tested on a single-node cluster created using `kubeadm`, with [containerd](https://containerd.io) as the container runtime, [Flannel](https://github.com/flannel-io/flannel) as the network layer, [Longhorn](https://longhorn.io/) for storage, and [MetalLB](https://metallb.universe.tf) serving as the load balancer. Domain name resolution was set up using [dnsmasq](https://thekelleys.org.uk/dnsmasq/doc.html) to resolve the `*.cluster` names to the MetalLB load balancer.

### Load Balancer

On a local network, the best option at this time is to use MetalLB which runs within Kubernetes and serves the same basic purpose by advertising Layer 2 name resolution to the network. See also https://kubernetes.github.io/ingress-nginx/deploy/baremetal/ for more information when using this with the nginx ingress controller, which these manifests are utilizing.

Note that when configuring MetalLB, it helps to use a set of IP addresses that are within the subnet of your LAN. That is, if your local router subnet is `192.168.1.0/24` then MetalLB should be configured to use addresses within `192.168.1.x` that will not conflict with existing hosts, as well as whatever range the router uses for dynamic address assignment (DHCP).

### Build the p4d image

Kubernetes will pull container images from [Docker Hub](https://hub.docker.com) by default, unless the image includes the address of a registry. These manifests assume that to be the case, using `192.168.1.1:5000` as the address of a local image registry. The steps below will produce the image for Helix Core Server and push it to that local registry.

```shell
docker build -f containers/basic-p4d/Dockerfile -t helix-p4d-basic .
docker image rm 192.168.1.1:5000/helix-p4d-basic
docker image tag helix-p4d-basic 192.168.1.1:5000/helix-p4d-basic
docker push 192.168.1.1:5000/helix-p4d-basic
```

## Deploy

The manifests defined here are merely examples, feel free to adjust as appropriate. The `kubectl patch` command is necessary in order to configure the `ingress-nginx` controller to handle TCP requests on port `1666` by sending them to the `helix-p4d` service.

**Note:** You will need to edit the `deployments/helix-p4d.yaml` file to use the correct registry address for the `helix-p4d-basic` image before proceeding.

For now, deploy everything one step at a time.

```shell
kubectl apply -f namespaces/helix.yaml
kubectl apply -f configmaps/tcp-services.yaml
kubectl patch deployment -n ingress-nginx ingress-nginx-controller --patch "$(cat patches/ingress-nginx-controller.yaml)"
kubectl create -f storageclasses/p4-data.yaml
kubectl apply -f pvcs/p4-data.yaml
kubectl apply -f secrets/loginhook-tls.yaml
kubectl apply -f services/helix-p4d.yaml
kubectl apply -f deployments/helix-p4d.yaml
```

At this point, Helix Core Server should be running and listening on port `1666`, accessible from the IP address assigned by the load balancer. To find that IP address, use `kubectl -n helix get svc`:

```shell
$ kubectl -n helix get svc
NAME        TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)          AGE
helix-p4d   LoadBalancer   10.100.195.16    192.168.1.22   1666:32151/TCP   47m
```

The output shows that the IP address is `192.168.1.22` and the service is exposed on port `1666` as expected. Connecting to the server using `p4` is shown below:

```shell
$ p4 -u super -p 192.168.1.22:1666 info
User name: super
Client name: joesample-client
Client host: joesample-host
Client unknown.
Current directory: /home/joesample
Peer address: 10.244.0.1:55080
Client address: 10.244.0.1
Server address: helix-p4d-cd8964bb6-qf465:1666
Server root: /p4/main/root
Server date: 2023/10/02 23:00:22 +0000 UTC
Server uptime: 00:30:27
Server version: P4D/LINUX26X86_64/2023.1/2468153 (2023/07/24)
ServerID: main
Server services: commit-server
Server license: none
Case Handling: sensitive
```

**Note:** If using the `basic-p4d` image as demonstrated above, the default password for the `super` user will be `Passw0rd!`.

### Configuring the extension

The global configuration of the extension should look something like this, with default values elided for brevity.

```
	Client-Cert:
		/opt/perforce/certs/tls.crt
	Client-Key:
		/opt/perforce/certs/tls.key
	Resolve-Host:
		auth-svc.cluster:443:192.168.1.21
	Service-URL:
		https://auth-svc.cluster
```

In short, the extension will connect to the service using its FQDN in `Service-URL`, but resolve that name by the value for `Resolve-Host` because our DNS resolution is not working in the p4d pod, for whatever reason. The client certificates are provided via the **secret** configured earlier.

The instance configuration for the extension will look something like this; as above, the default settings are elided for brevity:

```
	enable-logging:
		true
	name-identifier:
		nameID
	non-sso-groups:
		no_timeout
	user-identifier:
		email
```

This assumes the group `no_timeout` exists, as created by the `helix-p4d-basic` container when it starts up. This group contains the `super` user and has a nearly unlimited ticket expiration.

### Testing the extension

Once the pods are running and the extension is configured, you can create users in Helix Core Server and test the login. To examine the extension logs, you can do something like this:

```shell
$ kubectl -n helix get pod
NAME                         READY   STATUS    RESTARTS   AGE
auth-svc-5d695698d6-r8vsx    1/1     Running   0          6d
auth-svc-5d695698d6-vjkxb    1/1     Running   0          6d
helix-p4d-7bd98cf98b-xgvbl   1/1     Running   0          4h30m
redis-5b999654fc-sx4jc       1/1     Running   0          6d

$ kubectl -n helix exec -it pod/helix-p4d-7bd98cf98b-xgvbl -- /bin/bash
root@helix-p4d-7bd98cf98b-xgvbl:/setup# cd /p4/main/root/server.extensions.dir/117E9283-732B-45A6-9993-AE64C354F1C5/1-data/
root@helix-p4d-7bd98cf98b-xgvbl:/p4/main/root/server.extensions.dir/117E9283-732B-45A6-9993-AE64C354F1C5/1-data# tail log.json
{"data":{"getData":"info: fetching https://auth-svc.cluster/requests/new/nfiedler%40perforce.com"},"nanos":104927,"pid":217,"recType":0,"seconds":1696367414}
...
```

### Updating the extension

Use the `bin/redeploy.sh` script to rebuild, remove, install, and configure the extension. Note that this script is not tested or supported by Perforce, it may result in data loss.

```shell
env P4USER=super P4PORT=192.168.1.22:1666 ./bin/redeploy.sh
```
