# Development

## Docker

A container with a standalone instance of Helix Core is defined for use with
[Docker](https://www.docker.com) and [Docker
Compose](https://docs.docker.com/compose/). To build and start the container,
use `docker-compose` like so:

```shell
$ docker-compose build p4d.doc
$ docker-compose up -d p4d.doc
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
one being a commit server and the other being an edge server. To bring this
containers up and get them connected, use the following commands:

```shell
docker-compose build chicago.doc
docker-compose build tokyo.doc
docker-compose up -d chicago.doc
docker-compose up -d tokyo.doc
docker-compose exec chicago.doc /setup/login.sh
```

The last `exec` command is to perform the commit service user login to the edge
server instance, which cannot be done until both containers have been started
(hence it cannot be done during the build).

## Installing the Extension

Alongside this README file there exists a JavaScript file named `hook.js` that
is able to package and install the extension. However, it has several
dependencies and is configured using environment variables. It is intended
primarily for developers testing against a non-production Helix Server. See the
comments at the top of that file for additional information.

## Controlling URL open

Setting `P4USEBROWSER` to `false` prevents the browser from opening when you
invoke `p4 login`.
