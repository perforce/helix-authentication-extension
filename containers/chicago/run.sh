#!/usr/bin/env bash
#
# Start the server and tail the log.
#
set -e
p4dctl start -o '-p 0.0.0.0:2666' chicago_commit
exec tail -f /chicago/logs/log
