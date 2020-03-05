#!/usr/bin/env bash
#
# Install the login extension during build time.
#
set -e

# would be nice to get the P4PORT passed to this script
export P4PORT=0.0.0.0:2666
export P4USER=super
P4PASSWD=Rebar123

# start the server so we can populate it with data
p4dctl start -o '-p 0.0.0.0:2666' chicago_commit
echo ${P4PASSWD} | p4 login

# install and configure the extension
p4 extension --package loginhook
p4 extension --install loginhook.p4-extension -y
rm -f loginhook.p4-extension
p4 extension --configure Auth::loginhook -o \
 | ./ext_config.awk \
 | p4 extension --configure Auth::loginhook -i
p4 extension --configure Auth::loginhook --name loginhook-all -o \
 | ./ext_config.awk \
 | p4 extension --configure Auth::loginhook --name loginhook-all -i

# stop the server so that the run script can start it again, and the
# authentication changes will take effect
p4dctl stop chicago_commit
