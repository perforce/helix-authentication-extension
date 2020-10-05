<?php
/* WARNING: The contents of this file is cached by Swarm. Changes to
 * it will not be picked up until the cached versions are removed.
 * See the documentation on the 'Swarm config cache'.
 */
return array(
    'environment' => array(
        'mode' => 'development',
        'hostname' => 'swarm.doc',
        'logout_url' => 'https://auth-svc.doc:3000/saml/logout',
    ),
    'p4' => array(
        'port' => 'p4d.doc:1666',
        'user' => 'swarm',
        'password' => 'REPLACEME',
        'sso_enabled' => true,
    ),
    'security' => array(
        'require_login' => false,
    ),
    'log' => array(
        'priority' => 7,
        'reference_id' => true,
    ),
    'mail' => array(
        'transport' => array(
            'host' => 'localhost',
        ),
    ),
    'saml' => array(
        'header' => 'saml-response: ',
        'sp' => array(
            'entityId' => 'urn:swarm-example:sp',
            'assertionConsumerService' => array(
                'url' => 'http://swarm.doc:8080',
            ),
        ),
        'idp' => array(
            'entityId' => 'urn:auth-service:idp',
            'singleSignOnService' => array(
                'url' => 'https://auth-svc.doc:3000/saml/login',
            ),
            'x509cert' => 'MIIEqDCCApACCQD3DESimNj1bDANBgkqhkiG9w0BAQsFADAWMRQwEgYDVQQDDAtBdXRoU2VydmljZTAeFw0yMDAyMjQyMTU0NDVaFw0zMDAyMjEyMTU0NDVaMBYxFDASBgNVBAMMC0F1dGhTZXJ2aWNlMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAsNRsbY/li6lu6HFqhdXryTvJ7X2ItrEhnFQPvXBiYTxcA4ct+L1eTwqZ3XnccSQIAkBun7ugQvp/BbPikR15hvMI56Uj41mjrAX2R9qdol7GYidHMyfgn5eW+JV1m62AKy+UdVzRaihq5QyM7jErp/61Q4FeSic0o+n9InJHeat1P9kuXee+CXjU10oMNc7XJjhJdvQSx6LXD169nywpy8lVE31PIQVUDq0bmQypTtSuZkV3tWfqsoz1KUwyiYbSvuykJfyBFrX/O/G6H8lMNYqOnWDIdEeBuj1tZ9J89VkePmt5L7/MtwtZ0wgGIvbKHGbbCP8yWArEclmDdUfI/sqQUZIRJKBKjaC+1DdNSeXaKtA3zbx+ye1Uj6Ztf50Y/C7l6zYv/rMUK5N+BumhXVGDq78TtNHBgTOPV57xwcu1mxjMi2B1llO/HMh1A5bXUk/rf9ZUvc9BR7I97rd5yLQM2OVbm+6VAtmaw6uagcXicS8+Rfmusw/Q29Sp6PdDgANgpWgZMprOrMp83SoHflQ0oD28I3gHz21+GTZeTJ8TcieCo0AeEYiVgdzZuuRPp3gmSUuT0iSrVb1tE1ZocL1mIm5RPx3lBOUu8coOfCphYPUHGVGzIFm9AsetC+AQhyrWN/hAmqMmLtbYDBV4idfFB4NgGSTs9Q/syASbdXsCAwEAATANBgkqhkiG9w0BAQsFAAOCAgEAfDwfUWmStB/ec0eRVVhN6p4pKNLlEVpJOTS5qSPrMmUFHXB7NNFYjO7Rgiokc0zYd8cuAa39bsyh1DuYIa1/dchwI8xNqo3OeMb0/mlvFdAEFH2O+7as62JRm4Pv3hGPFB1vCd5gSyu3hI02pHq/VAx/9q0djy4/Am9/AyK1z/8oy1yN98nJGBW7hfbuLaBUbnrdkY8Ei5usUt7lWrb+UpDu1KKRjPGF48lsb01MaqUlZumT6qagxTNVVb30rhCswBVWQVcBMPT+zxAsKpsrkTuY2u/e0mmrqSlcNqb8/huhHmJVbL19A+KP0Xcar8DmWhronpgGLamZgyeWFVesAr3c7NqdBVjOqlSirp/ZBgb42mrKs2IFhuDMzaOPy7QyOdgjhiCySvvlTamfQjOOYSKTpQ98sWiWEoW0NqycgOdznWlUqfGLtuXB4q2kSFt0n8O2KKBCdp5gxBSYdfB56bk3UkImb3fCJ33druOK/0naU9AuXWdtiV1oQpv1ReS+JBgJz+4Dd2gZWsejNzCBbuwmgd48tjul7o3TkhjCyz6cpWatotQGuPuAqCGTci3ApVi/uYx9iOhN/en03kk5yxmGx9ldCRWtm3PvADUWHmjE2qyVduva8nDhvdVYNOOWbKu0UttWNKW+lMt/xl/S/v3EE8sfeFV/xHx7n+6Wfh0=',
        ),
    ),
);
