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

Refer to the `README.md` file in the `containers` directory for instructions.

## Controlling URL open

Setting `P4USEBROWSER` to `false` prevents the browser from opening when you
invoke `p4 login`.

## Configure Script on macOS

The configuration script (`bin/configure-login-hook.sh`) uses the GNU getopt
utility to read the command line arguments. However, macOS does not ship with
GNU getopt installed. To run the script on macOS, first install GNU getopt via
[Homebrew](https://brew.sh) `gnu-getopt` package, and then run the script with
the path to the GNU getopt directory:

```shell
$ PATH="/usr/local/opt/gnu-getopt/bin:$PATH" ./bin/configure-login-hook.sh
```

On M1 systems, the path will be different:

```shell
$ PATH="/opt/homebrew/opt/gnu-getopt/bin:$PATH" ./bin/configure-login-hook.sh
```
