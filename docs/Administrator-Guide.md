# Administrator's Guide for Helix Authentication Extension

## Overview

Helix Authentication Service support for Helix Core server and Helix Core clients, such as P4V, requires a Helix Core Server Extension. This extension, like the the Node.js authentication service, can run on Linux systems with Security-Enhanced Linux (SELinux) enabled and in enforcing mode. If you chose to enable [Security-Enhanced Linux (SELinux)](https://en.wikipedia.org/wiki/Security-Enhanced_Linux), the extension runs in enforcing mode.

For information about Helix Core Server Extensions, see the [Helix Core Extensions Developer Guide](https://www.perforce.com/manuals/extensions/Content/Extensions/Home-extensions.html).

### Prerequisites

* This document assumes that you have read "Administrator's Guide for Helix Authentication Service", which is available on the Perforce web site at https://www.perforce.com/manuals/helix-auth-svc/.
* Helix Core Server, version 2019.1 or later.

### Support

The configuration of the Helix Authentication Service to work with both the Identity Provider (IdP) and the Perforce server product requires an experienced security administrator. This effort might require assistance from Perforce Support.

## Preparing for Installation

Before installing the authentication extension there are a few steps to be taken.

### Upgrade the Clients

It is helpful for the end users to have updated Helix Core clients. The updated clients will direct the user to the web browser during the login progress. Older clients may only print the URL on the screen and not open the browser automatically. See the `README.md` file for the list of supported client versions.

### Testing the Extension

To test the extension with a limited set of users, prior to enabling SSO for all users, you can set the `sso-users` or `sso-groups` configuration settings, as described in the [Testing](#testing) section below. With either of these settings in place, only users that are listed in `sso-users`, or are a member of one of the groups listed in `sso-groups`, will be authenticated using the extension. Once the proper functioning of the extension has been established, you can then clear these settings to enable SSO for all users.

Basic preliminary testing of the extension is also possible using `p4 extension --run` which is described in the [Testing](#testing) section below.

### Excluding some users from SSO

See the section below titled [Allowing for non-SSO Users](#allowing-for-non-sso-users) for details. It is **recommended** to have at least one administrative user named among the non-SSO users. Administrative users should be using a database password to avoid being locked out in the event that the SSO mechanism is not operational (for instance, the identity provider is temporarily inaccessible).

### Migrating from LDAP

If you are planning to change some or all users from authenticating via LDAP to authenticating with web-based SSO, please see the [LDAP guide](./LDAP.md) for more information. Each such user will need to have their `AuthMethod` changed and possibly have a database password created.

## Installing the Extension

The extension can be installed using the provided configuration script, or manually for systems not supported by the script. This section will describe how to use the configuration script, while the [Manual Installation](#manual-installation) section describes the detailed steps for building, installing, and configuring the extension.

In both the assisted and manual installation procedures, the last step will involve restarting the Helix Core server.

### Configuration Script

The configuration script is a Linux-based bash script named `configure-login-hook.sh` in the `bin` directory. Since the script requires a Linux system, it does not support installation from a Windows system. The Helix Core server can be running on a Windows system, but the configure script must be run from a Linux system. The script can be run without prompting for input by providing all of the necessary command-line options, including `-n` to signal the script to run non-interactively. When run without options, the script will prompt for the required information. The script will use the provided information to build, install, and configure the extension. It will also restart the Helix Core server, if given permission to do so.

Invoke the script with the `--help` option to learn the details of the options and usage of the script.

### Manual Installation

#### Building the Extension

If you already have the `loginhook.p4-extension` file, go to the **Install** section.

If you want to build the loginhook extension from the source code, open a terminal window and issue the following command:

```shell
$ p4 extension --package loginhook
```

The result will be a zip file named `loginhook.p4-extension`

#### Installing the Extension

To install the extension, run the following command in a terminal window:

```shell
$ p4 extension --install loginhook.p4-extension -y
Extension 'Auth::loginhook#1.0' installed successfully.
```

If this is not the first time you are installing the extension, remove the existing extension before reinstalling it. See **Removing the Extension**.

## Configuring the Extension

The extension is configured at both the _global_ and _instance_ level. To learn about these levels, see the "Server extension configuration (global and instance specs)" topic in the [Helix Core Extensions Developer Guide](https://www.perforce.com/manuals/extensions/Content/Extensions/extensionspec.html). The extension has settings that are specific to the global and instance configuration, as described below.

Both the global and instance configuration are defined using Perforce forms, in which fields consist of a label, a colon, a tab character, and a value. Fields that allow multiple values will start on a new line, with each value on a separate line, and all lines are prefixed by a tab character. Within the `ExtConfig` section, field labels are prefixed by **one** tab character, and values start on a new line and are prefixed with **two** tab characters.

Specific to this extension, any value that starts with `...` means the value is left undefined, and the default behavior will take effect, if any. When defining a value for a configuration setting, remove the `...` and everything that follows on that line, then enter the desired value.

### Global

Start by setting the global configuration of the extension:

```shell
$ p4 extension --configure Auth::loginhook
[snip]

ExtP4USER:     sampleExtensionsUser

ExtConfig:
    Auth-Protocol:
        ... Authentication protocol, saml or oidc.
    Authority-Cert:
        ... Path to certificate authority public key, defaults to ./ca.crt
    Client-Cert:
        ... Path to client public key, defaults to ./client.crt
    Client-Key:
        ... Path to client private key, defaults to ./client.key
    Service-URL:
        ... The authentication service base URL.
    Verify-Peer:
        ... Ensure service certificate is valid, if 'true'.
    Verify-Host:
        ... Ensure service host name matches certificate, if 'true'.
```

where `[snip]` means some information has been omitted.

The first field to change is `ExtP4USER` which should be the Perforce user that will own this extension, typically a "super" or administrative user.

Of the settings in `ExtConfig`, only the `Service-URL` setting is required. The other settings have default values as described below.

#### Global Settings

| Name | Description | Default |
| ---- | ----------- | ------- |
| `Auth-Protocol` | Can be any value supported by the authentication service. This determines the authentication protocol for SSO users to authenticate. This setting is optional because the authentication service will use its own settings to determine the protocol. | Defaults to whatever the authentication service decides. |
| `Authority-Cert` | Path to the public key of the certificate authority. See the [Certificates](#certificates) section for more information. | Defaults to the `ca.crt` file in the extension directory. |
| `Client-Cert` | Path to the public key of the extension client certificate. See the [Certificates](#certificates) section for more information. | Defaults to the `client.crt` file in the extension directory. |
| `Client-Key` | Path to the private key of the extension client certificate. See the [Certificates](#certificates) section for more information. | Defaults to the `client.key` file in the extension directory. |
| `Service-URL` | The address of the authentication service by which the Helix Server can make a connection | _none_ |
| `Verify-Peer` | If set to `true` then the extension will verify that the authentication service is using a valid SSL/TLS certficate. | _false_ |
| `Verify-Host` | If set to `true` then the extension will verify that the hostname of the authentication service matches the SSL/TLS certificate returned by the service. | _false_ |

#### Example

In this following example, each level of indentation represents a single tab character. The labels are prefixed with **one** tab character and the values are all prefixed with **two** tab characters.

```
[snip]

ExtP4USER:     super

ExtConfig:
    Auth-Protocol:
        saml
    Authority-Cert:
        /etc/ssl/trusted-ca.crt
    Client-Cert:
        /p4/1/ssl/loginhook-client.crt
    Client-Key:
        /p4/1/ssl/loginhook-client.key
    Service-URL:
        https://auth-svc.example.com:3000/
    Verify-Peer:
        ... Ensure service certificate is valid, if 'true'.
    Verify-Host:
        ... Ensure service host name matches certificate, if 'true'.
```

### Instance

To configure a single _instance_ of the extension, include the `--name` option along with the `--configure` option. This example uses `loginhook-a1` just as an example; you are free to use a more descriptive name.

```shell
p4 extension --configure Auth::loginhook --name loginhook-a1 -o
[snip]
ExtConfig:
    client-name-identifier:
        ... Field within JSON web token containing unique user identifer.
    client-sso-groups:
        ... Those groups whose members must authenticate using P4LOGINSSO.
    client-sso-users:
        ... Those users who must authenticate using P4LOGINSSO.
    client-user-identifier:
        ... Trigger variable used as unique P4LOGINSSO user identifier.
    enable-logging:
        ... Extension will write debug messages to a log if 'true'.
    name-identifier:
        ... Field within IdP response containing unique user identifer.
    non-sso-groups:
        ... Those groups whose members will not be using SSO.
    non-sso-users:
        ... Those users who will not be using SSO.
    sso-groups:
        ... Those groups whose members must authenticate using SSO.
    sso-users:
        ... Those users who must authenticate using SSO.
    user-identifier:
        ... Trigger variable used as unique user identifier.
```

where `[snip]` means some information has been omitted.

All of these settings have sensible defaults. However, for the extension to be enabled, we must configure it. You might want to change either the `non-sso-groups` or `non-sso-users` fields to a list of Perforce groups and users that are _not_ participating in the SSO authentication integration.

#### Instance Settings

| Name | Description | Default |
| ---- | ----------- | ------- |
| `client-name-identifier` | Field within JSON web token containing unique user identifer. | _none_ |
| `client-sso-groups` | Those groups whose members must authenticate using P4LOGINSSO. | _none_ |
| `client-sso-users` | Those users who must authenticate using P4LOGINSSO. | _none_ |
| `client-user-identifier` | Trigger variable used as unique P4LOGINSSO user identifier. | _none_ |
| `enable-logging` | Extension will write debug messages to a log if `true` | `false` |
| `non-sso-groups` | Those groups who will not be using SSO. _This is a multi-value field, with each value starting on a new line and prefixed by two tab characters._ | _none_ |
| `non-sso-users` | Those users who will not be using SSO. _This is a multi-value field, with each value starting on a new line and prefixed by two tab characters._ | _none_ |
| `sso-groups` | Those groups whose members must authenticate using SSO. If this field is set to the name one or more groups, then the `non-sso-groups` field will be ignored. See the [Testing](#testing) section below. _This is a multi-value field, with each value starting on a new line and prefixed by two tab characters._ | _none_ |
| `sso-users` | Those users who must authenticate using SSO. If this field is set to the name one or more users, then the `non-sso-users` field will be ignored. See the [Testing](#testing) section below. _This is a multi-value field, with each value starting on a new line and prefixed by two tab characters._ | _none_ |
| `user-identifier` | Trigger variable used as unique user identifier, one of: `fullname`, `email`, or `user`. | `email` |
| `name-identifier` | Field within identity provider user profile containing unique user identifer. | `email` |

#### Example

In this following example, each level of indentation represents a single tab character. The labels are prefixed with **one** tab character and the values are all prefixed with **two** tab characters.

```
[snip]
ExtConfig:
    enable-logging:
        true
    name-identifier:
        nameID
    non-sso-groups:
        admins
        supers
    non-sso-users:
        bruno
        susan
    sso-groups:
        ... (none)
    sso-users:
        ... (none)
    user-identifier:
        email
```

#### Multiple Instance Configurations

The extension is not designed to support multiple instance configurations. To find out what configurations have been defined, use the `p4 extension --list` command like so:

```shell
$ p4 extension --list --type configs
... config foobar
... extension Auth::loginhook
... uuid 117E9283-732B-45A6-9993-AE64C354F1C5
... revision 1
... owner super
... type auth-check-sso
... arg auth

... config foobar
... extension Auth::loginhook
... uuid 117E9283-732B-45A6-9993-AE64C354F1C5
... revision 1
... owner super
... type auth-pre-sso
... arg auth

... config loginhook
... extension Auth::loginhook
... uuid 117E9283-732B-45A6-9993-AE64C354F1C5
... revision 1
... owner super
... type global-extcfg

... config loginhook-all
... extension Auth::loginhook
... uuid 117E9283-732B-45A6-9993-AE64C354F1C5
... revision 1
... owner super
... type auth-check-sso
... arg auth

... config loginhook-all
... extension Auth::loginhook
... uuid 117E9283-732B-45A6-9993-AE64C354F1C5
... revision 1
... owner super
... type auth-pre-sso
... arg auth
```

From the example output above, we see two instance configurations, one of which is named `foobar`. To remove this extraneous configuration, use the `p4 extension --delete` command, as shown in the example below:

```
$ p4 extension --delete Auth::loginhook --name foobar
Would delete Extension 'Auth::loginhook#1, foobar'.
This was report mode. Use -y to perform the operation.

$ p4 extension --delete Auth::loginhook --name foobar -y
Extension 'Auth::loginhook#1, foobar' successfully deleted.
```

That command will remove the named instance configuration, leaving the other configurations and the extension itself.

### Applying the Changes

After installing and configuring the authentication extension, the Helix Core server must be restarted for the changes to take effect. The `restart` is necessary because Helix Core prepares the authentication mechanisms during startup. This is true when adding or removing `auth-` related triggers, as well as when installing or removing the loginhook extension.

It is **recommended** to have at least one administrative user configured in the `non-sso-users` extension setting, or a group of users in the `non-sso-groups` setting; this provides a means of authenticating in the event that the service becomes unavailable for any reason. Typically the _super_ and/or _admin_ users, along with service or operator users, would be named in one of these two settings.

When you are ready to restart the server, you can use the following command:

```shell
$ p4 admin restart
```

## Next Steps

### Testing

Preliminary testing of the extension, after installation but before restarting Helix Core Server, is possible with the use of the `p4 extension --run` command. The extension supports several commands:

* `test-svc`: Tests the connection to the authentication service.
* `test-cmd`: Tests the invocation of Perforce commands on the server.
* `test-all`: Runs all available tests.

Examples of running these tests are shown here:

```shell
$ p4 extension --run loginhook-a1 test-svc
Service response: OK

$ p4 extension --run loginhook-a1 test-cmd
Command successful

$ p4 extension --run loginhook-a1 test-all
Service response: OK
Command successful
```

For the purpose of testing the authentication integration with a limited number of users, you may change the `sso-users` field to a list of Perforce users that _must_ authenticate using the SSO authentication integration. When this value is configured with one or more users, then the `non-sso-users` and `non-sso-groups` lists will be ignored by the extension. Likewise, any users _not_ included in this list will _not_ authenticate using the extension. To clear the `sso-users` field, replace the list of users with `...` to indicate that the field is to be ignored. When the `sso-users` field starts with `...` then the `non-sso-users` and `non-sso-groups` fields will be considered by the extension during user authentication.

Similar to the `sso-users` field is the `sso-groups` field, in which names of Perforce groups are given. Any users that are members of any of the named groups will be required to authenticate using the SSO authentication integration. When this value is configured with one or more groups, then the `non-sso-groups` and `non-sso-users` lists will be ignored by the extension. Likewise, any users that are _not_ members of any of the groups will _not_ authenticate using the extension. To clear the `sso-groups` field, replace the list of groups with `...` to indicate that the field is to be ignored. When the `sso-groups` field starts with `...` then the `non-sso-groups` and `non-sso-users` fields will be considered by the extension during user authentication.

### Debug logging

When enabled, the extension writes debugging logs to a JSON formatted file that will appear in the directory identified by the `data-dir` extension attribute. You can find the value for `data-dir` by searching the installed extensions using p4 extension as a privileged user.

```shell
$ p4 extension --list --type=extensions
... extension Auth::loginhook
... [snip]
... data-dir server.extensions.dir/117E9283-732B-45A6-9993-AE64C354F1C5/1-data
```

where `[snip]` means some information has been omitted.

### Mapping User Profiles to Perforce Users

Helix user specs have several fields that can be used for matching with the profile information returned from the identity provider. The extension uses the trigger variables exposed by the server, namely `fullname`, `user`, and `email`, and the choice is configured in the extension by setting the `user-identifier` value (default is `email`) in the *instance* configuration.

On the other side of the mapping is the user profile returned by the identity provider. Different protocols and providers return different fields, and there is no one field that works for all. Also, administrators are often free to adjust the output to suit their needs. As such, the extension has another *instance* configuration setting named `name-identifier`, which specifies the name of the field in the user profile that is to be used in matching with the Helix user. This defaults to `email` because that field is likely to be available and unique on both the IdP and Helix.

Generally, with **SAML**, the `name-identifier` extension setting should be given the value `nameID` because that field is always present in the user profile returned from the SAML IdP. Depending on the format of the name identifier, you will need to select an appropriate value for the `user-identifier`. If the IdP returns a "user name", and it matches the `User` field in the Perforce user spec, set `user-identifier` to `user` in the extension *instance* configuration. If the name identifier is an email address, use `email` instead of `user`. The value of `fullname` might also be appropriate, depending on the IdP configuration.

For **OIDC**, the user profile often includes an `email` field. The server extension looks for this by default because `name-identifier` defaults to `email`. Hopefully this value matches the `Email` field of the Perforce user spec because the server extension uses email for the `user-identifier` by default.

If you are unsure of the contents of the user profile returned from the identity provider, enable the debug logging in either the authentication service or the server extension, and then examine the logs after attempting a login. With the server extension, set the `enable-logging` *instance* configuration setting to `true`, attempt a login, and look for the `log.json` file under the `server.extensions.dir` directory of the Helix depot. For the authentication service, set the `DEBUG` environment variable to `auth:*`, restart the service, attempt the login, and look at the output from the service (either in the console or in a pm2 log file, if you are using pm2).

### Allowing for non-SSO Users

Configuring the extension to allow for non-SSO users is not required, however, it is recommended to have at least the administrative user named, either individually, or as part of a group of admin users. If either the Helix Authentication Service or the identity provider were to be unavailable, admin users would still be able to authenticate with Helix Core using another method, such as a database password or LDAP authentication.

The process for enabling non-SSO users consists of three steps:

1. Enable database passwords in addition to supporting SSO
1. Set passwords for all users
1. Assign users to the non-SSO group

#### Enable Database Passwords

To allow for database passwords, and to allow for the super user to set the passwords of users, configure the server using the [p4 configure](https://www.perforce.com/manuals/cmdref/Content/CmdRef/p4_configure.html) command:

```shell
$ p4 configure set auth.sso.allow.passwd=1
```

#### Set User Passwords

When the server is running at security level 3, all users must have a password, including SSO users, even though they do not need to know their password. We recommend setting this password to a random value:

```shell
$ yes $(uuidgen) | p4 -u super passwd username
```

#### Assign non-SSO Users

In the server extension, indicate which users and/or groups are excluded from SSO authentication. See the `non-sso-groups` and `non-sso-users` settings described above.

### Certificates

Included with the authentication extension are sample self-signed certificates. For production systems, these files should be replaced with _client_ certificates signed by a trusted certificate authority (CA). There are a total of three files: the public key of the Certificate Authority (CA) in a file named `ca.crt`, and the public and private parts of the client certificate used to connect to the authentication service. The client certificate files are named `client.crt` and `client.key` for the public and private parts of the certificate, respectively. All three files are found within the directory named by the `arch-dir` attribute of the installed extension. To find the `arch-dir` directory, use the `p4 extension` command:

```shell
$ p4 extension --list --type=extensions
... extension Auth::loginhook
... [snip]
... arch-dir server.extensions.dir/117E9283-732B-45A6-9993-AE64C354F1C5/1-arch
... data-dir server.extensions.dir/117E9283-732B-45A6-9993-AE64C354F1C5/1-data
```

where `[snip]` means some information has been omitted for brevity.

To change the certificates, you can replace the files with new content, keeping the names the same. Alternatively, you can change the _global_ configuration properties named `Authority-Cert`, `Client-Cert`, and `Client-Key` to point to files in a different location. The `Authority-Cert` setting specifies the path to the public key for the trusted certificate authority, which is used to verify that the authentication service is trustworthy. Note that the service validation is disabled by default, but can be enabled by setting `Verify-Peer` and `Verify-Host` to `true` in the global extension configuration.

The `Client-Cert` and `Client-Key` settings specify the paths of the client certificate public and private keys, respectively. These files should be in the PEM format, with the `BEGIN` and `END` lines to clearly indicate the contents.

To verify that the certificates used by the extension are _client_ certificates, you can use the `openssl` tool provided with the [OpenSSL](https://www.openssl.org) toolkit; note the **SSL client : Yes** in the example output below:

```shell
$ openssl x509 -in certificate.txt -noout -purpose
Certificate purposes:
SSL client : Yes
SSL client CA : No
SSL server : Yes
SSL server CA : No
[snip]
```

#### Testing the Certificates

To test the client certificates used by the extension, you can start by initiating a login request using the `curl` command against a running HAS instance, to retrieve a request identifier. Note that we are using the certificates in the `loginhook` directory as an example, be sure to use the actual client certificate files in your installation when testing.

```shell
$ curl --cacert loginhook/ca.crt https://has.example.com/requests/new/foobar
{"request":"01FKENCKS7F3A9YJV2Y71WZ6YZ", ...}
```

Using the `request` value above, we can now request the protected user profile data:

```shell
$ curl --cert loginhook/client.crt --key loginhook/client.key --cacert loginhook/ca.crt https://has.example.com/requests/status/01FKENCKS7F3A9YJV2Y71WZ6YZ
```

If successful, this request will pause for 1 minute before timing out with a '408' response since there is no user that will be performing a login on this request. Otherwise, if the client certificate is not accepted by the service, you will see the following error message:

```
certificates for <Nnn> from <Mmm> are not permitted
```

If that is the case, then verify that the HAS configuration specifies a certificate for CA that vouches for the validity of the client certificate.

### Authentication using JSON Web Tokens

Perforce users can be authenticated using JSON Web Tokens (JWT) rather than traditional credentials. This requires configuring the Helix Authentication Service to validate the token, and configuring the extension to extract the appropriate field from the payload of the token. To use this feature, the extension must have either `client-sso-groups` or `client-sso-users` or both configured with the set of users that will be authenticating using JWT. On the client system, the `P4LOGINSSO` setting must reference a program that will print the JWT. When a user in the "client-sso" set invokes `p4 login`, the `P4LOGINSSO` program will print the JWT, which the extension will then verifiy via the Helix Authentication Service. The service will return the JSON payload of the JWT, from which the extension will extract the field with the name given by the `client-name-identifier` extension setting. This value is then compared to the value retrieved via the `client-user-identifier`, in the same manner as with `user-identifier` and `name-identifier` for users that authenticate using web-based SSO.

An example program for retreiving a JWT from Azure AD in a managed VM is found in `cloud/azure/get-token.py` in this repository. This Python script will use the special Azure API to retrieve a JWT for the managed VM.

## Removing the Extension

To remove the login extension, perform the following three steps:

### Step 1: Find the installed extension by using the --list option.

```shell
$ p4 extension --list --type=extensions
... extension Auth::loginhook
... rev 1
... developer Perforce
... description-snippet SSO auth integration
... UUID 117E9283-732B-45A6-9993-AE64C354F1C5
... version 1.0
... enabled true
... arch-dir server.extensions.dir/117E9283-732B-45A6-9993-AE64C354F1C5/1-arch
... data-dir server.extensions.dir/117E9283-732B-45A6-9993-AE64C354F1C5/1-data
```

### Step 2: Remove that extension by using the --delete option as an administrative user.

```shell
$ p4 extension --delete Auth::loginhook --yes
Extension 'Auth::loginhook and its configurations' successfully deleted.
```

### Step 3: Restart the server

```shell
$ p4 admin restart
```

Without the `restart`, the server will report an error about a missing hook:

```
Command unavailable: external authentication 'auth-check-sso' trigger not found.
```

## Upgrading the Extension

The procedure for upgrading the extension to a newer release consists of these steps:

1. Print and retain the current extension configuration:
    * `p4 extension --configure Auth::loginhook -o`
    * `p4 extension --configure Auth::loginhook --name loginhook-a1 -o`
        - The `loginhook-a1` name is an example, the name you chose may be different.
1. Build the new extension package (`p4 extension --package loginhook`)
    * See the [Building the Extension](#building-the-extension) section for details.
1. Remove the existing installation (`p4 extension --delete Auth::loginhook --yes`)
    * See the [Removing the Extension](#removing-the-extension) section for details.
1. Install the new extension (`p4 extension --install loginhook.p4-extension -y`)
    * See the [Installing the Extension](#installing-the-extension) section for details.
1. Merge the previous configuration with those of the new extension
    * `p4 extension --configure Auth::loginhook`
    * `p4 extension --configure Auth::loginhook --name loginhook-a1`
1. Restart the Helix Server (`p4 admin restart`)

The process of migrating the old configuration to the new extension is not yet automated, so care must be taken to copy the values to the new extension configuration.

## Notes on Extension Behavior

### Authentication logic in detail

When the extension is installed, the **default** behavior is for **all** users to authenticate with SSO, with the exception of two categories of users: a) those users whose `AuthMethod` is set to `ldap`, and b) those users whose `Type` is not `standard` (i.e. operators and service users). LDAP users are expected to authenticate against an LDAP directory, and non-standard users typically cannot authenticate via a web browser.

If either the `client-sso-users` or `client-sso-groups` contains one or more entries (i.e. does not start with `...`), then any _matching_ users will require the use of the traditional SSO functionality in Helix Core Server. Specifically, the client must have a `P4LOGINSSO` that points to a program that emits a token. This is regardless of the `AuthMethod` or `Type` of the user.

If either the `sso-users` or `sso-groups` contains one or more entries (i.e. does not start with `...`), then any _matching_ users will **always** use SSO. This is regardless of the `AuthMethod` or `Type` of the user. Any users that do _not match_ will **not** authenticate with SSO. Note that LDAP users cannot used web-based SSO to authenticate with Helix Core Server. All such users **must** have their `AuthMethod` set to `perforce` to support web-based SSO. See [LDAP.md](./LDAP.md) for more information.

If `sso-users` and `sso-groups` are not defined (i.e. start with `...`), then the `non-sso-users` and `non-sso-groups` settings are taken into consideration, as well as the default behavior for the `AuthMethod` and `Type` as described above. 

### When the authentication service is unreachable

If a user attempts to authenticate with Helix Server while the authentication service is not accessible, the authentication extension will "error out" immediately, causing Helix Server to defer to another authentication mechanism (e.g. LDAP, database password). In this case the client will present a password prompt, as described in the [Troubleshooting](#troubleshooting) section.

### When user credentials are not accepted

If the user attempts to authenticate with the identity provider and enters invalid credentials, the extension will reject the login attempt completely, and in turn Helix Server will reject the user authentication. There is **no fallback** of any kind _if_ the authentication service is accessible and functioning properly.

### Login by superuser for another user

If a superuser performs a `login` for another user, as with the command `p4 login <username>`, the existing behavior will remain unchanged. That is, the extension will not be invoked and a ticket will immediately be issued for the user. In a similar manner, any multi-factor authentication (MFA) will also be implicitly granted for that user.

## Troubleshooting

### Client login reverts to password prompt

In the event that the Perforce client begins prompting for a password, rather than directing the user's browser to the identity provider, check that the Helix Authentication Service is running at the address referenced in the extension configuration (`Service-URL`). If the extension is not able to connect to the service, it will defer back to the server to handle the user authentication.

Ensure the debug logging is enabled in the extension, try the login again, and check the logs for any error messages. Based on the message in the log, check for a matching error in the issues described below.

### Login fails with 'P4LOGINSSO' not set

If a Perforce client sees the `Single sign-on on client failed: 'P4LOGINSSO' not set` error when attempting to log in to a Helix Server with the authentication extension installed, then it is likely that the authentication service was not reachable from the extension. The nature of this error can be confirmed by enabling the logging in the extension, attempt the login again, and look for a log entry that resembles the following:

```json
{"data":{"AuthPreSSO":"failed to get request identifier"},"nanos":927914375,
 "pid":11047,"recType":0,"seconds":1579641470}
```

As indicated in the log message, the extension was unable to reach the service to get a request identifier.

### Login via IdP successful, but server login fails (1)

The most likely scenario is that the user profile data returned by the identity provider is not matching the Perforce user. See the [Mapping User Profiles to Perforce Users](#mapping-user-profiles-to-perforce-users) section above for details on the basic setup. To determine if this is really the case, set the `enable-logging` *instance* configuration setting to `true` and look at the extension logs after making a login attempt. There should be an entry resembling the following:

```json
{"data":{"AuthCheckSSO":"received user data","sdata":{"nameID":"test-o365",
 "nameIDFormat":"urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"},
 "userid":"test-o365@example.com"},"nanos":600042464,"recType":0,"seconds":1578021016}
```

Note that the `nameID` value does not match the `userid`, although they are similar. The extension will only accept values that match **exactly**. In this example, it would seem that the `userid` is an email address (the `Email` field of the Perforce user spec), while the SAML Name ID is a username. There are two choices for resolving this mismatch: 1) change the SAML IdP configuration to return an email address for the Name ID, 2) change the `user-identifier` *instance* configuration of the extension to `user` and hope that the Perforce user name matches the SAML Name ID.

### Login via IdP successful, but server login fails (2)

Another reason that authentication will the identity provider will succeed but authentication with the server fails is that the user is configured to use LDAP for authentication. This can happen if the user is named in the `sso-users` or `sso-groups` extension setting _and_ their `AuthMethod` is set to `ldap`. As discussed in the [LDAP guide](./LDAP.md) this cannot work, either the user must authenticate with LDAP or web-based SSO, but not both.

### Login successful only after multiple attempts

When logging in, the `p4 login` is seemingly not satisfied until the user visits the same login URL two or three times, and only then will a ticket be issued. Otherwise, the login attempt fails after a timeout. This will happen if there are multiple extension **instance** configurations present. See the [Multiple Instance Configurations](#multiple-instance-configurations) section above for the commands to diagnose and correct the behavior.

### HTTP error code 401 in extension log

If the extension is failing to authenticate the user, and the extension log file contains something like this:

```json
{"data":{"AuthCheckSSO":"error: auth validation failed for user bruno","http-code":401,"http-error":"nil"},"nanos":194320152,"pid":30482,"recType":0,"seconds":1591982194}
```

Then the issue is that the extension is not sending certificates to the authentication service when the service is expecting them. If the service is configured to use HTTPS, then the extension must have a `Service-URL` that starts with `https://` in order to send client certificates to the service.

### HTTP error code 403 in extension log

If the extension is failing to authenticate the user, and the extension log file contains something like this:

```json
{"data":{"AuthCheckSSO":"error: auth validation failed for user bruno","http-code":403,"http-error":"nil"},"nanos":194320152,"pid":30482,"recType":0,"seconds":1591982194}
```

Then the issue is that the client certificates used by the extension to request the user profile from the authentication service is not acceptable. Either the certificate issuer is not trusted by the certificate authority in use (as named by the `CA_CERT_FILE` or `CA_CERT_PATH` settings in the service), or the common name in the client certificate does not match the pattern provided in the `CLIENT_CERT_CN` service setting. It could also be the case that the client certificate expired. In most cases, updating the client certificates in extension will resolve the issue.

### HTTP error code 408 in extension log (1)

If the extension log file contains something like this:

```json
{"data":{"AuthCheckSSO":"error: auth validation failed for user bruno","http-code":408,"http-error":"nil"},"nanos":194320152,"pid":30482,"recType":0,"seconds":1591982194}
```

This typically indicates that the user authenticaton took longer than the authentication service was configured to wait. By default, the service will wait 60 seconds for the user to complete the login process, after which it will respond to the `/requests/status` route with a `408` (timeout). To change the timeout period, set the `LOGIN_TIMEOUT` setting in the service to the desired number of seconds.

### HTTP error code 408 in extension log (2)

If the user is authenticating successfully with the service but the extension log still shows this error:

```json
{"data":{"AuthCheckSSO":"error: auth validation failed for user bruno","http-code":408,"http-error":"nil"},"nanos":194320152,"pid":30482,"recType":0,"seconds":1591982194}
```

Then there is a chance that the extension has more than one instance configuration. See the [Multiple Instance Configurations](#multiple-instance-configurations) section for more information on detecting and correcting this situation.

### HTTP error code 504 in extension log

If the extension is failing to authenticate the user, and the extension log file contains something like this:

```json
{"data":{"getData":"error: HTTP response: <html><body><h1>504 Gateway Time-out</h1>\nThe server didn't respond in time.\n</body></html>\n"},"nanos":3968637,"pid":1850,"recType":0,"seconds":1620069117}
{"data":{"AuthCheckSSO":"error: auth validation failed for user bruno","http-code":504,"http-error":"nil"},"nanos":4184180,"pid":1850,"recType":0,"seconds":1620069117}
```

Then the issue is that the reverse proxy in front of the authentication service is timing out before the service itself times out (e.g. after `LOGIN_TIMEOUT` seconds). The timeout defined in the reverse proxy should be longer than the login timeout defined in the authentication service.

### Curl "got nothing" errors in extension log

If the extension is failing to authenticate the user, and the extension log file contains something like this:

```json
{"data":{"AuthCheckSSO":"auth validation failed for user bruno","code":0,
 "error":"[CURL-EASY][GOT_NOTHING] Server returned nothing (no headers, no data) (52)"},
 "nanos":276255682,"pid":1661,"recType":0,"seconds":1578331572}
```

Then it may be that the service is experiencing an error. The `libcurl` error handling is very generalized, so the extension is not able to report detailed errors. When this happens, enable the debug logging in the authentication service and examine them after a login attempt to look for any possible errors.

If the service log does not indicate an error, the fault may lie with the SSL certificates used by the extension to connect to the service. On some systems, Debian buster being one example, the self-signed certificates provided with the extension are not adequately signed. These systems may require a message digest computed using SHA256, instead of the default SHA1. Try replacing the certificates in the extension, as described in the [Certificates](#certificates) section.

### Curl "Problem with the local SSL certificate (58)" in extension log

If the SSO login process is not triggering with `p4 login`, and the extension log contains something like the following:

```json
{"data":{"AuthPreSSO":"error: failed to get request identifier","http-code":0,"http-error":"[CURL-EASY][SSL_CERTPROBLEM] Problem with the local SSL certificate (58)"},"nanos":596087851,"pid":41,"recType":0,"seconds":1620082389}
```

Then the extension is not able to read the `client.crt` and `client.key` files. These files are located in the `server.extensions.dir/117E9283-732B-45A6-9993-AE64C354F1C5/1-arch` directory under the Perforce "root" directory. The files should be owned by the system user that is running the `p4d` process, readable by that user, and contain valid PEM-formatted public and private keys.

### Cannot change user password

Perforce users that are _not_ authenticating using the SSO extension will still be able to change their passwords in the Perforce server, however, the `auth.sso.allow.passwd` configurable must be set to `1` as described in the [Allowing for non-SSO Users](#allowing-for-non-sso-users) section. The error message below demonstrates the issue when `auth.sso.allow.passwd` is _not_ set to `1`:

```shell
$ p4 -u janedoe -p p4d.doc:1666 passwd
Command unavailable: external authentication 'auth-set' trigger not found.
```

### Cannot install unsigned extension

If when installing the extension you see a message from Helix Core Server like this:

```
Installation failure: extension package must be signed but is missing required
signature file or certificate file to validate authenticity.
```

Then it will be necessary to configure the server to allow for unsigned extensions. This is done by setting the `server.extensions.allow.unsigned` configurable to `1`, as shown below.

```shell
p4 configure set server.extensions.allow.unsigned=1
```

### non-LDAP users are not authenticated with SSO

When LDAP is configured in Helix Core Server, and a SSO trigger or extension is installed, non-LDAP users will not use the SSO mechanism. This is the default behavior of the Helix Core Server. However, LDAP authentication and web-based SSO do not work together, see [LDAP.md](./LDAP.md) for more information. To resolve this problem, set `auth.sso.nonldap` to `1` to instruct the server to allow for the user of SSO with non-LDAP users.

```shell
p4 configure set auth.sso.nonldap=1
```
