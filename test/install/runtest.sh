#!/usr/bin/env bash
#
# Need a single RUN command in docker in order to start p4d and interact with it
# during the build process (i.e. docker build does not leave processes running
# between each of the steps).
#
set -e

# would be nice to get the P4PORT passed to this script
export P4PORT=0.0.0.0:1666
export P4USER=super
P4PASSWD=Rebar123

# start the server so we can populate it with data
p4dctl start -o '-p 0.0.0.0:1666' despot
echo ${P4PASSWD} | p4 login

# disable the signed extensions requirement for testing
# p4 configure set server.extensions.allow.unsigned=1

# create a group with long lived tickets, log in again
p4 group -i <<EOT
Group:	no_timeout
Timeout:	unlimited
Users:
	super
EOT
p4 logout
echo ${P4PASSWD} | p4 login

# run the configure script without a default protocol
# (should default to having "... " rather than nothing at all)
echo 'configuring extension for OIDC...'
./helix-auth-ext/bin/configure-login-hook.sh -n \
    --p4port localhost:1666 \
    --super super \
    --superpassword Rebar123 \
    --service-url https://auth.hostname.com \
    --non-sso-users super \
    --name-identifier email \
    --user-identifier email \
    --yes

echo 'waiting for p4d to restart...'
sleep 5

p4 -ztag extension --configure Auth::loginhook -o | tr -s '[:space:]' ' ' > output
grep -q 'Auth-Protocol: ... ' output
grep -q 'Service-URL: https://auth.hostname.com' output

# run the configure script and set up OIDC
echo 'configuring extension for OIDC...'
./helix-auth-ext/bin/configure-login-hook.sh -n \
    --p4port localhost:1666 \
    --super super \
    --superpassword Rebar123 \
    --service-url https://has.example.com \
    --default-protocol oidc \
    --enable-logging \
    --non-sso-users super \
    --name-identifier email \
    --user-identifier email \
    --yes

echo 'waiting for p4d to restart...'
sleep 5

p4 -ztag extension --configure Auth::loginhook -o | tr -s '[:space:]' ' ' > output
grep -q 'Auth-Protocol: oidc' output
grep -q 'Service-URL: https://has.example.com' output

p4 extension --configure Auth::loginhook --name loginhook-a1 -o | tr -s '[:space:]' ' ' > output
grep -q 'enable-logging: true' output
grep -q 'name-identifier: email' output
grep -q 'non-sso-users: super' output
grep -q 'non-sso-groups: ... (none)' output
grep -q 'user-identifier: email' output

# run the configure script and set up SAML
echo 'configuring extension for SAML...'
./helix-auth-ext/bin/configure-login-hook.sh -n \
    --p4port localhost:1666 \
    --super super \
    --superpassword Rebar123 \
    --service-url https://localhost:3000 \
    --default-protocol saml \
    --non-sso-users super \
    --name-identifier nameID \
    --user-identifier fullname \
    --yes

echo 'waiting for p4d to restart...'
sleep 5

p4 -ztag extension --configure Auth::loginhook -o | tr -s '[:space:]' ' ' > output
grep -q 'Auth-Protocol: saml' output
grep -q 'Service-URL: https://localhost:3000' output

p4 extension --configure Auth::loginhook --name loginhook-a1 -o | tr -s '[:space:]' ' ' > output
grep -q 'enable-logging: ... off' output
grep -q 'name-identifier: nameID' output
grep -q 'non-sso-users: super' output
grep -q 'non-sso-groups: ... (none)' output
grep -q 'user-identifier: fullname' output

#
# run the configure script and set up SSO users
#
echo 'configuring extension for SSO users...'
./helix-auth-ext/bin/configure-login-hook.sh -n \
    --p4port localhost:1666 \
    --super super \
    --superpassword Rebar123 \
    --service-url https://localhost:3000 \
    --default-protocol saml \
    --sso-users jackson \
    --name-identifier nameID \
    --user-identifier fullname \
    --yes

echo 'waiting for p4d to restart...'
sleep 5

p4 -ztag extension --configure Auth::loginhook -o | tr -s '[:space:]' ' ' > output
grep -q 'Auth-Protocol: saml' output
grep -q 'Service-URL: https://localhost:3000' output

p4 extension --configure Auth::loginhook --name loginhook-a1 -o | tr -s '[:space:]' ' ' > output
grep -q 'enable-logging: ... off' output
grep -q 'name-identifier: nameID' output
grep -Eq '[^-]sso-users: jackson' output
grep -q 'non-sso-groups: ... (none)' output
grep -q 'non-sso-users: ... (none)' output
grep -q 'user-identifier: fullname' output

# Run the configure script without any P4 environment variables or login ticket;
# the script is expected to take the settings from the user inputs, not the
# environment, and log in as the super user.
#
# Also be sure the previous extension configuration does not lock out the super
# user, otherwise this test will fail when the script tries to log in.
echo 'configuring extension for SAML w/o P4 env...'
p4 logout
unset P4PASSWD
unset P4PORT
unset P4USER
./helix-auth-ext/bin/configure-login-hook.sh -n \
    --p4port localhost:1666 \
    --super super \
    --superpassword Rebar123 \
    --service-url https://exthost:3000 \
    --default-protocol saml \
    --non-sso-users super \
    --name-identifier nameID \
    --user-identifier user \
    --yes

echo 'waiting for p4d to restart...'
sleep 5

# Set up the p4 environment again for the sake of these tests. Also note that
# the configure script already logged the super user into p4d, so we have a
# valid ticket at this point, too.
export P4PORT=0.0.0.0:1666
export P4USER=super
p4 -ztag extension --configure Auth::loginhook -o | tr -s '[:space:]' ' ' > output
grep -q 'Auth-Protocol: saml' output
grep -q 'Service-URL: https://exthost:3000' output

p4 extension --configure Auth::loginhook --name loginhook-a1 -o | tr -s '[:space:]' ' ' > output
grep -q 'enable-logging: ... off' output
grep -q 'name-identifier: nameID' output
grep -q 'non-sso-users: super' output
grep -q 'non-sso-groups: ... (none)' output
grep -q 'user-identifier: user' output

#
# Switch to the negative cases in which we expect the configure script to return
# a non-zero exit code.
#
set +e
./helix-auth-ext/bin/configure-login-hook.sh -m -n > output 2>&1 2>&1
set -e
grep -q 'valid base URL' output

set +e
./helix-auth-ext/bin/configure-login-hook.sh -m -n \
    --service-url http://has > output 2>&1
set -e
grep -q 'Port number out of range' output

set +e
./helix-auth-ext/bin/configure-login-hook.sh -m -n \
    --service-url http://has \
    --p4port :1666 > output 2>&1
set -e
grep -q 'Username must start with a letter' output

set +e
./helix-auth-ext/bin/configure-login-hook.sh -m -n \
    --service-url http://has \
    --p4port :1666 \
    --super super \
    --superpassword Rebar123 > output 2>&1
set -e
grep -q 'value is required for the name identifier' output

set +e
./helix-auth-ext/bin/configure-login-hook.sh -m -n \
    --service-url http://has \
    --p4port :1666 \
    --super super \
    --superpassword Rebar123 \
    --name-identifier email > output 2>&1
set -e
grep -q 'Enter either "user", "email", or "fullname" for user identifier' output

#
# finally everything is okay once again
#
./helix-auth-ext/bin/configure-login-hook.sh -m -n \
    --service-url http://has \
    --p4port :1666 \
    --super super \
    --superpassword Rebar123 \
    --name-identifier email \
    --user-identifier email > output 2>&1
grep -q 'script is ready to make the configuration changes' output
