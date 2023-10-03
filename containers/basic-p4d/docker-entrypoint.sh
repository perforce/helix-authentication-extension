#!/usr/bin/env bash
#
# Configure and start p4d, then tail its log forever.
#
# The server instance build-out is done at run time rather than build time since
# we are using a mounted volume for the p4 data.
#
set -e

export P4PORT='0.0.0.0:1666'
export P4USER=super
export P4PASSWD='Passw0rd!'
export SVC_NAME=main
export P4ROOT="/p4/${SVC_NAME}"

function configure_p4d() {
    # patch configure script to wait for p4d to start fully (P4-20611)
    cd /opt/perforce/sbin
    # ignore non-zero exit status when patch has already been applied
    set +e
    patch -p0 <<EOF
--- configure-helix-p4d.sh	2021-04-09 10:43:16.000000000 -0700
+++ configure-helix-p4d.sh	2021-04-09 10:43:19.000000000 -0700
@@ -963,6 +963,7 @@
         if [ $attemps -gt 10 ]; then
             die "Server failed to start!"
         fi
+        sleep 1
     done
 
     # If it's not a fresh installation, we're done at this point
EOF
    set -e
    ./configure-helix-p4d.sh -n -p ${P4PORT} -r ${P4ROOT} -u ${P4USER} -P "${P4PASSWD}" ${SVC_NAME}
}

function install_loginhook() {
    # enable database passwords so super can log in w/o SSO
    p4 configure set auth.sso.allow.passwd=1

    # disable the signed extensions requirement for now
    p4 configure set server.extensions.allow.unsigned=1

    # create a group with long lived tickets, log in again
    p4 group -i <<EOF
Group:	no_timeout
Timeout:	unlimited
Users:
	${P4USER}
EOF
    echo "${P4PASSWD}" | p4 login

    # install and configure the extension with placeholder values
    /setup/bin/configure-login-hook.sh -n \
        --p4port ${P4PORT} \
        --super ${P4USER} \
        --superpassword "${P4PASSWD}" \
        --service-url https://has.example.com:3000 \
        --enable-logging \
        --non-sso-groups no_timeout \
        --name-identifier nameID \
        --user-identifier email \
        --yes
}

#
# Configure the server the first time, writing to the mounted volume. The conf
# file in /etc can be lost between runs, so save and restore as needed.
#
if [ ! -d "${P4ROOT}/root" ]; then
    configure_p4d
    cp "/etc/perforce/p4dctl.conf.d/${SVC_NAME}.conf" "${P4ROOT}"
elif [ ! -f "/etc/perforce/p4dctl.conf.d/${SVC_NAME}.conf" ]; then
    cp "${P4ROOT}/${SVC_NAME}.conf" "/etc/perforce/p4dctl.conf.d"
    p4dctl start ${SVC_NAME}
else
    p4dctl start ${SVC_NAME}
fi

if [ ! -d "${P4ROOT}/root/server.extensions.dir" ]; then
    install_loginhook
fi

exec tail -f "${P4ROOT}/logs/log"
