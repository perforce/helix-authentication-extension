#!/usr/bin/env bash
#
# Configuration script for Helix Authentication Service.
#
# Copyright 2020, Perforce Software Inc. All rights reserved.
#
MONOCHROME=false
DEBUG=false
AUTH_TRIGGER=''
AUTH_EMAIL=''
AUTH_USER=''
AUTH_HOST=''
AUTH_METHOD=''
AUTH_SCHEME=''
AUTH_TOKEN=''

# Print arguments to STDERR and exit.
function die() {
    error "FATAL: $*" >&2
    exit 1
}

# Print the first argument in red text on STDERR.
function error() {
    $MONOCHROME || echo -e "\033[31m$1\033[0m" >&2
    $MONOCHROME && echo -e "$1" >&2 || true
}

# Print the first argument in blue text on STDERR.
function debug() {
    $DEBUG || return 0
    $MONOCHROME || echo -e "\033[33m$1\033[0m" >&2
    $MONOCHROME && echo -e "$1" >&2 || true
}

# Print the usage text to STDOUT.
function usage() {
    cat <<EOS

Usage:

    mfa-trigger.sh [-m] [-h] ...

Description:

    Test trigger playing with MFA and HAS on the same instance.

    Most of these options are not implemented (yet).

    -m
        Monochrome; no colored text.

    --type <trigger>
        Trigger to run: pre-2fa, init-2fa, or check-2fa

    --email <user-email>
        Email address of the Perforce user authenticating.

    --user <user-name>
        Name of the Perforce user authenticating.

    --host <host-addr>
        Host address of the client system.

    --method <method>
        The authentication method from list-methods.

    --scheme <scheme>
        The authentication scheme set by init-auth.

    --token <token>
        The stashed token from the last init-auth.

    --debug
        Enable debugging output for this configuration script.

    -h / --help
        Display this help message.

EOS
}

# Echo the array inputs separated by the first argument.
function join_by() {
    local IFS="$1"; shift; echo "$*";
}

function read_arguments() {
    local ARGS=(type: email: user: host: method: scheme: token: debug help)
    local TEMP=$(getopt -n 'mfa-trigger.sh' \
        -o 'hm' \
        -l "$(join_by , ${ARGS[@]})" -- "$@")
    if (( $? != 0 )); then
        usage
        exit 1
    fi

    # Re-inject the arguments from getopt, so now we know they are valid and in
    # the expected order.
    eval set -- "$TEMP"
    while true; do
        case "$1" in
            -h)
                usage
                exit 0
                ;;
            -m)
                MONOCHROME=true
                shift
                ;;
            --type)
                AUTH_TRIGGER=$2
                shift 2
                ;;
            --email)
                AUTH_EMAIL=$2
                shift 2
                ;;
            --user)
                AUTH_USER=$2
                shift 2
                ;;
            --host)
                AUTH_HOST=$2
                shift 2
                ;;
            --method)
                AUTH_METHOD=$2
                shift 2
                ;;
            --scheme)
                AUTH_SCHEME=$2
                shift 2
                ;;
            --token)
                AUTH_TOKEN=$2
                shift 2
                ;;
            --debug)
                DEBUG=true
                shift
                ;;
            --help)
                usage
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                die "Unknown option: $1"
                exit 1
                ;;
        esac
    done

    # spurious arguments that are not supported by this script
    if (( $# != 0 )); then
        usage
        exit 1
    fi
}

function run_pre_2fa() {
    cat <<EOT
{
    "status" : 0,
    "methodlist" : [
        [ "challenge", "type something in response to a challenge" ],
    ]
}
EOT
}

function run_init_2fa() {
    cat <<EOT
{
    "status": 0,
    "scheme": "challenge",
    "message": "Please enter your response",
    "challenge": "ABBACD",
    "token": "REQID:20003339189"
}
EOT
}

function run_check_2fa() {
    cat <<EOT
{
    "status": 0
}
EOT
}

function main() {
    set -e
    read_arguments "$@"
    if [[ "${AUTH_TRIGGER}" == 'pre-2fa' ]]; then
        run_pre_2fa
    elif [[ "${AUTH_TRIGGER}" == 'init-2fa' ]]; then
        run_init_2fa
    elif [[ "${AUTH_TRIGGER}" == 'check-2fa' ]]; then
        run_check_2fa
    else
        error "Unknown trigger type: <<${AUTH_TRIGGER}>>"
        usage
        exit 1
    fi
}

main "$@"
