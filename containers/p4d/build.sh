#!/usr/bin/env bash
#
# Configure the p4d instance during build time.
#
set -e

# would be nice to get the P4PORT passed to this script
export P4PORT=0.0.0.0:1666
export P4USER=super
export P4PASSWD=Rebar123

# start the server so we can populate it with data
p4dctl start -o '-p 0.0.0.0:1666' despot
echo ${P4PASSWD} | p4 login

#
# Install and configure the extension.
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
# Populate p4d with test data.
#
p4 user -f -i < user_george.txt
yes ea0c350c-4766-4bf8-892d-86fdfc154bd5 | p4 passwd george

#
# create a group with long lived tickets, log in again
#
p4 group -i < group_notimeout.txt
p4 logout
echo ${P4PASSWD} | p4 login

#
# stop the server so that the run script can start it again,
# and the authentication changes will take effect
#
p4dctl stop despot
