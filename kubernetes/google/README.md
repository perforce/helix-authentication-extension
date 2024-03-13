# Kubernetes

This directory contains example manifests for deploying Helix Core Server and the `loginhook` extension within a Google-managed [Kubernetes](https://kubernetes.io) cluster using the [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine). This document describes the overall setup and provides additional tips and information. Familiarity with the `kubectl` command is assumed.

**Note:** This document and these manifests are intended for development and testing purposes. Running Helix Core Server in a container in production is strongly discouraged and **not supported** by Perforce. If you were to try, the first problem you would encounter is that the IP address will change whenever the pod is restarted, rendering an IP-based license invalid. Putting that aside, it may not even be worthwhile to use k8s since `p4d` does not scale horizontally, rendering the very thing k8s is known for completely useless. Lastly, the performance overhead of cluster-based storage will likely be untenable -- popular storage drivers often introduce a 40% overhead, with OpenEBS+Mayastor being a notable exception.

**Note:** A complication with running Helix Core Server in the cloud is that the client address will appear as one of several load balancers rather than the actual client. As a result, host-based tickets will be ineffective, forcing users to perform a `p4 login -a` to get a ticket that works on any host.

## Initial Setup

### Create the Cluster

1. Visit https://console.cloud.google.com/ in a browser
1. Create a new project or use an existing one.
1. Navigate to **Kubernetes Engine** and create a new cluster. There are no special requirements, the default selections will work fine.

### Client Setup

1. Install the Google Cloud CLI https://cloud.google.com/cli to your desktop or laptop.
    * If using [Homebrew](https://brew.sh), you can run `brew install google-cloud-sdk`
1. Update the installed components: `gcloud components update`
1. Install the `kubectl` command-line tool:
    * Using gcloud: `gcloud components install kubectl`
    * Using Homebrew: `brew install kubernetes-cli`
1. Install the GKE plugin for `kubectl` and authenticate with your cluster:

```shell
gcloud components install gke-gcloud-auth-plugin
gcloud auth login
gcloud config set project <name-of-project>
gcloud container clusters get-credentials <your-cluster> --region=<your-region>
```

### Artifact Registry

In order to produce container images and push them to a private registry, you will need to create an *image registry* and use that address when pulling private container images into your cluster. Google Cloud offers this as the **Artifact Registry** service, which charges for disk and network usage. See these [instructions](https://cloud.google.com/artifact-registry/docs/docker/store-docker-container-images) for details on the setup and usage.

### Build the p4d image

Kubernetes will pull container images from [Docker Hub](https://hub.docker.com) by default, unless the image includes the address of a registry. These manifests assume that to be the case, using `us-central1-docker.pkg.dev/p4-has-test-58982/my-docker-repo` as the address of a private artifact registry. The steps below will produce the image for Helix Core Server and push it to that artifact registry.

**Note:** You will need to create your own registry and modify the commands below to match.

```shell
docker build -f containers/basic-p4d/Dockerfile -t helix-p4d-basic .
docker image rm us-central1-docker.pkg.dev/p4-has-test-58982/my-docker-repo/helix-p4d-basic
docker image tag helix-p4d-basic us-central1-docker.pkg.dev/p4-has-test-58982/my-docker-repo/helix-p4d-basic
docker push us-central1-docker.pkg.dev/p4-has-test-58982/my-docker-repo/helix-p4d-basic
```

## Deploy

The manifests defined here are merely examples, feel free to adjust as appropriate. The `kubectl patch` command is necessary in order to configure the `ingress-nginx` controller to handle TCP requests on port `1666` by sending them to the `helix-p4d` service.

**Note:** You will need to edit the `deployments/helix-p4d.yaml` file to use the correct registry address for the `helix-p4d-basic` image before proceeding.

For now, deploy everything one step at a time.

```shell
kubectl apply -f namespaces/helix.yaml
kubectl apply -f pvcs/p4-data.yaml
kubectl apply -f secrets/loginhook-tls.yaml
kubectl apply -f services/helix-p4d.yaml
kubectl apply -f deployments/helix-p4d.yaml
```

At this point, Helix Core Server should be running and listening on port `1666`, accessible from the IP address assigned by the load balancer. To find that IP address, use `kubectl -n helix get svc`:

```shell
$ kubectl -n helix get svc
NAME        TYPE           CLUSTER-IP       EXTERNAL-IP      PORT(S)          AGE
helix-p4d   LoadBalancer   34.118.226.238   34.135.206.102   1666:31590/TCP   17h
```

The output shows that the IP address is `34.135.206.102` and the service is exposed on port `1666` as expected. Connecting to the server using `p4` is shown below:

```shell
$ p4 -u super -p 34.135.206.102:1666 info
User name: super
Client name: joesample-client
Client host: joesample-host
Client unknown.
Current directory: /home/joesample
Peer address: 99.82.198.92:51201
Client address: 99.82.198.92
Server address: helix-p4d-7ff5f67ff6-bxtr8:1666
Server root: /p4/main/root
Server date: 2024/03/14 17:11:00 +0000 UTC
Server uptime: 18:08:11
Server version: P4D/LINUX26X86_64/2023.2/2563409 (2024/02/27)
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
		auth-svc.pcloud:443:34.67.11.220
	Service-URL:
		https://auth-svc.pcloud
```

In short, the extension will connect to the service using its FQDN in `Service-URL`, but resolve that name by the value for `Resolve-Host` because our DNS resolution is not working in the p4d pod, for whatever reason. Of course the DNS resolution can be solved in several ways, this configuration simply provides an alternative.

Note that the client certificates are provided via the **secret** configured earlier.

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
{"data":{"getData":"info: fetching https://auth-svc.pcloud/requests/new/nfiedler%40perforce.com"},"nanos":104927,"pid":217,"recType":0,"seconds":1696367414}
...
```

### Updating the extension

Use the `bin/redeploy.sh` script to rebuild, remove, install, and configure the extension. Note that this script is not tested or supported by Perforce, it may result in data loss.

```shell
env P4USER=super P4PORT=34.135.206.102:1666 ./bin/redeploy.sh
```
