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
        'p4d' => array(
            'port' => 'p4d.doc:1666',
            'user' => 'swarm',
            'password' => 'P4D_TICKET',
            'sso' => 'optional',
        ),
        'chicago' => array(
            'port' => 'chicago.doc:2666',
            'user' => 'swarm',
            'password' => 'CHICAGO_TICKET',
            'sso' => 'optional',
        ),
        'tokyo' => array(
            'port' => 'tokyo.doc:3666',
            'user' => 'swarm',
            'password' => 'TOKYO_TICKET',
            'sso' => 'optional',
        ),
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
);
