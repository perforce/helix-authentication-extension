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
            'x509cert' => 'MIIEoTCCAokCAQEwDQYJKoZIhvcNAQEFBQAwGDEWMBQGA1UEAwwNRmFrZUF1dGhvcml0eTAeFw0yMTA3MTkyMzU3MzBaFw0zMTA3MTcyMzU3MzBaMBUxEzARBgNVBAMMCmF1dGhlbi5kb2MwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDB5IEMLFQxEAJMLaJ6aDTZwmfGKgApDzUh1YqbrenWhekBLVYmjOP1Pnv7lKeUzuHj+7zDqKKtFEWmfOjjFoSXR0sm9ShUfgEm6TQO6YN+gvwS8SqA74J64SMl48kIu215ZrEWHB5tTAnTTpmALUDAo4Hb/SZvGtjwUJUvBLt2l06IsdRUahdxkrGYKJIf7haPPSa7HbcRSY6lGAlreKZni0beigcRsv9iCnJd4R3JVAbafxVVs+lL3tDMOFtCKbKTs6s2sEAfb+HX130PejFenJ/wHGr5SNosecvXpke3AimJdiayJ4EmyySd7buR92W5ZddOn+e3w2o27j/9nCbOFhUYNgNbcP4gyeHCGf2R+tjdLpde6enbqnM2CkZSx9jPaFw4+4z9zmwgGWouxn72kpfkyHsx/u2ToDRJnXEjBN88CE4xzKT11I5/IMHxFEmUCTwEn46MI4iw/mE/JOCBvVaPRCD+1wpb1Wi5aWTRV5++ZbLxTUqY4c+lyO7rpivvXg52Qt4MQWYNgQSIN89aARFFComzVbgbguAtFRvPOJFD/7b9+VbRplcqMwUMFKySOsjtKJJwqzF2JJNTtXbuGKOsTpAc+1wPN/OUGU98uOj9zcfzPVINRKgs4iGtdMlwdsxw/9oS9Et9+LKyZPy3Kc5b4M6586V1icwmWbS2uQIDAQABMA0GCSqGSIb3DQEBBQUAA4ICAQBecKDVugNf+9tx/SOr3/Nj10JkvchgqyrIl4gkDX3QEZtRxBMmWCIcMUjBGdsr4cwQEr0Z1KoKb7RKAuRSJwa/7kXeimnUbF8XFjIrGTnoETMP6RglhvceDk065oeCjtG7O+Ut79+R3R03U6aFPNp0WUuUY++2WmyAu3GTTL4Dfsjcc29NQ5+Ku+2ks0P3HZJ2rphpRVEzaawcOxs0fERRKRdrElYCd/CEI1InUpYcfCR+Iz5j8dG3hxjhE8khv9idc0g0d2jrDD1mf2WLu6QBE4Wa8ViYw8lDkYD++zeFvVr1xgRg9q9dE3LR23KZeDYuDF+Kwu1HgKo0Dro44OZl9WWDqI7vY/I8L+WEj9Pk10pp2cmLBWpRn1tFi7p/D3LucrRAgrYrjUCmrTRjIA3yEhA1vJtocHSptveffscEEKEOfsCKQXLlFQMpTAGtAutelYbIeD80f5BFJTDe6BHS8EdoCXgmY5hWHt94KmEVogkBJuOTnMgeI3G2fPwHN5ucnX2oG8TbohbccHRahMWZUzgsAeQcQy8Hg5Y9m83ME/5Htfq60Fb1gIcvGd95BYdcICha7rUBC/Nlq2gf7pGsXm0Lz05TIzHqBXMrlqPrhripnz8Lzd9Sbefe8Cv0G5kxugRedzHfrrRkbyqrVBWAxm5z4QzniwR7OGChywVYdA==',
        ),
    ),
);
