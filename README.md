# Helix Authentication Extension

This Helix Server extension facilitates Single-Sign-On (SSO) authentication,
directing end users to the Helix Authentication Service to authenticate using an
identity provider that supports the either the OpenID Connect or SAML 2.0
authentication protocols.

## Overview

The Helix Authentication Extension is installed on the Helix Server, and hooks
into the authentication "triggers" in the server. Whenever a user initiates an
authentication with the server, they will be directed to the Helix
Authentication Service using their default web browser, which in turns redirects
the user to the configured identity provider (IdP). Once the user has
successfully authenticated with the IdP, a ticket will be issued by the Helix
Server, at which point the user can interact with Helix Server.

## Requirements

The extension requires a Helix Server version that supports extensions. This is
2019.1 or later for Linux systems. Windows support is still pending.

## Documentation

See the corresponding product documentation for details.

## Development

### Installing the Extension

To install the authentication integration extension, use `node` like so:

```shell
$ node hook.js
```

### Using SAML

For SAML, the extension must be installed slightly differently:

```shell
$ PROTOCOL=saml node hook.js
```

You will almost certainly have to change the `name-identifier` setting to
`nameID` as well, since typical SAML identity providers do not include an
`email` property. To configure the extension run the command below:

```shell
$ p4 extension --configure Auth::loginhook --name loginhook-all
```

### Tips and Tricks

#### Controlling URL open

By setting `P4USEBROWSER` to `false` you can prevent the browser from opening
when you invoke `p4 login`. Not all that useful, but good to know.
