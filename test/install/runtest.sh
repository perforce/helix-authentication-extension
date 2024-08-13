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
# (since at least version P4D/LINUX26X86_64/2021.1/2126753)
p4 configure set server.extensions.allow.unsigned=1

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
    --skip-tests

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
    --skip-tests

p4 -ztag extension --configure Auth::loginhook -o | tr -s '[:space:]' ' ' > output
grep -q 'Auth-Protocol: oidc' output
grep -q 'Service-URL: https://has.example.com' output

p4 extension --configure Auth::loginhook --name loginhook-a1 -o | tr -s '[:space:]' ' ' > output
grep -q 'enable-logging: true' output
grep -q 'name-identifier: email' output
grep -q 'non-sso-users: super' output
grep -q 'non-sso-groups: ... (none)' output
grep -Eq '[^-]sso-users: ... \(none\)' output
grep -Eq '[^-]sso-groups: ... \(none\)' output
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
    --skip-tests

p4 -ztag extension --configure Auth::loginhook -o | tr -s '[:space:]' ' ' > output
grep -q 'Auth-Protocol: saml' output
grep -q 'Service-URL: https://localhost:3000' output

p4 extension --configure Auth::loginhook --name loginhook-a1 -o | tr -s '[:space:]' ' ' > output
grep -q 'enable-logging: ... off' output
grep -q 'name-identifier: nameID' output
grep -q 'non-sso-users: super' output
grep -q 'non-sso-groups: ... (none)' output
grep -Eq '[^-]sso-users: ... \(none\)' output
grep -Eq '[^-]sso-groups: ... \(none\)' output
grep -q 'user-identifier: fullname' output

#
# inject settings that the configure script normally does not touch
#
PROG1="/Service-Down-URL:/ { print; print \"\t\thttps://corp.example.com\"; getline; next; }"
PROG2="/Client-Cert:/ { print; print \"\t\tmyclient.crt\"; getline; next; }"
PROG3="/Client-Key:/ { print; print \"\t\tmyclient.key\"; getline; next; }"
PROG4="/Authority-Cert:/ { print; print \"\t\tcorp-ca.crt\"; getline; next; }"
PROG5="/Verify-Peer:/ { print; print \"\t\tmaybe\"; getline; next; }"
PROG6="/Verify-Host:/ { print; print \"\t\tmaybe\"; getline; next; }"
p4 extension --configure Auth::loginhook -o | \
    awk "${PROG1} ${PROG2} ${PROG3} ${PROG4} ${PROG5} ${PROG6} {print}" | \
    p4 extension --configure Auth::loginhook -i

PROG1="/client-sso-users:/ { print; print \"\t\tchris, susan, harry\"; getline; next; }"
PROG2="/client-sso-groups:/ { print; print \"\t\tclient-group\"; getline; next; }"
PROG3="/client-user-identifier:/ { print; print \"\t\tcluserid\"; getline; next; }"
PROG4="/client-name-identifier:/ { print; print \"\t\tclnameid\"; getline; next; }"
p4 extension --configure Auth::loginhook --name loginhook-a1 -o | \
    awk "${PROG1} ${PROG2} ${PROG3} ${PROG4} {print}" | \
    p4 extension --configure Auth::loginhook --name loginhook-a1 -i

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
    --skip-tests

p4 -ztag extension --configure Auth::loginhook -o | tr -s '[:space:]' ' ' > output
grep -q 'Auth-Protocol: saml' output
grep -q 'Service-URL: https://localhost:3000' output
# ensure that the unconfigured settings are copied to the new installation
grep -q 'Service-Down-URL: https://corp.example.com' output
grep -q 'Client-Cert: myclient.crt' output
grep -q 'Client-Key: myclient.key' output
grep -q 'Authority-Cert: corp-ca.crt' output
grep -q 'Verify-Peer: maybe' output
grep -q 'Verify-Host: maybe' output

p4 extension --configure Auth::loginhook --name loginhook-a1 -o | tr -s '[:space:]' ' ' > output
grep -q 'enable-logging: ... off' output
grep -q 'name-identifier: nameID' output
grep -Eq '[^-]sso-users: jackson' output
grep -Eq '[^-]sso-groups: ... \(none\)' output
grep -q 'non-sso-groups: ... (none)' output
grep -q 'non-sso-users: ... (none)' output
grep -q 'user-identifier: fullname' output
# ensure that the unconfigured settings are copied to the new installation
cat output
grep -q 'client-sso-groups: client-group' output
grep -q 'client-sso-users: chris susan harry' output
grep -q 'client-user-identifier: cluserid' output
grep -q 'client-name-identifier: clnameid' output

#
# run the configure script and set up SSO groups
#
echo 'configuring extension for SSO groups...'
./helix-auth-ext/bin/configure-login-hook.sh -n \
    --p4port localhost:1666 \
    --super super \
    --superpassword Rebar123 \
    --service-url https://localhost:3000 \
    --default-protocol saml \
    --sso-groups requireds \
    --name-identifier nameID \
    --user-identifier fullname \
    --skip-tests

p4 -ztag extension --configure Auth::loginhook -o | tr -s '[:space:]' ' ' > output
grep -q 'Auth-Protocol: saml' output
grep -q 'Service-URL: https://localhost:3000' output

p4 extension --configure Auth::loginhook --name loginhook-a1 -o | tr -s '[:space:]' ' ' > output
grep -q 'enable-logging: ... off' output
grep -q 'name-identifier: nameID' output
grep -Eq '[^-]sso-users: ... \(none\)' output
grep -Eq '[^-]sso-groups: requireds' output
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
    --skip-tests

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
grep -Eq '[^-]sso-users: ... \(none\)' output
grep -Eq '[^-]sso-groups: ... \(none\)' output
grep -q 'user-identifier: user' output

echo -e "\nRunning negative test cases...\n"

#
# Switch to the negative cases in which we expect the configure script to return
# a non-zero exit code.
#
echo '>> need a valid service URL'
set +e
./helix-auth-ext/bin/configure-login-hook.sh -m -n > output 2>&1 2>&1
set -e
grep -q 'valid base URL' output

echo '>> need a valid p4 port'
unset P4PORT
set +e
./helix-auth-ext/bin/configure-login-hook.sh -m -n \
    --service-url http://has > output 2>&1
set -e
grep -q 'Port number out of range' output

echo '>> need a valid p4 user'
unset P4USER
set +e
./helix-auth-ext/bin/configure-login-hook.sh -m -n \
    --service-url http://has \
    --p4port :1666 > output 2>&1
set -e
grep -q 'Username must start with a letter' output

echo '>> need a valid name-identifier value'
set +e
./helix-auth-ext/bin/configure-login-hook.sh -m -n \
    --service-url http://has \
    --p4port :1666 \
    --super super \
    --superpassword Rebar123 > output 2>&1
set -e
grep -q 'value is required for the name identifier' output

echo '>> need a valid user-identifier value'
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
echo '>> positive case, everything is okay once more'
./helix-auth-ext/bin/configure-login-hook.sh -m -n \
    --service-url http://has \
    --p4port :1666 \
    --super super \
    --superpassword Rebar123 \
    --name-identifier email \
    --user-identifier email > output 2>&1
grep -q 'script is ready to make the configuration changes' output
