#!/usr/bin/env bash
#
# Configure the p4d instance during build time.
#
set -e

# would be nice to get the P4PORT passed to this script
export P4PORT=0.0.0.0:1666
export P4USER=super
P4PASSWD=Rebar123

# start the server so we can populate it with data
p4dctl start -o '-p 0.0.0.0:1666' despot
echo ${P4PASSWD} | p4 login

#
# install and configure the extension
#
p4 extension --package loginhook
p4 extension --install loginhook.p4-extension -y
rm -f loginhook.p4-extension
p4 extension --configure Auth::loginhook -o \
 | ./ext_config.awk \
 | p4 extension --configure Auth::loginhook -i
p4 extension --configure Auth::loginhook --name loginhook-all -o \
 | ./ext_config.awk \
 | p4 extension --configure Auth::loginhook --name loginhook-all -i

#
# populate p4d with test data
#
p4 user -f -i < user_george.txt
p4 user -f -i < user_jackson.txt
yes 94f6ce8c-fbea-4fcd-b7d0-564de93beb1b | p4 passwd jackson
p4 user -f -i < user_johndoe.txt
yes 18873fa3-1918-43ca-a518-c706def5e07f | p4 passwd johndoe

#
# create a group with long lived tickets, log in again
#
p4 group -i < group_notimeout.txt
p4 logout
echo ${P4PASSWD} | p4 login

#
# enable LDAP authentication as well as database password
#
p4 ldap -i < ldap_simple.txt
p4 configure set auth.default.method=ldap
p4 configure set auth.ldap.order.1=simple
p4 configure set auth.sso.allow.passwd=1
p4 configure set auth.sso.nonldap=1

#
# stop the server so that the run script can start it again,
# and the authentication changes will take effect
#
p4dctl stop despot
