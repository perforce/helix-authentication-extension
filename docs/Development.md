# Development

This document is intended for developers who are interested in learning how
to modify and test the Helix Authentication Extension.

## Automated Testing

Automated tests for this extension are written using JavaScript testing tools
(Chai and Mocha). To prepare and run the tests, you will need to install
[Node.js](https://nodejs.org/) *LTS* and run these commands in the directory
containing the `package.json` file:

```shell
npm install
npm test
```

## Docker

A container with a standalone instance of Helix Core is defined for use with
[Docker](https://www.docker.com) and [Docker
Compose](https://docs.docker.com/compose/). To build and start the container,
use `docker-compose` like so:

```shell
docker-compose build p4d.doc
docker-compose up -d p4d.doc
```

This will set up an instance of Helix Core with several test users, as well as
install the extension with a sensible configuration for testing with a test
installation of the authentication service, as described in the next section.

### Container Name Resolution

The docker containers have names that are used internally to find each other. In
order for the container host to resolve these names, it may be helpful to
install [dnsmasq](http://www.thekelleys.org.uk/dnsmasq/doc.html). The easiest
way to run dnsmasq is via Docker. If using a macOS system, the commands below
will get dnsmasq and the host configured appropriately:

```shell
$ echo "address=/.doc/127.0.0.1" | sudo tee - /etc/dnsmasq.conf
$ sudo mkdir /etc/resolver
$ echo 'nameserver 127.0.0.1' | sudo tee /etc/resolver/doc
$ docker run --name dnsmasq -d -p 53:53/udp -p 5380:8080 \
    -v /etc/dnsmasq.conf:/etc/dnsmasq.conf \
    --log-opt 'max-size=1m'  -e 'HTTP_USER=admin' -e 'HTTP_PASS=admin' \
    --restart always jpillora/dnsmasq
```

### Authentication Service

The containers for the authentication service and test identity providers
(Shibboleth for SAML and IdentityServer for OIDC) are in a separate
[repository](https://github.com/perforce/helix-authentication-service) and can
be installed using `docker-compose` as described in the documentation for that
project.

### Commit and Edge Testing

In addition to a standalone container running a single instance of Helix Core,
there are two containers that define a commit/edge server pair. They are
configured in a similar fashion to the standalone instance, with the addition of
one being a commit server and the other being an edge server. To bring these
containers up and get them connected, use the following commands:

```shell
docker-compose up --build -d chicago.doc
docker-compose up --build -d tokyo.doc
docker-compose exec chicago.doc /setup/login.sh
```

The last `exec` command is to perform the commit service user login to the edge
server instance, which cannot be done until both containers have been started
(hence it cannot be done during the build).

### Swarm Testing

A container that installs the latest release of Swarm, configured to connect to
the Helix Server in the `p4d.doc` container, is defined with the name
`swarm.doc`, and can be built and started like so:

```shell
docker-compose up --build -d swarm.doc
```

This Swarm instance is pre-configured to use the authentication service instance
reachable at `https://auth-svc.doc:3000/`, running in a container defined in the
Helix Authentication Service code base.

## Controlling URL open

Setting `P4USEBROWSER` to `false` prevents the browser from opening when you
invoke `p4 login`.

## Configure Script on macOS

The configuration script (`bin/configure-login-hook.sh`) uses the GNU getopt
utility to read the command line arguments. However, macOS does not ship with
GNU getopt installed. To run the script on macOS, first install GNU getopt via
[Homebrew](https://brew.sh) `gnu-getopt` package, and then run the script with
the path to the GNU getopt directory:

```shell
$ PATH="/usr/local/opt/gnu-getopt/bin:$PATH" ./bin/configure-login-hook.sh
```
