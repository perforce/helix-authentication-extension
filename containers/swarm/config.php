<?php
/* WARNING: The contents of this file is cached by Swarm. Changes to
 * it will not be picked up until the cached versions are removed.
 * See the documentation on the 'Swarm config cache'.
 */
return array(
    'environment' => array(
        'mode' => 'development',
        'hostname' => 'swarm.doc',
        'logout_url' => 'https://authen.doc/saml/logout',
    ),
    'p4' => array(
        'port' => 'p4d.doc:1666',
        'user' => 'swarm',
        'password' => 'REPLACEME',
        'sso' => 'optional',
    ),
    'security' => array(
        'https_strict' => true,
        'https_strict_redirect' => true,
        'https_port' => null,
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
                'url' => 'https://swarm.doc:8043',
            ),
        ),
        'idp' => array(
            'entityId' => 'urn:auth-service:idp',
            'singleSignOnService' => array(
                'url' => 'https://authen.doc/saml/login',
            ),
            'x509cert' => '-----BEGIN CERTIFICATE-----
MIIEoTCCAokCAQEwDQYJKoZIhvcNAQELBQAwGDEWMBQGA1UEAwwNRmFrZUF1dGhv
cml0eTAeFw0yMTExMDgyMjE1MzRaFw0zMTExMDYyMjE1MzRaMBUxEzARBgNVBAMM
CmF1dGhlbi5kb2MwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDC0Whu
jXOzgiKRBFtu38BgQ+hujR0UGUS2DvbrTzHCODyFGudvjTXLKp+Ms/4okfuvWdcz
PK5h0vy1lO/INlNDchRytIhrws9mIY9wuLJW3tgocDF2WARiON6ZABMx/JC2Qcs/
/K8gu0KIbxa8r7jfCs9YChOuqG7CD3JuXZVv9TKgoPgXTYCu/LbNxpm92hBRyffJ
K+DSdvdRnvnMrvR5LbED4Pk+k0DMXOtypgoC9KIvciIVS8TGPdpcyXxUg1ba7nik
TgwaOvywYKJHyY46gFcRSq8CDlcRPAGzDubneT1r2K0LmshWTB8fg+2XgcbTLSGy
it+Q6zRogU7ts/8dNk7wN1iGbP7jqrGYCUBZpnu97pNFFaHEB/2KZfNdIRF6ARJO
4bwXnXeNEIxWV6mARvFvSVfeISu09NfZCQuY1WGiO7dgfOb3OLpnEun6VpkwRJ9m
rZ6a4l2yHYCJTUlQchYbAzz40Ye2U1eW9UB0OMyXAbhPIIblNf8Uic8mDo98mG63
jdl+xrC9J1EbUej9v9NaqSfP09Pi6fgt3f6itCdoFaUgDJNrcCgKE09X4uvjL+sV
ISdBXE+C0ODMACCnpjnJ5QFHu+KoDsqdbArnm/cLU6Ck0wyOI72DqAuWR/SYXgkO
P0AA8LDbKQo00/rbEr5SRv+ya4MlaW4vkB7qGwIDAQABMA0GCSqGSIb3DQEBCwUA
A4ICAQBvjCCs8Xsi0U7KSrXq9q7Ysht7Jf+3a5JaA2gHU40CYIqRlReX3bcHAra5
2eZu77pazxDDtlWQtdv2C0P4l5hl+IhaUipDNQEciYcVBsJp2Lizedla0IEgfyEv
cJrvaULHRaNVhOkM2MJNE1xsP0yF34aXR85nmJ7K8qqHaxDokAyMqbVOwQW3nTaM
cvpesfaRwE8+eIjohMFEyuc+qpV1titjXueQ9GulkSX20tsiOmnl3KtY3VGCTrXs
mbbL46utMifkhYG6B3aQbcl16SeQth0Bihc9xfJHzrigwb4l+cfJe3eUPPclvTOs
2eWKcuMxAipmCir52Lr1WIFzIkAn2UqP4aZo8+MM2bsOGI09dNUmflg/ZyI+F5tl
kD5+gkn5fXwfQuVScYH7ecOIZhCvtsE0+FgqdMx5rkBKdxpGQqd8JpR6ENfJc2y6
okBJ30ZSXKIpBXz8dDlSwDwA5dpICW8YR6aTQuWgriadXS6Abni2gsx1sAPpt7bg
svjqwGB+wnqvD7+oCjH3/kLKTgm6Rh8NMViS/O7kyIa+8B7lw2EhTb6yySxVZgs5
gTw6pzhEX/3xGwgDOn4UK4gzk2xAkAUsh0IQNnfcj13P6VqslVLcI/2mqKT72Quo
MZXNWXiBpf4CRHvtHBOD7Jae4d7mlqAZp9JUHbVxTv4lHT3fcw==
-----END CERTIFICATE-----',
        ),
    ),
);
