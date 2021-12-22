#!/usr/bin/awk -f
#
# Configure the authentication extension for testing.
#

/^ExtP4USER:/ {
    print "ExtP4USER:\tsuper";
    next;
}

/Service-URL:/ {
    print;
    print "\t\thttps://authen.doc/";
    getline;
    next;
}

/enable-logging:/ {
    print;
    print "\t\ttrue";
    getline;
    next;
}

/\tname-identifier:/ {
    print;
    print "\t\tnameID";
    getline;
    next;
}

/\tuser-identifier:/ {
    print;
    print "\t\temail";
    getline;
    next;
}

/client-name-identifier:/ {
    print;
    print "\t\toid";
    getline;
    next;
}

/client-user-identifier:/ {
    print;
    print "\t\tuser";
    getline;
    next;
}

/client-sso-users:/ {
    print;
    print "\t\tfa2067ca-9797-4c3a-95b8-c6c2e87f615a";
    getline;
    next;
}

/non-sso-groups:/ {
    print;
    print "\t\tno_timeout";
    getline;
    next;
}

{print}
