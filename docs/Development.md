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

## Installing the Extension

Alongside this README file there exists a JavaScript file named `hook.js` that
is able to package and install the extension. However, it has several
dependencies and can only be configured using environment variables. It is
intended primarily for **developers** testing against a **non-production** Helix
Server. This script is unsupported.

## Controlling URL open

Setting `P4USEBROWSER` to `false` prevents the browser from opening when you
invoke `p4 login`.
