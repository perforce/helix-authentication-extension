# LDAP

## Overview

Helix Server has long supported LDAP for user authentication, and that does not
change when used in concert with the authentication extension. The server can
support users that authenticate with a database password (default Perforce
authentication), or an LDAP-based password (as defined with `p4 ldap`), or via
SSO authentication by means of the `auth-check-sso` trigger. In fact, a user can
be authenticated by both an `auth-check-sso` trigger _and_ LDAP.

However, the authentication extension differs from an `auth-check-sso` trigger
in that it uses the "invoke URL" feature to open a web browser to delegate user
authentication to an external web site (i.e. identity provider). As a result,
the Perforce client and server never receive the user's credentials, and thus
the server cannot pass the credentials to an LDAP directory. In this scenario, a
user can either authenticate with the authentication extension, or they can
authenticate by some other means (i.e. LDAP), but not both.

The remainder of this guide offers one of several possible combinations of
authentication methods, allowing some users to authenticate with database
passwords, some to authenticate using an LDAP directory, and yet another set of
users that authenticate using browser-based SSO.

## Perforce Configuration

Permitting a combination of authentication mechanisms is a matter of setting the
Perforce configuration appropriately, and defining which users are authenticated
by which method.

Start by defining an LDAP configuration in Perforce using the `p4 ldap` command
as described in this knowledge base
[guide](https://community.perforce.com/s/article/2590).

Once a basic LDAP configuration is in place, define several settings that will
allow a combination of authentication paths, as shown below:

```shell
$ p4 configure set auth.default.method=ldap
$ p4 configure set auth.ldap.order.1=<name-of-your-ldap-config>
$ p4 configure set auth.sso.allow.passwd=1
$ p4 configure set auth.sso.nonldap=1
```

The above commands set LDAP as the default authentication mechanism, but allow
for non-LDAP users (those whose `AuthMethod` is set to `perforce`), and
additionally instructs the SSO mechanism to allow "password" authenticated users
(those users that are authenticated by the server without delegation to LDAP or
SSO). This is just an example, and by no means the only possible configuration.

Once the configuration is in place, those users that will be using LDAP
authentication must have their `AuthMethod` set to `ldap`. For any user whose
`AuthMethod` is set to `ldap` the authentication extension will defer their
authentication to the server, which will use LDAP, if given the configuration
shown above.

Users that will authenticate with a database password should be named in either
the `non-sso-users` extension configuration, or belong to a group named in
`non-sso-groups`, and have their `AuthMethod` set to `perforce`. This setting,
in combination with `auth.sso.allow.passwd=1`, instructs the server to use the
database password for non-SSO and non-LDAP users.
