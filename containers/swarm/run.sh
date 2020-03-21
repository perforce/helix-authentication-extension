#!/usr/bin/env bash
#
# Start the server and tail the log.
#
set -e
if [ -x /opt/perforce/swarm/sbin/redis-server-swarm ]; then
    /opt/perforce/swarm/sbin/redis-server-swarm /opt/perforce/etc/redis-server.conf --daemonize yes
fi
apachectl start
echo Rebar123 | p4 -p p4d.doc:1666 -u swarm login -p > ticket
sed -e "s/REPLACEME/$(awk 'NR > 1' ticket)/" /opt/perforce/swarm/data/config.php.template > /opt/perforce/swarm/data/config.php
touch /opt/perforce/swarm/data/log
exec tail -f /opt/perforce/swarm/data/log
