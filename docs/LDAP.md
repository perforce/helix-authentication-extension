# LDAP

## Overview

Helix Server has long supported LDAP for user authentication, and that does not
change when used in concert with the authentication extension. The server can
support users that authenticate with either a database password (default
Perforce authentication), an LDAP-based password (as defined with `p4 ldap`), as
well as SSO authentication by means of the `auth-check-sso` trigger (which the
authentication extension implements).

## Docker Demo

See the
[Development.md](https://github.com/perforce/helix-authentication-service/blob/master/docs/Development.md)
file of the authentication
[service](https://github.com/perforce/helix-authentication-service) project for
details on setting up and starting the docker containers which demonstrate the
authentication service with LDAP authentication along side SSO authentication
via the Shibboleth IdP.

## Perforce Configuration

Permitting a combination of authentication mechanisms is only a matter of
setting the Perforce configuration appropriately. First, define an LDAP
configuration in Perforce using the `p4 ldap` command as described in the
knowledge base [guide](https://community.perforce.com/s/article/2590). Next,
define several settings that will allow a combination of authentication paths,
as shown below:

```shell
$ p4 configure set auth.default.method=ldap
$ p4 configure set auth.ldap.order.1=simple
$ p4 configure set auth.sso.allow.passwd=1
$ p4 configure set auth.sso.nonldap=1
```

The above commands set LDAP as the default authentication mechanism, but allow
for non-LDAP users (those whose `AuthMethod` is set to `perforce`), and
additionally the SSO mechanism is set to allow "password" authenticated users
(those users that are authenticated by the server without delegation to LDAP or
SSO). This is just an example, and by no means the only possible configuration.
