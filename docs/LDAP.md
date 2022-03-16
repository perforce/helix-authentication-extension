# LDAP

## Overview

Helix Core Server has long supported LDAP for user authentication, and that does not change when used in concert with the authentication extension. The server can support users that authenticate with a database password (default `perforce` authentication) or an LDAP-based password (as defined with `p4 ldap`), or via SSO authentication by means of the `auth-check-sso` trigger. In fact, a user can be authenticated by both a classic `auth-check-sso` trigger _and_ LDAP.

However, the authentication extension differs from an `auth-check-sso` trigger in that it uses the _invoke URL_ feature to open a web browser to delegate user authentication to an external web site (the identity provider). As a result, the Perforce client and server never receive the user's credentials, and thus the server cannot pass the credentials to an LDAP directory. In this scenario, a user can either authenticate with web-based SSO, or they can authenticate by some other means, but not both.

The remainder of this guide offers one of several possible combinations of authentication methods, allowing some users to authenticate with database passwords, some to authenticate using an LDAP directory, and yet another set of users that authenticate using browser-based SSO.

## Migrating LDAP users to SSO

Switching users from LDAP authentication to web-based SSO authentication will require changing the `AuthMethod` for each user that will be authenticating with web-based SSO. When the `AuthMethod` field has the value `ldap` then that user will authenticate using LDAP. To change the authentication method for a user to SSO, simply change the `AuthMethod` value to `perforce`. At this point, it is the extension configuration that will determine if a user authenticates with SSO or some other method, such as a database password.

Changing a user's `AuthMethod` can be achieved from the command line, like so:

```shell
p4 --field AuthMethod=perforce user -o <username> | p4 user -f -i
```

Note that when the `security` server configurable is set to `3` or higher, every user whose `AuthMethod` is `perforce` will be required to have a database password. This is true regardless of how the user with authenticate with the server. An easy way to set the password to a long random string (on Unix) might look like this:

```shell
yes $(uuidgen) | p4 passwd <username>
```

## Helix Core Server Configuration

Permitting a combination of authentication mechanisms is a matter of setting the server configuration appropriately, and defining which users are authenticated by which method. Start by defining an LDAP configuration in Helix Core Server using the `p4 ldap` command as described in this knowledge base [guide](https://community.perforce.com/s/article/2590). Once a basic LDAP configuration is in place, set the server configurable(s) to allow a combination of authentication paths, as described in the following sections.

### LDAP users always authenticate with LDAP

With the authentication extension in place, LDAP users will always be prompted for their credentials by the Perforce client, and Helix Core Server will then authenticate the user against the LDAP directory. The authentication extension will **not** process LDAP user authentication for the reason stated above.

### Use SSO for non-LDAP users

With the authentication extension, configuring the server to use SSO for non-LDAP users requires setting the `auth.sso.nonldap` configurable to `1`. From the command-line you can configure the server using the [p4 configure](https://www.perforce.com/manuals/cmdref/Content/CmdRef/p4_configure.html) command:


```shell
p4 configure set auth.sso.nonldap=1
```

## References

* [Helix Core Server Administrator Guide](https://www.perforce.com/manuals/p4sag/Content/P4SAG/scripting.triggers.external_auth.sso.html)
* [Helix Core Command-Line (P4) Reference](https://www.perforce.com/manuals/cmdref/Content/CmdRef/configurables.configurables.html)
