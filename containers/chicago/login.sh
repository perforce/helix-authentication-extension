#!/usr/bin/env bash
#
# Create a ticket for the commit service user on edge instance.
#
# Run manually using docker-compose exec chicago.doc /setup/login.sh
#
set -e
yes d4490c91-e4e0-4e1e-a5ea-fb5e0423a34e | \
    p4 -E P4TICKETS=/chicago/root/.p4tickets -u svc_chicago_commit -p tokyo.doc:3666 login
