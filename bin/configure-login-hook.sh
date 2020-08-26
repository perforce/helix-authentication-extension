#!/usr/bin/env bash
#
# Configuration script for Helix Authentication Extension.
#
# Copyright 2020, Perforce Software Inc. All rights reserved.
#
INTERACTIVE=true
MONOCHROME=false
DEBUG=false
PLATFORM=''
P4PORT=''
P4USER=''
P4PASSWD=''
RESTART_OK=false
SERVICE_URL=''
DEFAULT_PROTOCOL=''
ENABLE_LOGGING=''
NON_SSO_USERS=''
NON_SSO_GROUPS=''
NAME_IDENTIFIER=''
USER_IDENTIFIER=''
P4D_MIN_CHANGE='1797576'
P4D_MIN_VERSION='2019.1'

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

# Prompt the user for information by showing a prompt string. Optionally
# calls a validation function to check if the response is OK.
#
# prompt_for <VAR> <prompt> <default> [<validationfunc>]
function prompt_for() {
    local var="$1"
    local prompt="$2"
    local default="$3"
    local check_func=true

    [[ -n "$4" ]] && check_func=$4
    [[ "$default" =~ [[:space:]]+ ]] && default=''

    while true; do
        local input=''
        if [[ -n "$default" ]]; then
            read -e -p "$prompt [$default]: " input
            if [[ ! -n "$input" ]]; then
                input=$default
            fi
        else
            read -e -p "$prompt: " input
        fi
        if $check_func "$input"; then
            eval "$var=\"$input\""
            break
        fi
    done
    return 0
}

# Prompt the user for a password by showing a prompt string and not echoing
# input to the terminal. Optionally calls a validation function to check if the
# response is OK.
#
# prompt_for <VAR> <prompt> <default> [<validationfunc>]
function prompt_for_password() {
    local var="$1"
    local prompt="$2"
    local default="$3"
    local check_func=true

    [[ -n "$4" ]] && check_func=$4
    [[ "$default" =~ [[:space:]]+ ]] && default=''

    while true; do
        local pw=''
        local pw2=''
        if [[ -n "$default" ]]; then
            showDefault=$(echo "$default" | sed 's/./*/g')
            read -s -e -p "$prompt [$showDefault]: " pw
            if [[ ! -n "$pw" ]]; then
                pw=$default
            fi
        else
            read -s -e -p "$prompt: " pw
        fi
        echo ''
        if $check_func "$pw"; then
            if [[ -n "$default" ]]; then
                break
            fi
            read -s -e -p "Re-enter password: " pw2
            echo ''
            if [[ "$pw" == "$pw2" ]]; then
                eval "$var=\"$pw\""
                break
            else
                echo 'Passwords do not match. Please try again.'
            fi
        fi
    done
    return 0
}

# Display the given prompt and prompt for a yes/no response.
function prompt_for_yn() {
    local var="$1"
    local prompt="$2"

    while true; do
        read -p "${prompt} [y/n] " input
        case $input in
            [yY][eE][sS]|[yY])
                eval "$var='yes'"
                break
                ;;
            [nN][oO]|[nN])
                eval "$var='no'"
                break
                ;;
            *)
                echo 'Please answer yes or no.'
                ;;
        esac
    done
    return 0
}

# Display the given prompt and prompt for the Perforce user spec field.
function prompt_for_user_field() {
    local var="$1"
    local prompt="$2"

    echo $prompt
    select field in 'user' 'email' 'fullname'; do
        case $field in
            user)
                eval "$var=user"
                break
                ;;
            email)
                eval "$var=email"
                break
                ;;
            fullname)
                eval "$var=fullname"
                break
                ;;
            *)
                echo 'Please select an option'
                ;;
        esac
    done
    return 0
}

# Print the usage text to STDOUT.
function usage() {
    cat <<EOS

Usage:

    configure-login-hook.sh [-n] [-m] ...

Description:

    Configuration script for Helix Authentication Extension.

    This script will package, install, and configure the Helix Core
    extension for integrating with the Helix Authentication Service.

    -m
        Monochrome; no colored text.

    -n
        Non-interactive mode; exits immediately if prompting is required.

    --p4port <p4port>
        The P4PORT for the Helix Core server.

    --super <username>
        Helix Core super user's username.

    --superpassword <password>
        Helix Core super user's password.

    --service-url <service-url>
        HTTP/S address of the authentication service.

    --default-protocol <oidc|saml>
        The default authentication protocol, either 'oidc' or 'saml'.

    --enable-logging
        If this argument is given, enable debug logging in the extension.

    --non-sso-users <list>
        Comma-separated list of Perforce users excluded from SSO support.

    --non-sso-groups <list>
        Comma-separated list of Perforce groups excluded from SSO support.

    --name-identifier <property>
        Property name of uniquely identifying value in IdP response. This is
        often the user email, typically named 'email', for OpenID Connect,
        while for SAML 2.0 this is likely to be 'nameID'.

    --user-identifier <attribute>
        Attribute of the Perforce user spec for comparing to the value from
        the identity provider. Can be one of 'user', 'email', or 'fullname'.

    --yes
        Restart the Helix Core server if running in non-interactive mode.

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

# Validate the given argument is not empty, returning 0 if okay, 1 otherwise.
function validate_nonempty() {
    if [[ -z "$1" ]]; then
        error_prompt 'Please enter a value.'
        return 1
    fi
    return 0
}

# Validate the given argument as a URL, returning 0 if okay, 1 otherwise.
function validate_url() {
    local URLRE='^https?://.+'
    if [[ -z "$1" ]] || [[ ! "$1" =~ $URLRE ]]; then
        error_prompt 'Please enter a valid URL.'
        return 1
    fi
    return 0
}

# Validate first argument represents a valid P4PORT value.
function validate_p4port() {
    local PORT=$1
    local PROTOS='tcp tcp4 tcp6 tcp46 tcp64 ssl ssl4 ssl6 ssl46 ssl64'
    local PROTO=''
    local HOST=''
    local PNUM=''

    # extract the port number, if any
    local BITS=(${PORT//:/ })
    local COUNT=${#BITS[@]}
    if [[ $COUNT -eq 1 ]]; then
        PNUM=${BITS[0]}
    elif [[ $COUNT -eq 2 ]]; then
        [[ $PROTOS =~ ${BITS[0]} ]] && PROTO=${BITS[0]} || HOST=${BITS[0]}
        PNUM=${BITS[1]}
    elif [[ $COUNT -eq 3 ]]; then
        PROTO=${BITS[0]}
        HOST=${BITS[1]}
        PNUM=${BITS[2]}
    elif [[ $COUNT -gt 3 ]]; then
        error_prompt "Too many parts in P4PORT: $PORT"
        return 1
    fi

    if [[ -n "$PROTO" ]] && [[ ! $PROTOS =~ $PROTO ]]; then
        error_prompt "Invalid Helix protocol: $PROTO"
        return 1
    fi

    # check port range (port >= 1024 && port =< 65535)
    # see http://www.iana.org/assignments/port-numbers for details
    local NUMRE='^[0-9]+$'
    if [[ ! $PNUM =~ $NUMRE ]] || [ $PNUM -lt 1024 -o $PNUM -gt 65535 ]; then
        error_prompt "Port number out of range (1024-65535): $PNUM"
        return 1
    fi
    return 0
}

# Validate first argument represents a valid Perforce username.
function validate_p4user() {
    local USERRE='^[a-zA-Z]+'
    if [[ -z "$1" ]] || [[ ! "$1" =~ $USERRE ]]; then
        error_prompt 'Username must start with a letter.'
        return 1
    fi
    return 0
}

# Validate arguments represents space or comma-separated Perforce user names.
function validate_user_list() {
    local USERRE='^[a-zA-Z]+'
    # allow both comma and space separated arguments
    IFS=', ' read -r -a NAMES <<< "$*"
    if (( ${#NAMES[@]} > 0 )); then
        for NAME in "${NAMES[@]}"; do
            if [[ -z "$NAME" ]] || [[ ! "$NAME" =~ $USERRE ]]; then
                error_prompt "Name must start with a letter: $NAME"
                return 1
            fi
        done
    fi
    return 0
}

# Validate first argument is a valid authentication protocol.
function validate_protocol() {
    if [[ -z "$1" || "$1" == 'oidc' || "$1" == 'saml' ]]; then
        return 0
    fi
    error_prompt 'Enter either "oidc" or "saml" for the protocol, or leave this blank.'
    return 1
}

# Validate that the name identifier is non-empty.
function validate_name_identifier() {
    if [[ -n "$1" ]]; then
        return 0
    fi
    error_prompt 'A value is required for the name identifier.'
    return 1
}

# Validate the selected user spec field name.
function validate_user_identifier() {
    if [[ "$1" == 'user' || "$1" == 'email' || "$1" == 'fullname' ]]; then
        return 0
    fi
    error_prompt 'Enter either "user", "email", or "fullname" for user identifier.'
    return 1
}

# Ensure OS is compatible and dependencies are already installed.
function ensure_readiness() {
    if [[ -e '/etc/redhat-release' ]]; then
        PLATFORM=redhat
    elif [[ -e '/etc/debian_version' ]]; then
        PLATFORM=debian
    else
        die 'Could not determine OS distribution.'
    fi
    if ! which p4 >/dev/null 2>&1; then
        die 'Perforce client "p4" is required. Please ensure "p4" is in the PATH.'
    fi
}

function read_arguments() {
    # build up the list of arguments in pieces since there are so many
    local ARGS=(p4port: super: superpassword: service-url: default-protocol: enable-logging)
    ARGS+=(non-sso-users: non-sso-groups: name-identifier: user-identifier:)
    ARGS+=(yes debug help)
    local TEMP=$(getopt -n 'configure-auth-service.sh' \
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
            --p4port)
                P4PORT=$2
                shift 2
                ;;
            --super)
                P4USER=$2
                shift 2
                ;;
            --superpassword)
                P4PASSWD=$2
                shift 2
                ;;
            --service-url)
                SERVICE_URL=$2
                shift 2
                ;;
            --default-protocol)
                DEFAULT_PROTOCOL=$2
                shift 2
                ;;
            --enable-logging)
                ENABLE_LOGGING='yes'
                shift
                ;;
            --non-sso-users)
                NON_SSO_USERS=$2
                shift 2
                ;;
            --non-sso-groups)
                NON_SSO_GROUPS=$2
                shift 2
                ;;
            --name-identifier)
                NAME_IDENTIFIER=$2
                shift 2
                ;;
            --user-identifier)
                USER_IDENTIFIER=$2
                shift 2
                ;;
            --yes)
                RESTART_OK=true
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

# Show the argument values already provided.
function display_arguments() {
    highlight_on
    cat <<EOT
Summary of arguments passed:

Helix server P4PORT            [${P4PORT:-(not specified)}]
Helix super-user               [${P4USER:-(not specified)}]
Helix super-user password      [${P4PASSWD:-(not specified)}]
Service base URL               [${SERVICE_URL:-(not specified)}]
Preferred auth protocol        [${DEFAULT_PROTOCOL:-(not specified)}]
Debug logging enabled          [${ENABLE_LOGGING:-(not specified)}]
List of non-SSO users          [${NON_SSO_USERS:-(not specified)}]
List of non-SSO groups         [${NON_SSO_GROUPS:-(not specified)}]
Name identifier property       [${NAME_IDENTIFIER:-(not specified)}]
Perforce user property         [${USER_IDENTIFIER:-(not specified)}]

For a list of other options, type Ctrl-C to exit, and run this script with
the --help option.

EOT
    highlight_off
}

# Show a message about the interactive configuration procedure.
function display_interactive() {
    highlight_on
    cat <<EOT
You have entered interactive configuration for the extension. This script will
ask a series of questions, and use your answers to configure the extension for
first time use. Options passed in from the command line or automatically
discovered in the environment are presented as defaults. You may press enter
to accept them, or enter an alternative.
EOT
    highlight_off
}

# Prompt for the P4PORT of the Helix Core server.
function prompt_for_p4port() {
    prompt_for P4PORT 'Enter the P4PORT of the Helix server' "${P4PORT}" validate_p4port
}

# Prompt for the name of the Perforce super user.
function prompt_for_p4user() {
    prompt_for P4USER 'Enter the username of the super user' "${P4USER}" validate_p4user
}

# Prompt for the password of the Perforce super user.
function prompt_for_p4passwd() {
    prompt_for_password P4PASSWD 'Enter the password of the super user' "${P4PASSWD}"
}

# Prompt for the URL of the authentication service.
function prompt_for_service_url() {
    cat <<EOT


The URL of the authentication service that is accessible from the Helix Core
system. This value may be the externally visible address, or an internal
address, if needed.

EOT
    prompt_for SERVICE_URL 'Enter the URL for the authentication service' "${SERVICE_URL}" validate_url
}

# Prompt for the default authentication protocol.
function prompt_for_default_protocol() {
    cat <<EOT


The authentication protocol to be used by Helix Core can be specified here,
or left blank to allow the authentication service to use its own default.
Valid values include 'oidc' and 'saml'.

EOT
    prompt_for DEFAULT_PROTOCOL 'Enter the default authentication protocol' "${DEFAULT_PROTOCOL}" validate_protocol
}

# Prompt for enabling debug logging in the extension.
function prompt_for_enable_logging() {
    prompt_for_yn ENABLE_LOGGING 'Do you want to enable debug logging?'
}

# Prompt for a set of optional Perforce users not using SSO auth.
function prompt_for_nonsso_users() {
    cat <<EOT


You may specify a list of Perforce users that will not be authenticating
using the single-sign-on integration. This would often include the super
user, as well as any operator users.

EOT
    prompt_for NON_SSO_USERS 'Enter list of non-SSO users' "${NON_SSO_USERS}" validate_user_list
}

# Prompt for a set of optional Perforce groups not using SSO auth.
function prompt_for_nonsso_groups() {
    cat <<EOT


You may specify a list of Perforce groups that will not be authenticating
using the single-sign-on integration. Any users within any of those groups
will not use SSO authentication.

EOT
    prompt_for NON_SSO_GROUPS 'Enter list of non-SSO groups' "${NON_SSO_GROUPS}" validate_user_list
}

# Prompt for a name identifier value.
function prompt_for_name_identifier() {
    cat <<EOT


The name identifier is the name of the property in the user profile data
that uniquely identifiers that user. The value of that property will then
be compared to the "user identifier" value in the Perforce user spec (either
the username, full name, or email address).

When using SAML, the name identifier is typically 'nameID', while for OIDC
it is often 'email', however each identity provider may be different, and
custom configuration may have an effect on the returned profile data.

EOT
    prompt_for NAME_IDENTIFIER 'Enter name of user profile property' "${NAME_IDENTIFIER}" validate_nonempty
}

# Prompt for a user identifier value.
function prompt_for_user_identifier() {
    cat <<EOT


The name of the Perforce user field to compare to the name identifier.

EOT
    prompt_for_user_field USER_IDENTIFIER 'Choose the user spec field'
}

# Prompt for inputs.
function prompt_for_inputs() {
    prompt_for_p4port
    prompt_for_p4user
    prompt_for_p4passwd
    prompt_for_service_url
    prompt_for_default_protocol
    prompt_for_enable_logging
    prompt_for_nonsso_users
    prompt_for_nonsso_groups
    prompt_for_name_identifier
    prompt_for_user_identifier
}

# Ensure the Helix server is running.
function check_perforce_server() {
    if [ -z "$P4PORT" ]; then
        error 'No P4PORT specified'
        return 1
    fi

    local SSLRE="^ssl"
    local BITS=(${P4PORT//:/ })
    if [[ ${BITS[0]} =~ $SSLRE ]]; then
        p4 -p "$P4PORT" trust -f -y >/dev/null 2>&1
        if (( $? != 0 )); then
            error "Unable to trust the server [$P4PORT]"
            return 1
        fi
    fi

    local P4INFO=""
    if ! P4INFO=$(p4 -p "$P4PORT" -ztag info 2>/dev/null); then
        error "Unable to connect to Helix server [$P4PORT]"
        return 1
    fi

    # Divide the server version into parts that can be easily analyzed.
    local SERVER_VERSION="$(echo "$P4INFO" | grep -F '... serverVersion')"
    IFS=' ' read -r -a PARTS <<< "${SERVER_VERSION}"
    IFS='/' read -r -a PIECES <<< "${PARTS[2]}"
    local P4D_REL="${PIECES[2]}"
    local P4D_CHANGE="${PIECES[3]}"
    if [ "$(awk 'BEGIN{ if ("'$P4D_REL'" < "'$P4D_MIN_VERSION'") print(1); else print(0) }')" -eq 1 ] || \
       [ -n "$P4D_MIN_CHANGE" -a "$P4D_CHANGE" -lt "${P4D_MIN_CHANGE:-0}" ]; then
        error "This Helix server $P4D_REL/$P4D_CHANGE is not supported by Auth Extension."
        error "Auth Extension supports Helix servers starting with [$P4D_MIN_VERSION]/[${P4D_MIN_CHANGE}]"
        return 1
    fi
}

# Ensure the user credentials provided are valid and confer super access.
function check_perforce_super_user() {
    if [ -z "$P4PORT" -o -z "$P4USER" ]; then
        error 'No P4PORT or P4USER specified'
        return 1
    fi

    if [[ -z "$P4PASSWD" || "$P4PASSWD" =~ ^[[:blank:]]*$ ]]; then
        echo "P4PASSWD is empty or is whitespace. Skipping Helix server login."
    else
        if ! echo "$P4PASSWD" | p4 -p "$P4PORT" -u "$P4USER" login >/dev/null 2>&1; then
            error "Unable to login to the Helix server '$P4PORT' as '$P4USER' with supplied password"
            return 1
        fi
    fi

    if ! p4 -p "$P4PORT" -u "$P4USER" protects -m 2>&1 | grep -q 'super'; then
        error "User '$P4USER' must have super privileges"
        return 1
    fi
    return 0
}

# Validate all of the inputs however they may have been provided.
function validate_inputs() {
    if ! validate_url "$SERVICE_URL"; then
        error 'A valid base URL for the service must be provided.'
        return 1
    fi
    validate_p4port "${P4PORT}"
    validate_p4user "${P4USER}"
    check_perforce_server
    check_perforce_super_user
    validate_protocol "${DEFAULT_PROTOCOL}"
    validate_user_list "${NON_SSO_USERS}"
    validate_user_list "${NON_SSO_GROUPS}"
    validate_name_identifier "${NAME_IDENTIFIER}"
    validate_user_identifier "${USER_IDENTIFIER}"
    return 0
}

# Normalize the user inputs.
function clean_inputs() {
    if [[ ! -z "$SERVICE_URL" ]]; then
        # trim trailing slashes
        SERVICE_URL="$(echo -n "$SERVICE_URL" | sed 's,[/]*$,,')"
    fi
    if [[ -z "${DEFAULT_PROTOCOL}" ]]; then
        DEFAULT_PROTOCOL='... use auth service default protocol'
    fi
}

# Print what this script will do.
function print_preamble() {
    cat <<EOT

The script is ready to make the configuration changes.

The operations involved are as follows:

EOT
    echo "  * Set global Service-URL to ${SERVICE_URL}"
    echo "  * Set global Auth-Protocol to '${DEFAULT_PROTOCOL}'"
    echo "  * Set instance enable-logging to ${ENABLE_LOGGING}"
    if [[ -n "${NON_SSO_USERS}" ]]; then
        echo "  * Set instance non-sso-users to ${NON_SSO_USERS}"
    fi
    if [[ -n "${NON_SSO_GROUPS}" ]]; then
        echo "  * Set instance non-sso-groups to ${NON_SSO_GROUPS}"
    fi
    echo "  * Set instance name-identifier to ${NAME_IDENTIFIER}"
    echo "  * Set instance user-identifier to ${USER_IDENTIFIER}"
    echo ''
}

# Prompt user to proceed with or cancel the configuration.
function prompt_to_proceed() {
    echo 'Do you wish to continue?'
    select yn in 'Yes' 'No'; do
        case $yn in
            Yes) break ;;
            No) exit ;;
        esac
    done
}

# Package and install the extension in Helix Core server.
function install_extension() {
    # remove the extension if it is already installed, cannot install on top of
    # an existing installation
    local EXISTS=$(p4 -p "$P4PORT" -u "$P4USER" extension --list --type=extensions)
    if [[ "${EXISTS}" =~ 'Auth::loginhook' ]]; then
        debug 'removing existing extension install...'
        local DELETE=$(p4 -p "$P4PORT" -u "$P4USER" extension --delete Auth::loginhook --yes)
        if [[ ! "${DELETE}" =~ 'successfully deleted' ]]; then
            error 'Failed to remove existing extension installation'
            return 1
        fi
    fi
    debug 'building new extension...'
    rm -f loginhook.p4-extension
    local BUILD=$(p4 -p "$P4PORT" -u "$P4USER" extension --package loginhook)
    if [[ ! "${BUILD}" =~ 'packaged successfully' ]]; then
        error 'Failed to build extension package file'
        return 1
    fi
    debug 'installing new extension...'
    local INSTALL=$(p4 -p "$P4PORT" -u "$P4USER" extension --install loginhook.p4-extension -y)
    if [[ ! "${INSTALL}" =~ 'installed successfully' ]]; then
        error 'Failed to install the extension on the server'
        return 1
    fi
    return 0
}

# Format the list of space or comma-separated Perforce user/group names for
# inclusion in the extension configuration.
function format_user_list() {
    # allow both comma and space separated arguments
    IFS=', ' read -r -a NAMES <<< "$*"
    if (( ${#NAMES[@]} > 0 )); then
        for NAME in "${NAMES[@]}"; do
            # print with the escape intact for awk to process
            echo -n "\t\t${NAME}\n"
        done
    else
        echo -n "\t\t... (none)\n"
    fi
    return 0
}

# Make the prescribed changes to the extension configuration.
function configure_extension() {
    debug 'configuring global settings...'
    local PROG1="/^ExtP4USER:/ { print \"ExtP4USER:\t${P4USER}\"; next; }"
    local PROG2="/Auth-Protocol:/ { print; print \"\t\t${DEFAULT_PROTOCOL}\"; getline; next; }"
    local PROG3="/Service-URL:/ { print; print \"\t\t${SERVICE_URL}\"; getline; next; }"
    local GLOBAL=$(p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook -o \
        | awk -e "${PROG1} ${PROG2} ${PROG3} {print}" -- \
        | p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook -i)
    if [[ ! "${GLOBAL}" =~ 'Extension config loginhook saved' ]]; then
        error 'Failed to configure global settings'
        return 1
    fi

    debug 'configuring instance settings...'
    local LOGGING
    if [[ "${ENABLE_LOGGING}" == 'yes' ]]; then
        LOGGING='true'
    else
        LOGGING='... off'
    fi
    local PROG1="/enable-logging:/ { print; print \"\t\t${LOGGING}\"; getline; next; }"
    local PROG2="/name-identifier:/ { print; print \"\t\t${NAME_IDENTIFIER}\"; getline; next; }"
    local PROG3="/user-identifier:/ { print; print \"\t\t${USER_IDENTIFIER}\"; getline; next; }"
    local NON_USERS=$(format_user_list "${NON_SSO_USERS}")
    local NON_GROUPS=$(format_user_list "${NON_SSO_GROUPS}")
    # use printf to not emit the ORS that (g)awk print does by default
    local PROG4="/non-sso-groups:/ { print; printf \"${NON_GROUPS}\"; getline; next; }"
    local PROG5="/non-sso-users:/ { print; printf \"${NON_USERS}\"; getline; next; }"
    local LOCAL=$(p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook --name loginhook-a1 -o \
        | awk -e "${PROG1} ${PROG2} ${PROG3} ${PROG4} ${PROG5} {print}" -- \
        | p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook --name loginhook-a1 -i)
    if [[ ! "${LOCAL}" =~ 'Extension config loginhook-a1 saved' ]]; then
        error 'Failed to configure instance settings'
        return 1
    fi
    return 0
}

# Restart the server for the trigger changes to take effect.
function restart_server() {
    if $INTERACTIVE; then
        cat <<EOT


The configure script is now ready to restart the Helix Core server. This may
interrupt client requests and/or backups that are in progress. You may choose
not to restart and restart at a later time. This can be achieved using the
following command:

    p4 admin restart

EOT
        prompt_to_proceed
        debug 'Restarting Helix Core server...'
        p4 -p "$P4PORT" -u "$P4USER" admin restart
    elif $RESTART_OK; then
        debug 'Restarting Helix Core server...'
        p4 -p "$P4PORT" -u "$P4USER" admin restart
    else
        cat <<EOT


The configure script will not be restarting the Helix Core server at this time.
You may restart the server at an appropriate time using the following command:

    p4 admin restart

EOT
    fi
    return 0
}

# Print a summary of what was done and any next steps.
function print_summary() {
    cat <<EOT

==============================================================================
Automated configuration complete!

What was done:
  * The extension configuration was updated.
EOT
    if $INTERACTIVE || $RESTART_OK; then
        echo '  * The Helix Core server was restarted.'
    fi
    cat <<EOT

What should be done now:
EOT
    if ! $RESTART_OK; then
        echo '  * Restart the Helix Core server at an appropriate time.'
    fi
    cat <<EOT
  * If not already completed, please install and configure the Helix
    Authenication Service on a system addressed by the URL entered in the
    extension configuration. If the URL must be changed in the extension
    configuration, you may change the value using the p4 extension command
    like so, and changing the Service-URL setting:

    $ p4 extension --configure Auth::loginhook

==============================================================================

EOT
}

function main() {
    ensure_readiness
    set -e
    read_arguments "$@"
    if $INTERACTIVE || $DEBUG; then
        display_arguments
    fi
    if $INTERACTIVE; then
        display_interactive
        prompt_for_inputs
        while ! validate_inputs; do
            prompt_for_inputs
        done
    elif ! validate_inputs; then
        exit 1
    fi
    clean_inputs
    print_preamble
    if $INTERACTIVE; then
        prompt_to_proceed
    fi
    cd "$( cd "$(dirname "$0")" ; pwd -P )/.."
    install_extension
    configure_extension
    restart_server
    print_summary
}

main "$@"
