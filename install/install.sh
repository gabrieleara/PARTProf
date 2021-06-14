#!/bin/bash

# -------------------------------------------------------- #

function jump_and_print_path() {
    cd -P "$(dirname "$1")" >/dev/null 2>&1 && pwd
}

function get_script_path() {
    local _SOURCE
    local _PATH

    _SOURCE="${BASH_SOURCE[0]}"

    # Resolve $_SOURCE until the file is no longer a symlink
    while [ -h "$_SOURCE" ]; do
        _PATH="$(jump_and_print_path "${_SOURCE}")"
        _SOURCE="$(readlink "${_SOURCE}")"

        # If $_SOURCE is a relative symlink, we need to
        # resolve it relative to the path where the symlink
        # file was located
        [[ $_SOURCE != /* ]] && _SOURCE="${_PATH}/${_SOURCE}"
    done

    _PATH="$(jump_and_print_path "$_SOURCE")"
    echo "${_PATH}"
}

# Argument: relative path of project directory wrt this
# script directory
function get_project_path() {
    local _PATH
    local _PROJPATH

    _PATH=$(get_script_path)
    _PROJPATH=$(realpath "${_PATH}/$1")
    echo "${_PROJPATH}"
}

# -------------------------------------------------------- #

function usage() {
    cat <<EOF
usage: $0 [options] PATH

The provided path shall be valid within the destination host (either local or
accessed through the --ssh option). After the installation process it will
contain a 'PARTProf' folder with the desired components installed.

List of options (all optional):
  -h, --help        Prints this help message and returns with an error.
  -n, --dry-run     Prints out all commands but does not execute them.
  -D, --install-deps
                    Install dependencies before copying files. This option
                    installs dependencies both on the local and the remote host
                    using apt. Enabled by default.
  -l, --skip-deps-local
                    Do not install dependencies on the local host.
  -r, --skip-deps-remote
                    Do not install dependencies on the remote host.
  -d, --skip-deps   Do not install dependencies, neither on the local nor the
                    remote host.
  -s, --ssh HOSTNAME
                    A valid location to ssh into. You may be prompted one or
                    multiple times for credentials during the process.
  -E, --install-embedded
                    Enables the installation of the embedded component.
                    See Notes.
  -H, --install-host
                    Enables the installation of the host component. See Notes.

Notes:
    If neither '-E' nor '-H' options are provided, it is equivalent to providing
    both (because installing no component makes little sense).
EOF
}

opt_args=()
pos_args=()

function toshortopts() {
    while [ $# -gt 0 ]; do
        case "$1" in
        --install-deps)
            printf ' %s' "-D"
            ;;
        --skip-deps-local)
            printf ' %s' "-l"
            ;;
        --skip-deps-remote)
            printf ' %s' "-r"
            ;;
        --skip-deps)
            printf ' %s' "-d"
            ;;
        --install-embedded)
            printf ' %s' "-E"
            ;;
        --install-host)
            printf ' %s' "-H"
            ;;
        --help)
            printf ' %s' "-h"
            ;;
        --dry-run)
            printf ' %s' "-n"
            ;;
        --ssh)
            printf ' %s' "-s"
            ;;
        *)
            printf ' %s' "$1"
            ;;
        esac

        shift
    done
}

function separate_args() {
    local optstring="$1"
    local OPTION
    shift

    opt_args=()
    pos_args=()

    while [ $# -gt 0 ]; do
        unset OPTIND
        unset OPTARG
        unset OPTION
        while getopts ":$optstring" OPTION; do
            if [ "$OPTION" != : ]; then
                opt_args+=("-$OPTION")
            else
                OPTARG="-$OPTARG"
            fi

            if [ ! -z "$OPTARG" ]; then
                opt_args+=("$OPTARG")
            fi

            unset OPTARG
        done

        shift $((OPTIND - 1)) || true
        pos_args+=($1)
        shift || true
    done
}

function parse_opt_args() {
    local optstring="$1"
    local OPTION
    shift

    unset OPTIND
    unset OPTARG
    unset OPTION
    while getopts "$optstring" OPTION; do
        case $OPTION in
        E)
            install_neither=0
            install_embedded=1
            ;;
        H)
            install_neither=0
            install_host=1
            ;;
        h)
            usage
            # exit_code="0"
            return 1
            ;;
        D)
            install_deps_remote=1
            install_deps_local=1
            ;;
        l)
            install_deps_local=0
            ;;
        r)
            install_deps_remote=0
            ;;
        d)
            install_deps_remote=0
            install_deps_local=0
            ;;
        n)
            dry_run=1
            ;;
        s)
            if [ -z "$OPTARG" ]; then
                usage
                return 1
            fi
            ssh_host="$OPTARG"
            ;;
        *)
            printf "ERR: unrecognized option '-%s'.\n\n" "$OPTION" >&2
            usage
            return 1
            ;;
        esac
        unset OPTARG
    done

    # Too many options/unrecognized options
    shift $((OPTIND - 1)) || true
    if [ "$#" -gt 0 ]; then
        printf "ERR: unrecognized options.\n\n" >&2
        usage
        return 1
    fi

    if [ "$install_neither" = 1 ]; then
        install_embedded=1
        install_host=1
    fi
}

function parse_pos_args() {
    dest_path="${pos_args[0]}"
    if [ -z "$dest_path" ]; then
        printf "ERR: missing required argument.\n\n" >&2
        usage
        return 1
    fi
}

function echo_step() {
    printf '\n >>> %s\n\n' "$1"
}

function run_or_dry_run() {
    local the_command
    the_command="$@"

    # Note: must use bash -c to avoid problems with quoting
    if [ "$dry_run" = 1 ]; then
        echo "(DRY RUN) Command: $the_command"
    else
        bash -c "$the_command"
    fi
}

function test_ssh() {
    [ -z "$ssh_host" ] && return 0

    local ssh_test_cmd
    ssh_test_cmd="ssh -T '$ssh_host' </dev/null >/dev/null 2>&1"

    echo_step "TESTING SSH CONNECTION..."

    if ! run_or_dry_run $ssh_test_cmd; then
        echo "ERR: could not establish a connection with '$ssh_host'!" >&2
        return 1
    fi
}

function install_dep() {
    local idp_fname
    local local_dep_file
    local remote_dep_file
    local local_install_cmd
    local remote_copy_cmd
    local remote_install_cmd

    idp_fname="install-dep.sh"
    local_dep_file="${path_proj}/install/${idp_fname}"
    remote_dep_file="/tmp/${idp_fname}"
    local_install_cmd="'$local_dep_file'"
    remote_copy_cmd="scp -p '$local_dep_file' '${ssh_host}:${remote_dep_file}' >/dev/null"
    remote_install_cmd="ssh '$ssh_host' '${remote_dep_file}'"

    if [ $install_deps_local = 1 ]; then
        echo_step "INSTALLING DEPENDENCIES ON LOCAL HOST..."
        run_or_dry_run $local_install_cmd
    fi

    if [ ! -z "$ssh_host" ] && [ $install_deps_remote = 1 ]; then
        echo_step "INSTALLING DEPENDENCIES ON REMOTE HOST..."
        run_or_dry_run $remote_copy_cmd
        run_or_dry_run $remote_install_cmd
    fi
}

(
    set -e

    optstring="DdrlEHhns:"

    # Optional arguments
    ssh_host=
    install_neither=1
    install_embedded=0
    install_host=0
    install_deps_local=1
    install_deps_remote=1
    dry_run=0

    # Required arguments (in order)
    dest_path=

    OPTERR=0

    # Separate optional from positional arguments, then parse them
    separate_args "$optstring" $(toshortopts "$@")
    parse_opt_args "$optstring" "${opt_args[@]}"
    parse_pos_args "${pos_args[@]}"

    path_proj="$(get_project_path "..")"
    path_embedded="$(realpath "${path_proj}/embedded")"
    path_host="$(realpath "${path_proj}/host")"

    test_ssh
    if [ "$install_deps_local" = 1 ] || [ "$install_deps_remote" = 1 ]; then
        install_dep
    fi

    # TODO: DRY RUN

    # Build rsync parameters putting includes first and excludes last
    include_rules=''

    # Directories to exclude
    for d in build bin .devcontainer .git .vscode old __pycache__ '*results*' \
        '*images*' '*tables*'; do
        include_rules+=" '--exclude=$d/**'"
    done
    include_rules+=" '--exclude=.gitignore'"

    # Exclude unwanted directories from this install
    # TODO: Bad solution, fix later?
    [ "$install_embedded" != 1 ] &&
        include_rules+=" '--exclude=embedded'"
    [ "$install_host" != 1 ] &&
        include_rules+=" '--exclude=host'"

    # Common flags for the installation command
    rsync_flags=" -aviz --delete --prune-empty-dirs"

    # Force SSH if --ssh/-s is used
    if [ ! -z "$ssh_host" ]; then
        rsync_flags+=" -e ssh"
        dest_path="${ssh_host}:${dest_path}"
    fi

    install_cmd="rsync ${rsync_flags} ${include_rules} '${path_proj}' '$dest_path'"

    # Finally, print and run
    echo_step "INSTALLING..."
    # printf "%s\n\n%s\n\n" "About to run the following command:" "$install_cmd"
    run_or_dry_run $install_cmd
)
