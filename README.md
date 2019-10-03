# Helix Authentication Extension

This Helix Server extension facilitates Single-Sign-On (SSO) authentication,
directing end users to the Helix Authentication Service to authenticate using an
identity provider that supports either the OpenID Connect or SAML 2.0
authentication protocols.

## Overview

The Helix Authentication Extension is installed on the Helix Server, and hooks
into the authentication "triggers" in the server. Whenever a user attempts to
authenticate with the server, they will be directed to the Helix Authentication
Service via their default web browser, which in turn redirects the user to the
configured identity provider (IdP). Once the user has successfully authenticated
with the IdP, a ticket will be issued by the Helix Server, at which point the
user can interact with Helix Server.

## Requirements

The extension requires a Helix Server version that supports extensions. This is
2019.1 or later for Linux systems. Windows support for extensions is still
pending. When tested with a pre-release version of the server on Windows, the
extension worked as expected.

### Perforce Clients

The authentication extension has been tested with the following clients:

* P4 2019.1
    + Earlier versions will also work, but the user will have to copy the URL
      displayed in the console and paste it into the browser location bar.
* P4V 2019.2
* P4VS 2019.2 Update 2
* P4EXP 2019.2

## Documentation

See the product documentation in the [docs](./docs) directory. The documentation
includes instructions for packaging and installing the extension.

## Known Issues

Users authenticating with the Helix Server will likely need to use one of the
supported clients to authenticate. Once a valid P4 ticket has been acquired,
then clients other than those listed above should function normally. In
particular, the clients need to handle the `invokeURL` feature added in the
2019.1 P4API. This includes the P4API-derived clients (P4Python, P4Ruby, etc)
which at this time do not yet support this feature.

### P4Eclipse

When using P4Eclipse, you must authenticate using one of the clients listed
above under the **Requirements** section. Then, when setting up the initial P4
connection in P4Eclipse, you are prompted for a user and password. Only put in
the username and leave the password field blank. The client will then use the
existing connection.

### P4SL

When using P4SL, you must authenticate using one of the clients listed above
under the **Requirements** section. Then, when setting up the initial P4
connection in P4SL, you are prompted for a user and password. Only put in the
username and leave the password field blank. The client will then use the
existing connection.

### IntelliJ

When logging in to Perforce using IntelliJ, it will prompt for a password but
also open the browser to the identity provider. Once you have authenticated with
the IdP and acquired a P4 ticket, IntelliJ will still be waiting for a password.
Submit that login request and let it fail, after which IntelliJ will operate
normally.

## How to Get Help

Configuring the extension, the authentication service, and the identity provider
is a non-trivial task. Some expertise in a security systems is helpful. In the
event that you need assistance with configuring these systems, please contact
[Perforce Support](https://www.perforce.com/support/request-support).

## Development

### Installing the Extension

Alongside this README file there exists a JavaScript file named `hook.js` that
is able to package and install the extension. However, it has several
dependencies and is configured using environment variables. It is intended
primarily for developers testing against a non-production Helix Server. See the
comments at the top of that file for additional information.

### Controlling URL open

By setting `P4USEBROWSER` to `false` you can prevent the browser from opening
when you invoke `p4 login`. Not all that useful, but good to know.
