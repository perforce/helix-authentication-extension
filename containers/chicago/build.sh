#!/usr/bin/env bash
#
# Configure the p4d instance during build time.
#
set -e

# would be nice to get the P4PORT passed to this script
export P4PORT=0.0.0.0:2666
export P4USER=super
P4PASSWD=Rebar123

# start the server so we can populate it with data
p4dctl start -o '-p 0.0.0.0:2666' chicago_commit
echo ${P4PASSWD} | p4 login

# create the users
p4 user -f -i < user_jackson.txt
yes 94f6ce8c-fbea-4fcd-b7d0-564de93beb1b | p4 passwd jackson
p4 user -f -i < user_johndoe.txt
yes 18873fa3-1918-43ca-a518-c706def5e07f | p4 passwd johndoe
p4 user -f -i < user_commit_svc.txt
yes d4490c91-e4e0-4e1e-a5ea-fb5e0423a34e | p4 passwd svc_chicago_commit
p4 user -f -i < user_edge_svc.txt
yes f020c1e1-7528-4f6f-b84c-96336a4c955b | p4 passwd svc_tokyo_edge
p4 user -f -i < user_swarm.txt
yes ${P4PASSWD} | p4 passwd swarm

# create a group with long lived tickets, log in again
p4 group -i < group_notimeout.txt

# give the swarm user admin protections
p4 protect -o > protects.txt
echo '	admin user swarm * //...' >> protects.txt
p4 protect -i < protects.txt

# set up commit/edge service user permissions
p4 protect -i < protections.txt

# configure the commit/edge replication settings
# n.b. configure-helix-p4d.sh already defined the 'server'
p4 configure set chicago_commit#journalPrefix=/chicago/journals/journal
p4 configure set chicago_commit#lbr.autocompress=1
p4 configure set chicago_commit#monitor=2
p4 configure set chicago_commit#P4LOG=/chicago/logs/log
p4 configure set chicago_commit#P4TICKETS=/chicago/root/.p4tickets
p4 configure set chicago_commit#serviceUser=svc_chicago_commit
p4 configure set tokyo_edge#db.replication=readonly
p4 configure set tokyo_edge#journalPrefix=/tokyo/journals/journal
p4 configure set tokyo_edge#lbr.autocompress=1
p4 configure set tokyo_edge#lbr.replication=readonly
p4 configure set tokyo_edge#monitor=1
p4 configure set tokyo_edge#P4LOG=/tokyo/logs/log
p4 configure set tokyo_edge#P4TARGET=chicago.doc:2666
p4 configure set tokyo_edge#P4TICKETS=/tokyo/root/.p4tickets
p4 configure set tokyo_edge#rpl.compress=4
p4 configure set tokyo_edge#rpl.forward.login=1
p4 configure set tokyo_edge#serviceUser=svc_tokyo_edge
p4 configure set tokyo_edge#startup.1='pull -i 1'
p4 configure set tokyo_edge#startup.2='pull -u -i 1'
p4 configure set tokyo_edge#startup.3='pull -u -i 1'

# Don't worry p4d, it's just docker being fishy with its multiple addresses for
# the same container. Not that the default value was a problem, but better to be
# explicit about our intentions.
p4 configure set any#net.mimcheck=0

# Define the edge-server service configuration; the various settings have
# already been defined above, this just makes it look official.
p4 server -o -c edge-server tokyo_edge | p4 server -i

# configure authentication related settings
p4 configure set auth.sso.allow.passwd=1
p4 configure set auth.id=EXT_AUTH_ID
echo ${P4PASSWD} | p4 login
p4 configure set any#auth.id=EXT_AUTH_ID
echo ${P4PASSWD} | p4 login

# disable the signed extensions requirement for testing
p4 configure set server.extensions.allow.unsigned=1

# stop the server so that the run script can start it again, and the
# authentication changes will take effect
p4dctl stop chicago_commit
