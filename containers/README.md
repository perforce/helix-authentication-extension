# Extension Docker Containers

This document describes a setup for testing the login extension using [Docker](https://www.docker.com), which is relatively easy to use, but comes with the cavaet that you will need to work through some complicated setup for container name resolution. Be sure to read through this entire document before attempting to use these containers.

## Overview

This directory contains definitions for several Docker containers for testing the extension.

* **p4d:** standalone instance of Helix Core Server.
* **swarm:** Swarm configured to connect to **p4d** using SSO.
* **chicago:** commit instance of Helix Core Server, connected to **tokyo**.
* **tokyo:** edge instance of Helix Core Server, connected to **chicago**.

The `docker-compose.yml` file in the parent directory configures those containers.

* `p4d.doc`: Helix Core Server listening on port `1666`
* `chicago.doc`: commit server listening on port `2666`
* `tokyo.doc`: edge server listening on port `3666`
* `swarm.doc`: Swarm listening on port `8080`

See the next section for the setup, and in particular the container name resolution.

## Setup

1. [Install](https://docs.docker.com/engine/install/) Docker
1. [Install](https://docs.docker.com/compose/install/) Docker Compose

Supported platforms include Linux, macOS, and Windows. Supported Linux distributions include CentOS, Debian, Fedora, and Ubuntu.

### Container Name Resolution

The Docker containers have names that are used internally to find each other, and since one of the containers (Swarm) is serving requests from the web browser, the names must be resolvable by the system doing the testing. In order for the test system to resolve these names, it may be helpful to install [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html). The easiest way to run dnsmasq is via Docker.

```shell
$ echo 'address=/.doc/127.0.0.1' | sudo tee /etc/dnsmasq.conf
$ docker run --name dnsmasq -d -p 53:53/udp -p 5380:8080 \
    -v /etc/dnsmasq.conf:/etc/dnsmasq.conf \
    --log-opt 'max-size=1m'  -e 'HTTP_USER=admin' -e 'HTTP_PASS=admin' \
    --restart always jpillora/dnsmasq
```

If using a macOS system, the commands below will configure the host to use dnsmasq for host name resolution:

```shell
$ sudo mkdir /etc/resolver
$ echo 'nameserver 127.0.0.1' | sudo tee /etc/resolver/doc
```

If using a systemd-based Linux desktop, this [page](https://sixfeetup.com/blog/local-development-with-wildcard-dns-on-linux) describes the steps for running dnsmasq and `systemd-resolved` together. Note that this only works for the desktop system itself, if you want other hosts to be able to use this system for DNS, you will need to disable the stub listener for `systemd-resolved` and rely directly on dnsmasq.

An alternative to using dnsmasq would be to hard-code the names in the `/etc/hosts` file, or configure a DNS server to resolve the names.

## Usage

Build and start the containers (from the parent directory) like so:

```shell
$ docker compose build chicago.doc
$ docker compose up --build -d
$ docker compose exec chicago.doc /setup/login.sh
```

The last `exec` command is to perform the commit service user login to the edge server instance, which cannot be done until both containers have been started, hence it cannot be done during the build.

To test authentication, you will need to build and start the Docker containers defined in the https://github.com/perforce/helix-authentication-service project. These containers directly or indirectly defer to the Helix Authentication Service at some point in the process.

The **p4d** Helix Core Server instance has been configured with the full suite of test accounts defined in the authentication service containers. By default, the SAML/Shibboleth accounts will be in effect. To change this, configure the extension to specify `oidc` as the protocol in the `Auth-Protocol` global setting.

The **chicago** and **tokyo** instances have only the `jackson` and `johndoe` accounts defined, simply for brevity. You are free to define any accounts you like, as long as the OIDC or SAML identity providers know about them.
