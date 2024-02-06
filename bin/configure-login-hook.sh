#!/usr/bin/env bash
#
# Configuration script for Helix Authentication Extension.
#
# Copyright 2023, Perforce Software Inc. All rights reserved.
#
INTERACTIVE=true
MONOCHROME=false
DEBUG=false
P4PORT=''
P4USER=''
P4PASSWD=''
RESTART_OK=false
SERVICE_URL=''
RESOLVE_HOST=''
SERVICE_DOWN_URL=''
CLIENT_CERT=''
CLIENT_KEY=''
AUTHORITY_CERT=''
VERIFY_PEER=''
VERIFY_HOST=''
DEFAULT_PROTOCOL=''
ENABLE_LOGGING=''
SKIP_TESTS=false
NON_SSO_USERS=''
NON_SSO_GROUPS=''
CLIENT_SSO_USERS=''
CLIENT_SSO_GROUPS=''
NAME_IDENTIFIER=''
USER_IDENTIFIER=''
CLIENT_NAME_IDENTIFIER=''
CLIENT_USER_IDENTIFIER=''
SSO_USERS=''
SSO_GROUPS=''
SSO_ALLOW_PASSWD_IS_SET=false
SSO_NONLDAP_IS_SET=false
ALLOW_NON_SSO=false
ALLOW_NON_LDAP=false
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
    [[ "$default" =~ ^[[:space:]]+$ ]] && default=''

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
    [[ "$default" =~ ^[[:space:]]+$ ]] && default=''

    while true; do
        local pw=''
        if [[ -n "$default" ]]; then
            # conceal the length of the incoming password
            read -s -e -p "$prompt [************]: " pw
            if [[ ! -n "$pw" ]]; then
                pw=$default
            fi
        else
            read -s -e -p "$prompt: " pw
        fi
        echo ''
        if $check_func "$pw"; then
            # No need to prompt again, the credentials will be checked
            # immediately rather than after receiving all user input.
            eval "$var=\"$pw\""
            break
        fi
    done
    return 0
}

# Display the given prompt and prompt for a yes/no response.
function prompt_for_yn() {
    local var="$1"
    local prompt="$2"
    local default="$3"

    [[ "$default" =~ ^[[:space:]]+$ ]] && default=''

    # read the yes/no input like any other input
    local input=''
    if [[ -n "$default" ]]; then
        read -e -p "$prompt [$default]: " input
        if [[ ! -n "$input" ]]; then
            input=$default
        fi
    else
        read -e -p "$prompt: " input
    fi

    # coerce the input value into either a 'yes' or a 'no'
    case $input in
        [yY][eE][sS]|[yY])
            eval "$var='yes'"
            ;;
        *)
            eval "$var='no'"
            ;;
    esac
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

    --allow-non-sso
        If this argument is given, set the server configurable to allow
        non-SSO authentication, such as database password and LDAP.

    --allow-non-ldap
        If this argument is given, set the server configurable to allow
        SSO-based authentication for users not authenticating with LDAP.

    --name-identifier <property>
        Property name of uniquely identifying value in IdP response. This is
        often the user email, typically named 'email', for OpenID Connect,
        while for SAML 2.0 this is likely to be 'nameID'.

    --user-identifier <attribute>
        Attribute of the Perforce user spec for comparing to the value from
        the identity provider. Can be one of 'user', 'email', or 'fullname'.

    --sso-users <list>
        Comma-separated list of Perforce users required to log in with SSO.
        When provided, any users not included in this list will not log in
        using SSO. This option is useful for testing the authentication setup
        with a limited set of users. If this value is given, then the value
        for --non-sso-users will be ignored by the extension.

    --sso-groups <list>
        Comma-separated list of Perforce groups whose members are required
        to log in with SSO. When provided, any users that are not members of
        any of the listed groups will not log in using SSO. If this value is
        given, then the value for --non-sso-groups will be ignored by the
        extension.

    --yes
        Restart the Helix Core server if running in non-interactive mode.

    --skip-tests
        Do not run the automated tests after installation.

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
        error "Too many parts in P4PORT: $PORT"
        return 1
    fi

    if [[ -n "$PROTO" ]] && [[ ! $PROTOS =~ $PROTO ]]; then
        error "Invalid Helix protocol: $PROTO"
        return 1
    fi

    # check port range (port >= 1024 && port <= 65535)
    # see http://www.iana.org/assignments/port-numbers for details
    local NUMRE='^[0-9]+$'
    if [[ ! $PNUM =~ $NUMRE ]] || [ $PNUM -lt 1024 -o $PNUM -gt 65535 ]; then
        error "Port number out of range (1024-65535): $PNUM"
        return 1
    fi
    return 0
}

# Validate first argument represents a valid Perforce username.
function validate_p4user() {
    local USERRE='^[a-zA-Z]+'
    if [[ -z "$1" ]] || [[ ! "$1" =~ $USERRE ]]; then
        error 'Username must start with a letter.'
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
    error 'Enter either "oidc" or "saml" for the protocol, or leave this blank.'
    return 1
}

# Validate that the name identifier is non-empty.
function validate_name_identifier() {
    if [[ -n "$1" ]]; then
        return 0
    fi
    error 'A value is required for the name identifier.'
    return 1
}

# Validate the selected user spec field name.
function validate_user_identifier() {
    if [[ "$1" == 'user' || "$1" == 'email' || "$1" == 'fullname' ]]; then
        return 0
    fi
    error 'Enter either "user", "email", or "fullname" for user identifier.'
    return 1
}

# Ensure OS is compatible and dependencies are already installed.
function ensure_readiness() {
    # Test write access by modifying something that is neither tracked by
    # version control nor created by this script, which might foil any logic
    # that decides whether to create the file or not.
    mkdir -p node_modules >/dev/null 2>&1
    if [ $? != 0 ]; then
        die 'You do not have permission to write to this directory.'
    fi
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
    local ARGS=(p4port: super: superpassword: service-url: default-protocol: enable-logging)
    ARGS+=(non-sso-users: non-sso-groups: sso-users: sso-groups: name-identifier: user-identifier:)
    ARGS+=(allow-non-sso yes debug skip-tests help)
    local TEMP=$(getopt -n 'configure-login-hook.sh' \
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
            --allow-non-sso)
                ALLOW_NON_SSO=true
                shift
                ;;
            --allow-non-ldap)
                ALLOW_NON_LDAP=true
                shift
                ;;
            --sso-users)
                SSO_USERS=$2
                shift 2
                ;;
            --sso-groups)
                SSO_GROUPS=$2
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
            --skip-tests)
                SKIP_TESTS=true
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
Service base URL               [${SERVICE_URL:-(not specified)}]
Preferred auth protocol        [${DEFAULT_PROTOCOL:-(not specified)}]
Debug logging enabled          [${ENABLE_LOGGING:-(not specified)}]
List of non-SSO users          [${NON_SSO_USERS:-(not specified)}]
List of non-SSO groups         [${NON_SSO_GROUPS:-(not specified)}]
List of SSO users              [${SSO_USERS:-(not specified)}]
List of SSO groups             [${SSO_GROUPS:-(not specified)}]
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
    cat <<EOT


The extension can write debugging information to a log file, which will
be named log.json, and is found in the 1-data directory of the extension
installation.

EOT
    prompt_for_yn ENABLE_LOGGING 'Do you want to enable debug logging?' "${ENABLE_LOGGING}"
}

# Prompt for a set of optional Perforce users that must use SSO auth.
function prompt_for_sso_users() {
    cat <<EOT


You may specify a list of Perforce users that are required to authenticate
using the single-sign-on integration. Any users not included in this list
will not authenticate using SSO. This is useful for testing the setup with
a limited set of users.

Note that setting a value for this configurable will mean that the value
for the "non-sso-users" setting will be ignored by the extension during
user authentication.

EOT
    prompt_for SSO_USERS 'Enter list of SSO users' "${SSO_USERS}" validate_user_list
}

# Prompt for a set of optional Perforce groups that must use SSO auth.
function prompt_for_sso_groups() {
    cat <<EOT


You may specify a list of Perforce groups that are required to authenticate
using the single-sign-on integration. Any users within any of those groups
will be required to use SSO authentication. Any users that are not members
of any of the groups will not authenticate using SSO.

Note that setting a value for this configurable will mean that the value
for the "non-sso-groups" setting will be ignored by the extension during
user authentication.

EOT
    prompt_for SSO_GROUPS 'Enter list of SSO groups' "${SSO_GROUPS}" validate_user_list
}

# Prompt for a set of optional Perforce users not using SSO auth.
function prompt_for_non_sso_users() {
    cat <<EOT


You may specify a list of Perforce users that will not be authenticating
using the single-sign-on integration. This would often include the super
user, as well as any operator users.

It is recommended to have at least one super or admin user that does not
authenticate using web-based SSO, and those users can be named here or in
the non-sso-groups setting in the next prompt.

EOT
    prompt_for NON_SSO_USERS 'Enter list of non-SSO users' "${NON_SSO_USERS}" validate_user_list
}

# Prompt for a set of optional Perforce groups not using SSO auth.
function prompt_for_non_sso_groups() {
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
    prompt_for NAME_IDENTIFIER 'Enter name of user profile property' "${NAME_IDENTIFIER}" validate_name_identifier
}

# Prompt for a user identifier value.
function prompt_for_user_identifier() {
    cat <<EOT


The user identifier is the name of the Perforce user field that will be
used to compare to the name identifier. This can be one of 'user', 'email',
or 'fullname', which refer to the 'User', 'Email', and 'FullName' fields
of the Perforce user spec.

EOT
    prompt_for USER_IDENTIFIER 'Choose the user spec field' "${USER_IDENTIFIER}" validate_user_identifier
}

# Prompt for inputs.
function prompt_for_inputs() {
    prompt_for_p4port
    while ! check_perforce_server; do
        prompt_for_p4port
    done
    prompt_for_p4user
    prompt_for_p4passwd
    while ! check_perforce_super_user; do
        prompt_for_p4user
        # Clear the password so prompt_for_password will behave as if no
        # password has yet been provided (which is partially true).
        P4PASSWD=''
        prompt_for_p4passwd
    done
    # Now that we have a valid p4 ticket for the super user, we can prime the
    # inputs based on the existing extension installation, if any.
    fetch_extension_settings
    prompt_for_service_url
    prompt_for_default_protocol
    prompt_for_enable_logging
    prompt_for_sso_users
    prompt_for_sso_groups
    prompt_for_non_sso_users
    prompt_for_non_sso_groups
    prompt_for_name_identifier
    prompt_for_user_identifier
}

# Ensure the Helix server is running.
function check_perforce_server() {
    local ISSSL=false
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
        ISSSL=true
    fi

    local P4INFO=""
    if ! P4INFO=$(p4 -p "$P4PORT" -ztag info 2>/dev/null); then
        # try using ssl if not already specified
        if ! $ISSSL; then
            if ! P4INFO=$(p4 -p "ssl:$P4PORT" -ztag info 2>/dev/null); then
                error "Unable to connect to Helix server [$P4PORT]"
                return 1
            fi
            P4PORT="ssl:${P4PORT}"
        else
            error "Unable to connect to Helix server [$P4PORT]"
            return 1
        fi
    fi

    # Divide the server version into parts that can be easily analyzed.
    local SERVER_VERSION="$(echo "$P4INFO" | grep -F '... serverVersion')"
    IFS=' ' read -r -a PARTS <<< "${SERVER_VERSION}"
    IFS='/' read -r -a PIECES <<< "${PARTS[2]}"
    local P4D_REL="${PIECES[2]}"
    local P4D_CHANGE="${PIECES[3]}"
    if [ "$(awk 'BEGIN{ if ("'$P4D_REL'" < "'$P4D_MIN_VERSION'") print(1); else print(0) }')" -eq 1 ] || \
       [ -n "$P4D_MIN_CHANGE" -a "$P4D_CHANGE" -lt "${P4D_MIN_CHANGE}" ]; then
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

# Retrieve any existing extension settings to prime the inputs.
#
# Requires a valid p4 ticket for the super user.
function fetch_extension_settings() {
    if ! p4 -p "$P4PORT" -u "$P4USER" extension --list --type extensions | grep -q '... extension Auth::loginhook'; then
        return
    fi
    GLOBAL=$(p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook -o)
    if (( $? != 0 )); then
        return
    fi
    PROTO=$(awk '/Auth-Protocol:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${GLOBAL}")
    if [[ ! "${PROTO}" =~ '...' ]]; then
        DEFAULT_PROTOCOL=${DEFAULT_PROTOCOL:-${PROTO}}
    fi
    URL=$(awk '/Service-URL:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${GLOBAL}")
    if [[ ! "${URL}" =~ '...' ]]; then
        SERVICE_URL=${SERVICE_URL:-${URL}}
    fi
    INSTANCE=$(p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook --name loginhook-a1 -o)
    if (( $? != 0 )); then
        return
    fi
    LOGGING=$(awk '/enable-logging:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${INSTANCE}")
    if [[ ! "${LOGGING}" =~ '...' ]]; then
        ENABLE_LOGGING='yes'
    fi
    NAMEID=$(awk '/[ \t]name-identifier:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${INSTANCE}")
    if [[ ! "${NAMEID}" =~ '...' ]]; then
        NAME_IDENTIFIER="${NAME_IDENTIFIER:-${NAMEID}}"
    fi
    USERID=$(awk '/[ \t]user-identifier:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${INSTANCE}")
    if [[ ! "${USERID}" =~ '...' ]]; then
        USER_IDENTIFIER="${USER_IDENTIFIER:-${USERID}}"
    fi
    NON_USERS=$(awk '/non-sso-users:/ { getline; while (match($0, "^\t\t")) { sub(/^[ \t]+/, ""); print; getline } }' <<<"${INSTANCE}")
    if [[ ! "${NON_USERS}" =~ '...' ]]; then
        IFS=',' readarray -t NAMES <<< "$NON_USERS"
        NON_SSO_USERS="${NON_SSO_USERS:-${NAMES[*]}}"
    fi
    NON_GROUPS=$(awk '/non-sso-groups:/ { getline; while (match($0, "^\t\t")) { sub(/^[ \t]+/, ""); print; getline } }' <<<"${INSTANCE}")
    if [[ ! "${NON_GROUPS}" =~ '...' ]]; then
        IFS=',' readarray -t NAMES <<< "$NON_GROUPS"
        NON_SSO_GROUPS="${NON_SSO_GROUPS:-${NAMES[*]}}"
    fi
    SSOUSERS=$(awk '/[ \t]sso-users:/ { getline; while (match($0, "^\t\t")) { sub(/^[ \t]+/, ""); print; getline } }' <<<"${INSTANCE}")
    if [[ ! "${SSOUSERS}" =~ '...' ]]; then
        IFS=',' readarray -t NAMES <<< "$SSOUSERS"
        SSO_USERS="${SSO_USERS:-${NAMES[*]}}"
    fi
    SSOGROUPS=$(awk '/[ \t]sso-groups:/ { getline; while (match($0, "^\t\t")) { sub(/^[ \t]+/, ""); print; getline } }' <<<"${INSTANCE}")
    if [[ ! "${SSOGROUPS}" =~ '...' ]]; then
        IFS=',' readarray -t NAMES <<< "$SSOGROUPS"
        SSO_GROUPS="${SSO_GROUPS:-${NAMES[*]}}"
    fi
}

# Retrieve any extension settings that are normally not modified by this script
# in order to preserve whatever values the admin had defined. In the process of
# "upgrading" the extension, the old one is removed, and as a result its
# configuration is lost as well.
#
# Requires a valid p4 ticket for the super user.
function fetch_unconfigured_settings() {
    if ! p4 -p "$P4PORT" -u "$P4USER" extension --list --type extensions | grep -q '... extension Auth::loginhook'; then
        return
    fi

    #
    # global settings
    #
    GLOBAL=$(p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook -o)
    if (( $? != 0 )); then
        return
    fi
    VALUE=$(awk '/Client-Cert:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${GLOBAL}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        CLIENT_CERT=${CLIENT_CERT:-${VALUE}}
    fi
    VALUE=$(awk '/Client-Key:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${GLOBAL}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        CLIENT_KEY=${CLIENT_KEY:-${VALUE}}
    fi
    VALUE=$(awk '/Resolve-Host:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${GLOBAL}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        RESOLVE_HOST=${RESOLVE_HOST:-${VALUE}}
    fi
    VALUE=$(awk '/Service-Down-URL:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${GLOBAL}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        SERVICE_DOWN_URL=${SERVICE_DOWN_URL:-${VALUE}}
    fi
    VALUE=$(awk '/Authority-Cert:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${GLOBAL}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        AUTHORITY_CERT=${AUTHORITY_CERT:-${VALUE}}
    fi
    VALUE=$(awk '/Verify-Peer:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${GLOBAL}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        VERIFY_PEER=${VERIFY_PEER:-${VALUE}}
    fi
    VALUE=$(awk '/Verify-Host:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${GLOBAL}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        VERIFY_HOST=${VERIFY_HOST:-${VALUE}}
    fi

    #
    # instance settings
    #    
    INSTANCE=$(p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook --name loginhook-a1 -o)
    if (( $? != 0 )); then
        return
    fi
    VALUE=$(awk '/client-name-identifier:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${INSTANCE}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        CLIENT_NAME_IDENTIFIER="${CLIENT_NAME_IDENTIFIER:-${VALUE}}"
    fi
    VALUE=$(awk '/client-user-identifier:/ { getline; sub(/^[ \t]+/, ""); print }' <<<"${INSTANCE}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        CLIENT_USER_IDENTIFIER="${CLIENT_USER_IDENTIFIER:-${VALUE}}"
    fi
    VALUE=$(awk '/client-sso-users:/ { getline; while (match($0, "^\t\t")) { sub(/^[ \t]+/, ""); print; getline } }' <<<"${INSTANCE}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        IFS=',' readarray -t NAMES <<< "$VALUE"
        CLIENT_SSO_USERS="${CLIENT_SSO_USERS:-${NAMES[*]}}"
    fi
    VALUE=$(awk '/client-sso-groups:/ { getline; while (match($0, "^\t\t")) { sub(/^[ \t]+/, ""); print; getline } }' <<<"${INSTANCE}")
    if [[ ! "${VALUE}" =~ '...' ]]; then
        IFS=',' readarray -t NAMES <<< "$VALUE"
        CLIENT_SSO_GROUPS="${CLIENT_SSO_GROUPS:-${NAMES[*]}}"
    fi
}

# Validate all of the inputs however they may have been provided.
function validate_inputs() {
    if ! validate_url "$SERVICE_URL"; then
        error 'A valid base URL for the service must be provided.'
        return 1
    fi
    if ! validate_p4port "${P4PORT}"; then
        return 1
    fi
    if ! check_perforce_server; then
        return 1
    fi
    if ! validate_p4user "${P4USER}"; then
        return 1
    fi
    if ! check_perforce_super_user; then
        return 1
    fi
    if ! validate_protocol "${DEFAULT_PROTOCOL}"; then
        return 1
    fi
    if ! validate_user_list "${SSO_USERS}"; then
        return 1
    fi
    if ! validate_user_list "${SSO_GROUPS}"; then
        return 1
    fi
    if ! validate_user_list "${NON_SSO_USERS}"; then
        return 1
    fi
    if ! validate_user_list "${NON_SSO_GROUPS}"; then
        return 1
    fi
    if ! validate_name_identifier "${NAME_IDENTIFIER}"; then
        return 1
    fi
    if ! validate_user_identifier "${USER_IDENTIFIER}"; then
        return 1
    fi
    return 0
}

# Normalize the user inputs.
function clean_inputs() {
    if [[ ! -z "$SERVICE_URL" ]]; then
        # trim trailing slashes
        SERVICE_URL="$(echo -n "$SERVICE_URL" | sed 's,[/]*$,,')"
    fi
    if [[ -z "${AUTHORITY_CERT}" ]]; then
        AUTHORITY_CERT='... use default value'
    fi
    if [[ -z "${CLIENT_CERT}" ]]; then
        CLIENT_CERT='... use default value'
    fi
    if [[ -z "${CLIENT_KEY}" ]]; then
        CLIENT_KEY='... use default value'
    fi
    if [[ -z "${VERIFY_PEER}" ]]; then
        VERIFY_PEER='... use default value'
    fi
    if [[ -z "${VERIFY_HOST}" ]]; then
        VERIFY_HOST='... use default value'
    fi
    if [[ -z "${RESOLVE_HOST}" ]]; then
        RESOLVE_HOST='... use default value'
    fi
    if [[ -z "${SERVICE_DOWN_URL}" ]]; then
        SERVICE_DOWN_URL='... use default value'
    fi
    if [[ -z "${CLIENT_NAME_IDENTIFIER}" ]]; then
        CLIENT_NAME_IDENTIFIER='... use default value'
    fi
    if [[ -z "${CLIENT_USER_IDENTIFIER}" ]]; then
        CLIENT_USER_IDENTIFIER='... use default value'
    fi
    if [[ -z "${DEFAULT_PROTOCOL}" ]]; then
        DEFAULT_PROTOCOL='... use auth service default protocol'
    fi
}

# Query the server for some configuration settings.
function query_configuration() {
    #
    # The p4 command-line makes for a poor API...
    #
    # $ p4 configure show security
    # security=3 (configure)
    # $ p4 configure show auth.sso.allow.passwd
    # auth.sso.allow.passwd:0 (default)
    # $ p4 configure set auth.sso.allow.passwd=1
    # For server 'any', configuration variable 'auth.sso.allow.passwd' set to '1'
    # $ p4 configure show auth.sso.allow.passwd
    # auth.sso.allow.passwd:1 (configure)
    #
    local PASSWD=$(p4 -p "$P4PORT" -u "$P4USER" configure show auth.sso.allow.passwd | grep -E 'auth.sso.allow.passwd[:=]1')
    if [[ "${PASSWD}" =~ 'auth.sso.allow.passwd' ]]; then
        SSO_ALLOW_PASSWD_IS_SET=true
    fi
    local NONLDAP=$(p4 -p "$P4PORT" -u "$P4USER" configure show auth.sso.nonldap | grep -E 'auth.sso.nonldap[:=]1')
    if [[ "${NONLDAP}" =~ 'auth.sso.nonldap' ]]; then
        SSO_NONLDAP_IS_SET=true
    fi
}

# Prompt user concerning other server configurables that may be appropriate
# based on the selections made so far (interactive only).
function conditional_prompts() {
    if ! $SSO_ALLOW_PASSWD_IS_SET; then
        if [[ -n "${NON_SSO_USERS}" ]] || [[ -n "${NON_SSO_GROUPS}" ]]; then
            # administrative users generally should not use SSO
            cat <<EOT

To allow the non-SSO users to authenticate with a database password or
LDAP, the server configurable auth.sso.allow.passwd must be set to '1'.
Would you like the script to make that change?

EOT
            select yn in 'Yes' 'No'; do
                case $yn in
                    Yes)
                        ALLOW_NON_SSO=true
                        break
                        ;;
                    No) break ;;
                esac
            done
        fi
    fi

    # LDAP and web-based SSO do not mix well
    if ! $SSO_NONLDAP_IS_SET; then
        cat <<EOT

To allow the use of SSO authentication for non-LDAP users the server
configurable auth.sso.nonldap must be set to '1'. Would you like the
script to make that change?

EOT
        select yn in 'Yes' 'No'; do
            case $yn in
                Yes)
                    ALLOW_NON_LDAP=true
                    break
                    ;;
                No) break ;;
            esac
        done
    fi
}

# Print what this script will do.
function print_preamble() {
    cat <<EOT

The script is ready to make the configuration changes.

The operations involved are as follows:

EOT
    echo "  * Set global Service-URL to ${SERVICE_URL}"
    if [[ -n "${DEFAULT_PROTOCOL}" ]] && [[ ! "${DEFAULT_PROTOCOL}" =~ '...' ]]; then
        echo "  * Set global Auth-Protocol to '${DEFAULT_PROTOCOL}'"
    fi
    if [[ "${ENABLE_LOGGING}" == 'yes' ]]; then
        echo "  * Set instance enable-logging to 'on'"
    else
        echo "  * Set instance enable-logging to 'off'"
    fi
    if [[ -n "${SSO_USERS}" ]]; then
        echo "  * Set instance sso-users to ${SSO_USERS}"
    fi
    if [[ -n "${SSO_GROUPS}" ]]; then
        echo "  * Set instance sso-groups to ${SSO_GROUPS}"
    fi
    if [[ -n "${NON_SSO_USERS}" ]]; then
        echo "  * Set instance non-sso-users to ${NON_SSO_USERS}"
    fi
    if [[ -n "${NON_SSO_GROUPS}" ]]; then
        echo "  * Set instance non-sso-groups to ${NON_SSO_GROUPS}"
    fi
    echo "  * Set instance name-identifier to ${NAME_IDENTIFIER}"
    echo "  * Set instance user-identifier to ${USER_IDENTIFIER}"
    if $ALLOW_NON_SSO; then
        echo "  * Configure server to allow non-SSO authentication."
    fi
    if $ALLOW_NON_LDAP; then
        echo "  * Configure server to allow SSO authentication for non-LDAP users."
    fi
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
    # Build the extension first to make sure we _can_ build it, before removing
    # any previous installation. The --delete will work with older clients while
    # the --package will fail, leaving us in weird state.
    #
    # do not clobber an existing (signed) package that is ready to install
    if [[ ! -f loginhook.p4-extension ]]; then
        debug 'building new extension...'
        local BUILD=$(p4 -p "$P4PORT" -u "$P4USER" extension --package loginhook)
        if [[ ! "${BUILD}" =~ 'packaged successfully' ]]; then
            error 'Failed to build extension package file'
            return 1
        fi
    fi
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
    # Start by assuming the extension was already built and signed, or that the
    # server is an older version that does not require signing. If that attempt
    # fails, then try again with the "pretty please" option.
    debug 'installing new extension...'
    local INSTALL=$(p4 -p "$P4PORT" -u "$P4USER" extension --install loginhook.p4-extension --yes 2>/dev/null)
    if [[ ! "${INSTALL}" =~ 'installed successfully' ]]; then
        INSTALL=$(p4 -p "$P4PORT" -u "$P4USER" extension --install loginhook.p4-extension --yes --allow-unsigned)
        if [[ ! "${INSTALL}" =~ 'installed successfully' ]]; then
            error 'Failed to install the extension on the server'
            error 'Try setting the server configurable server.extensions.allow.unsigned to 1'
            error 'and running this script again.'
            return 1
        fi
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
    local PROG4="/Service-Down-URL:/ { print; print \"\t\t${SERVICE_DOWN_URL}\"; getline; next; }"
    local PROG5="/Authority-Cert:/ { print; print \"\t\t${AUTHORITY_CERT}\"; getline; next; }"
    local PROG6="/Client-Cert:/ { print; print \"\t\t${CLIENT_CERT}\"; getline; next; }"
    local PROG7="/Client-Key:/ { print; print \"\t\t${CLIENT_KEY}\"; getline; next; }"
    local PROG8="/Verify-Peer:/ { print; print \"\t\t${VERIFY_PEER}\"; getline; next; }"
    local PROG9="/Verify-Host:/ { print; print \"\t\t${VERIFY_HOST}\"; getline; next; }"
    local PROGA="/Resolve-Host:/ { print; print \"\t\t${RESOLVE_HOST}\"; getline; next; }"
    local GLOBAL=$(p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook -o \
        | awk "${PROG1} ${PROG2} ${PROG3} ${PROG4} ${PROG5} ${PROG6} ${PROG7} ${PROG8} ${PROG9} ${PROGA} {print}" \
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
    local PROG2="/[^-]name-identifier:/ { print; print \"\t\t${NAME_IDENTIFIER}\"; getline; next; }"
    local PROG3="/[^-]user-identifier:/ { print; print \"\t\t${USER_IDENTIFIER}\"; getline; next; }"
    local SSO_USERS=$(format_user_list "${SSO_USERS}")
    local SSO_GROUPS=$(format_user_list "${SSO_GROUPS}")
    local NON_USERS=$(format_user_list "${NON_SSO_USERS}")
    local NON_GROUPS=$(format_user_list "${NON_SSO_GROUPS}")
    local CLIENT_USERS=$(format_user_list "${CLIENT_SSO_USERS}")
    local CLIENT_GROUPS=$(format_user_list "${CLIENT_SSO_GROUPS}")
    # use printf to not emit the ORS that (g)awk print does by default
    local PROG4="/non-sso-groups:/ { print; printf \"${NON_GROUPS}\"; getline; next; }"
    local PROG5="/non-sso-users:/ { print; printf \"${NON_USERS}\"; getline; next; }"
    local PROG6="/[^-]sso-users:/ { print; printf \"${SSO_USERS}\"; getline; next; }"
    local PROG7="/[^-]sso-groups:/ { print; printf \"${SSO_GROUPS}\"; getline; next; }"
    local PROG8="/client-sso-groups:/ { print; printf \"${CLIENT_GROUPS}\"; getline; next; }"
    local PROG9="/client-sso-users:/ { print; printf \"${CLIENT_USERS}\"; getline; next; }"
    local PROGA="/client-name-identifier:/ { print; print \"\t\t${CLIENT_NAME_IDENTIFIER}\"; getline; next; }"
    local PROGB="/client-user-identifier:/ { print; print \"\t\t${CLIENT_USER_IDENTIFIER}\"; getline; next; }"
    local LOCAL=$(p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook --name loginhook-a1 -o \
        | awk "${PROG1} ${PROG2} ${PROG3} ${PROG4} ${PROG5} ${PROG6} ${PROG7} ${PROG8} ${PROG9} ${PROGA} ${PROGB} {print}" \
        | p4 -p "$P4PORT" -u "$P4USER" extension --configure Auth::loginhook --name loginhook-a1 -i)
    if [[ ! "${LOCAL}" =~ 'Extension config loginhook-a1 saved' ]]; then
        error 'Failed to configure instance settings'
        return 1
    fi
    return 0
}

# Test the extension to ensure proper functioning, or at least let the user know
# that something may need fixing.
function test_extension() {
    highlight_on
    cat <<EOT

The configure script will now run some tests to ensure that the extension
is functioning as expected...

EOT
    p4 -p "$P4PORT" -u "$P4USER" extension --run loginhook-a1 test-all
    cat <<EOT

If every test indicates "OK" then the extension is ready.
If not, correct the issues before restarting the server.

EOT
    highlight_off
}

# Set server configurables according to user selections.
function configure_server() {
    if $ALLOW_NON_SSO; then
        p4 -p "$P4PORT" -u "$P4USER" configure set auth.sso.allow.passwd=1 >/dev/null 2>&1
    fi
    if $ALLOW_NON_LDAP; then
        p4 -p "$P4PORT" -u "$P4USER" configure set auth.sso.nonldap=1 >/dev/null 2>&1
    fi
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
    if $ALLOW_NON_SSO; then
        echo '  * The server was configured to allow non-SSO logins.'
    fi
    if $ALLOW_NON_LDAP; then
        echo '  * The server was configured to allow SSO for non-LDAP users.'
    fi
    cat <<EOT

What should be done now:
EOT
    if ! $INTERACTIVE && ! $RESTART_OK; then
        echo '  * Restart the Helix Core server at an appropriate time.'
    fi
    local ignore=$(test -n "${NON_SSO_USERS}" || test -n "${NON_SSO_GROUPS}")
    local NON_SSO_EXISTS=$?
    if ! $SSO_ALLOW_PASSWD_IS_SET && ! $ALLOW_NON_SSO && [[ $NON_SSO_EXISTS -eq 0 ]]; then
        echo '  * Set the Perforce configurable auth.sso.allow.passwd to 1 to allow'
        echo '    non-SSO user authentication via a database password, LDAP, etc.'
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
    source_enviro
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
    fetch_unconfigured_settings
    clean_inputs
    query_configuration
    if $INTERACTIVE; then
        conditional_prompts
    fi
    print_preamble
    if $INTERACTIVE; then
        prompt_to_proceed
    fi
    cd "$( cd "$(dirname "$0")" ; pwd -P )/.."
    install_extension
    configure_extension
    if ! $SKIP_TESTS; then
        test_extension
    fi
    configure_server
    restart_server
    print_summary
}

main "$@"
