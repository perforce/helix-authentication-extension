#!/usr/bin/awk -f
#
# Insert the P4PORT into the service configuration.
#

/^P4ROOT/ {
    print;
    print "P4PORT = 0.0.0.0:3666";
    next;
}

{print}
