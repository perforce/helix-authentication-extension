#!/usr/bin/env bash
#
# Start the server and tail the log.
#
set -e
if [ -x /opt/perforce/swarm/sbin/redis-server-swarm ]; then
    /opt/perforce/swarm/sbin/redis-server-swarm /opt/perforce/etc/redis-server.conf --daemonize yes
fi
touch /opt/perforce/swarm/data/log
chown www-data:www-data /opt/perforce/swarm/data/log
apachectl start

# install ticket for stand-alone p4d instance
echo Rebar123 | p4 -p p4d.doc:1666 -u swarm login -p > ticket
if [ ! -e /opt/perforce/swarm/data/config.php.original ]; then
    cp /opt/perforce/swarm/data/config.php /opt/perforce/swarm/data/config.php.original
fi
sed -e "s/P4D_TICKET/$(awk 'NR > 1' ticket)/" /opt/perforce/swarm/data/config.php.template > /opt/perforce/swarm/data/config.php.1

# install ticket for commit server (chicago)
echo Rebar123 | p4 -p chicago.doc:2666 -u swarm login -p > ticket
sed -e "s/CHICAGO_TICKET/$(awk 'NR > 1' ticket)/" /opt/perforce/swarm/data/config.php.1 > /opt/perforce/swarm/data/config.php.2
rm -f /opt/perforce/swarm/data/config.php.1

# install ticket for edge server (tokyo)
echo Rebar123 | p4 -p tokyo.doc:3666 -u swarm login -p > ticket
sed -e "s/TOKYO_TICKET/$(awk 'NR > 1' ticket)/" /opt/perforce/swarm/data/config.php.2 > /opt/perforce/swarm/data/config.php
rm -f /opt/perforce/swarm/data/config.php.2
rm -f ticket

exec tail -f /opt/perforce/swarm/data/log
