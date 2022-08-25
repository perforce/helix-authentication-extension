# Helix Authentication Extension

This Helix Server extension facilitates Single-Sign-On (SSO) authentication,
directing end users to the Helix Authentication Service to authenticate using an
identity provider that supports either the OpenID Connect or SAML 2.0
authentication protocols.

## Versions

Official releases will have version numbers of the form `YYYY.N`, such as
`2019.1`, `2020.1`, or `2020.2`. These releases have undergone testing and are
available on *releases* page in the GitHub project.

Patch releases will have version numbers with three dot separated numbers, such
as `2020.1.1` or `2019.1.2`.

The unofficial "snapshot" releases will have `-snapshot` after the version
number: `YYYY.N-snapshot` after a major release, and `YYYY.N.N-snapshot` after a
patch release. These may include changes that are not yet reflected in the
documentation, and these versions are limited to Community Support.

## Overview

The Helix Authentication Extension is installed on the Helix Server, and hooks
into the authentication facility of the server. Whenever a user attempts to
authenticate with the server, they will be directed to the Helix Authentication
Service via their default web browser, which in turn redirects the user to the
configured identity provider (IdP). Once the user has successfully authenticated
with the IdP, a ticket will be issued by the Helix Server, at which point the
user can interact with Helix Server.

## Requirements

The extension requires a Helix Server version that supports extensions. This is
**2019.1** or later for **Linux** systems, and **2021.2** or later for
**Windows** systems.

### Helix Authentication Service

The extension integrates with the Helix Authentication Service
(available on [GitHub](https://github.com/perforce/helix-authentication-service))
in order to direct the user to the identity provider during the login process.
As such, the authentication service must be running and accessible to the
Helix Core Server running the extension.

### Perforce Clients

The authentication extension has been tested with the following clients. The
extension will work with the versions shown, as well as later versions.

* P4 2019.1, the Helix Core command-line client
    + Earlier versions will also work, but the user will have to copy the URL
      displayed in the console and paste it into the browser location bar.
* P4V 2019.2, the Helix Core Visual Client
* P4VS 2019.2, patch 2, the Helix Plugin for Visual Studio
* P4EXP 2019.2, the Helix Plugin for File Explorer
* Helix DAM, 2022.1
* Helix Plugin for Eclipse (P4Eclipse) 2019.1 patch 2
* Helix Plugin for Matlab (P4SL) 2019.1
* Helix Swarm 2018.3, the free code review tool
* Helix TeamHub, 2022.1

## Documentation

See the administrative guide in the [docs](./docs) directory for instructions on
installing and configuring the extension. Additionally, guidance on configuring
LDAP authentication, along with SSO, is given in the [LDAP](./docs/LDAP.md)
guide.

## How to Get Help

Configuring the extension, the authentication service, and the identity provider
is a non-trivial task. Some expertise in a security systems is helpful. In the
event that you need assistance with configuring these systems, please contact
[Perforce Support](https://www.perforce.com/support/request-support).

## Development

See the [development](./docs/Development.md) page for additional information
regarding building and testing the service.
