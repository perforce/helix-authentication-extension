#!/usr/bin/env bash
#
# Start the server and tail the log.
#
set -e
yes f020c1e1-7528-4f6f-b84c-96336a4c955b |\
    p4 -E P4TICKETS=/tokyo/root/.p4tickets -u svc_tokyo_edge -p chicago.doc:2666 login
p4dctl start -o '-p 0.0.0.0:3666' tokyo_edge
exec tail -f /tokyo/logs/log
