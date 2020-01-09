# Development

## Docker

A container is defined for use with [Docker](https://www.docker.com) and [Docker
Compose](https://docs.docker.com/compose/). To build and start the container,
use `docker-compose` like so:

```shell
$ docker-compose build
$ docker-compose up -d
```

### Authentication Service

The containers for the authentication service for integrating the extension with
an identity provider are in a separate
[repository](https://github.com/perforce/helix-authentication-service) and can
be installed using `docker-compose` as described in the documentation for that
project.

## Installing the Extension

Alongside this README file there exists a JavaScript file named `hook.js` that
is able to package and install the extension. However, it has several
dependencies and is configured using environment variables. It is intended
primarily for developers testing against a non-production Helix Server. See the
comments at the top of that file for additional information.

## Controlling URL open

Setting `P4USEBROWSER` to `false` prevents the browser from opening when you
invoke `p4 login`.
