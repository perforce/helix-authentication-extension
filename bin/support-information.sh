#!/usr/bin/env bash
#
# Support script for collecting details about the extension.
#
# Copyright 2023, Perforce Software Inc. All rights reserved.
#
INTERACTIVE=true
MONOCHROME=false
DEBUG=false
AUTH_EXTENSION='117E9283-732B-45A6-9993-AE64C354F1C5'

# Print arguments to STDERR and exit.
function die() {
    error "FATAL: $*" >&2
    exit 1
}

# Begin printing text in green.
function highlight_on() {
    $MONOCHROME || echo -n -e "\033[32m"
    $MONOCHROME && echo -n '' || true
}

# Reset text color to default.
function highlight_off() {
    $MONOCHROME || echo -n -e "\033[0m"
    $MONOCHROME && echo -n '' || true
}

# Print the argument in green text.
function highlight() {
    $MONOCHROME || echo -e "\033[32m$1\033[0m"
    $MONOCHROME && echo -e "$1" || true
}

# Print the input validation error in red text on STDERR.
function error_prompt() {
    if $INTERACTIVE; then
        error "$@"
    fi
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

    collect.sh [-n] [-m] ...

Description:

    Support script for Helix Authentication Extension.

    This script will collect information regarding the extension installation
    in a format suitable for sending to Perforce Support.

    -m
        Monochrome; no colored text.

    -n
        Non-interactive mode; exits immediately if prompting is required.

    --debug
        Enable debugging output for this configuration script.

    -h / --help
        Display this help message.

See the Helix Authentication Extension documentation for additional
information pertaining to configuring and managing the extension.

EOS
}

# Echo the array inputs separated by the first argument.
function join_by() {
    local IFS="$1"; shift; echo "$*";
}

# Ensure OS is compatible and dependencies are already installed.
function ensure_readiness() {
    if ! which p4 >/dev/null 2>&1; then
        die 'Perforce client "p4" is required. Please ensure "p4" is in the PATH.'
    fi
}

# Source selected P4 settings by use of the p4 set command.
# Has no effect if the settings have not already been set by the user.
function source_enviro() {
    if [ -n "$(p4 set -q P4PORT)" ]; then
        eval "$(p4 set -q P4PORT)"
    fi
    if [ -n "$(p4 set -q P4USER)" ]; then
        eval "$(p4 set -q P4USER)"
    fi
}

function read_arguments() {
    # build up the list of arguments in pieces since there are so many
    local ARGS=(debug help)
    local TEMP=$(getopt -n 'collect.sh' \
        -o 'hmn' \
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
            -n)
                INTERACTIVE=false
                shift
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

function ensure_extension() {
    if ! p4 extension --configure Auth::loginhook -o >/dev/null 2>&1; then
        error 'Authentication extension seemingly not installed.'
        die 'Try using the "perforce" user to run the script.'
    fi
}

function p4_info() {
    echo 'running p4 info...'
    p4 info > $COLLECT_TEMP/p4-info.txt
}

function p4_configure() {
    echo 'running p4 configure show allservers...'
    p4 configure show allservers > $COLLECT_TEMP/configure-all.txt
}

function p4_extensions() {
    echo 'running p4 extension --list --type extensions...'
    p4 extension --list --type extensions > $COLLECT_TEMP/extensions.txt
}

function p4_ext_configs() {
    echo 'running p4 extension --list --type configs...'
    p4 extension --list --type configs > $COLLECT_TEMP/configs.txt
}

function ext_global_config() {
    echo 'running p4 extension --configure Auth::loginhook -o...'
    p4 extension --configure Auth::loginhook -o > $COLLECT_TEMP/global-config.txt
}

function ext_instance_config() {
    echo 'running p4 extension --list --type configs...'
    # scan all of the extension configurations to find ours; there may be more
    # than one, and this will capture all of them
    CONFIGS=$(p4 extension --list --type configs)
    INSTANCE_NAME=''
    IS_OUR_EXT=false
    while read -r line; do
        if [[ "${line}" == '' ]]; then
            # reset whenever we encounter the split between configs
            INSTANCE_NAME=''
            IS_OUR_EXT=false
        else
            # evaluate the various fields of the configuration to determine if
            # it is ours and to consider just one entry point (we only need one
            # name to output our instance config)
            IFS=' ' read -r -a PARTS <<< "$line"
            if [[ "${PARTS[1]}" == 'config' ]]; then
                INSTANCE_NAME="${PARTS[2]}"
            fi
            if [[ "${PARTS[1]}" == 'uuid' && "${PARTS[2]}" == "${AUTH_EXTENSION}" ]]; then
                IS_OUR_EXT=true
            fi
            if [[ "${PARTS[1]}" == 'type' && "${PARTS[2]}" == 'auth-check-sso' ]] && $IS_OUR_EXT; then
                echo "running p4 extension --configure Auth::loginhook --name ${INSTANCE_NAME} -o..."
                p4 extension --configure Auth::loginhook --name "${INSTANCE_NAME}" -o > $COLLECT_TEMP/${INSTANCE_NAME}.txt
            fi
        fi
    done <<< "${CONFIGS}"
}

function ext_log_file() {
    # scan all of the extensions to find ours
    echo 'running p4 extension --list --type extensions...'
    EXTENSIONS=$(p4 extension --list --type extensions)
    IS_OUR_EXT=false
    DATA_DIR=''
    while read -r line; do
        if [[ "${line}" == '' ]]; then
            # reset whenever we encounter the split between configs
            IS_OUR_EXT=false
        else
            # evaluate the various fields of the configuration to determine if
            # it is ours and to consider just one entry point (we only need one
            # name to output our instance config)
            IFS=' ' read -r -a PARTS <<< "$line"
            if [[ "${PARTS[1]}" == 'UUID' && "${PARTS[2]}" == "${AUTH_EXTENSION}" ]]; then
                IS_OUR_EXT=true
            fi
            if [[ "${PARTS[1]}" == 'data-dir' ]] && $IS_OUR_EXT; then
                DATA_DIR=${PARTS[2]}
            fi
        fi
    done <<< "${EXTENSIONS}"
    # piece together the path to the log file and determine if we can read it
    if [[ -n "${DATA_DIR}" ]]; then
        P4ROOT=$(p4 info | grep 'Server root' | cut -d ' ' -f 3)
        FULLPATH="${P4ROOT}/${DATA_DIR}"
        if [ -d $FULLPATH ]; then
            cp $FULLPATH/log.json $COLLECT_TEMP
        else
            error 'Extension data directory is not accessible.'
            error 'This script must be run from the commit server.'
            error "Make sure your user can access ${FULLPATH}"
        fi
    else
        error 'Could not find authentication extension data-dir.'
    fi
}

# Print a summary of what was done and any next steps.
function print_summary() {
    cat <<EOT

Extension information collection complete!
Please provide the '${TAR_FILE}' file to Perforce support.

EOT
}

function main() {
    ensure_readiness
    source_enviro
    set -e
    read_arguments "$@"
    ensure_extension
    COLLECT_TEMP=$(mktemp -d)
    p4_info
    p4_configure
    p4_extensions
    p4_ext_configs
    ext_global_config
    ext_instance_config
    ext_log_file
    # colons confuse tar so use a colon-free time format
    TAR_FILE="loginhook-$(date +'%F-%H-%M-%S').tar.gz"
    tar zcf ${TAR_FILE} -C ${COLLECT_TEMP} .
    rm -rf ${COLLECT_TEMP}
    print_summary
}

main "$@"
