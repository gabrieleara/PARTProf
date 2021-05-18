#!/bin/bash

# -------------------------------------------------------- #

function jump_and_print_path() {
    cd -P "$(dirname "$_SOURCE")" >/dev/null 2>&1 && pwd
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
    _PROJPATH=$(jump_and_print_path "${_PATH}/$1")

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
  -s, --ssh HOSTNAME
                    A valid location to ssh into. You may be prompted one or
                    multiple times for credentials during the process.
  -E, --install-embedded
                    Enables the installation of the embedded component.
                    See Notes.
  -H, --install-host
                    Enables the installation of the host component. See Notes.

Notes:
    If neither '-E' nor '-H' options are provided, it is equivalent as providing
    both (because installing no component makes little sense).
EOF
}

opt_args=()
pos_args=()

function toshortopts() {
    while [ $# -gt 0 ]; do
        # if ! [[ "$1" == "--*" ]]; then
        #     echo -E "$1"
        #     shift
        #     continue
        # fi

        case "$1" in
        --install-deps)
            printf ' %s' "-D"
            ;;
        --dont-install-deps)
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
            echo "DBG: OPTION: $OPTION"
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

        echo "DBG: AAAARGS  $@"
        shift $((OPTIND - 1)) || true
        echo "DBG: AAAARGS2 $@"
        pos_args+=($1)
        echo "DBG: POSARGS $pos_args"
        shift || true
        echo "DBG: AAAARGS3 $@"
    done
}

function parse_opt_args() {
    local optstring="$1"
    local OPTION
    shift

    unset OPTIND
    unset OPTARG
    unset OPTION
    echo "DBG: ARGS $@"
    while getopts "$optstring" OPTION; do
        echo "DBG: " $OPTION
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
            usage >/dev/stderr
            return 1
            ;;
        D)
            install_deps=1
            ;;
        d)
            install_deps=0
            ;;
        s)
            if [ -z "$OPTARG" ]; then
                usage >/dev/stderr
                return 1
            fi
            ssh_host="$OPTARG"
            ;;
        *)
            usage >/dev/stderr
            return 1
            ;;
        esac
        unset OPTARG
    done

    # Too many options/unrecognized options
    shift $((OPTIND - 1)) || true
    if [ "$#" -gt 0 ]; then
        usage >/dev/stderr
        return 1
    fi

    if [ "$install_neither" = 1 ]; then
        echo "NEITHER!"
        install_embedded=1
        install_host=1
    fi
}

function parse_pos_args() {
    dest_path="${pos_args[0]}"
    if [ -z "$dest_path" ]; then
        usage >/dev/stderr
        return 1
    fi
}

# function check_prog_args() {
#     if [ $# -lt 1 ]; then
#         echo "Please provide a valid ssh host as first argument!" \
#             >/dev/stderr
#         return 1
#     fi

#     if [ $# -lt 2 ]; then
#         echo "Please provide a valid destination for rsync as first argument!" \
#             >/dev/stderr
#         return 1
#     fi

#     # TODO: check whether argument is an okay path
# }

# Builds arguments for the rsync command
#
# Usage: addparam <include/exclude> args...
#
# Arguments:
#  1. <include/exclude>     indicates what to do with following args (only 1)
#  2. args...               list of directories (with subdirectories)
function addparam() {
    include_rules=""
    for p in "${@:2}"; do
        include_rules+=" --$1='${p}/**'"
    done
    echo "$include_rules"
}

function test_ssh() {
    [ -z "$ssh_host" ] && return 0

    if ! ssh -T "$ssh_host" </dev/null >/dev/null 2>&1 ; then
        echo "ERR: could not establish a connection with '$ssh_host'!" \
            >/dev/stderr
        return 1
    fi
}

function install_dep() {
    idp_fname="install-dep.sh"
    install_dep_file="$(realpath "$path_proj")/install/${idp_fname}"

    echo ">> INSTALLING LOCAL DEPENDENCIES..."
    "$install_dep_file"

    if [ ! -z "$ssh_host" ] ; then
        echo ">> INSTALLING REMOTE DEPENDENCIES..."
        scp -p "$install_dep_file" "${ssh_host}:/tmp/${idp_fname}"
        ssh "$ssh_host" '/tmp/${idp_fname}'
    fi
}

(
    set -e
    # set -x

    optstring="DdEHhs:"

    # Optional arguments
    ssh_host=
    install_neither=1
    install_embedded=0
    install_host=0
    install_deps=1

    # Required arguments (in order)
    dest_path=

    OPTERR=0

    echo "DBG: ALL " $(toshortopts "$@")
    echo "DBG: TOSHORT " $(toshortopts "$@")

    # Separate optional from positional arguments, then parse them
    separate_args "$optstring" $(toshortopts "$@")
    parse_opt_args "$optstring" "${opt_args[@]}"
    parse_pos_args "${pos_args[@]}"

    path_proj="$(get_project_path "..")"
    path_embedded="$(realpath "${path_proj}/embedded")"
    path_host="$(realpath "${path_proj}/host")"

    test_ssh
    [ "$install_deps" = 1 ] && install_dep

    # TODO: DRY RUN

    # Build rsync parameters putting includes first and excludes last
    include_rules=''
    # include_rules+=" '--include=*/'"

    # # Directories to exclude
    for d in build bin .devcontainer .git .vscode '*results' tables; do
        include_rules+=" '--exclude=$d/**'"
    done
    include_rules+=" '--exclude=.gitignore'"

    # LIST_OF_DIRECTORIES_TO_EXCLUDE=(build bin obj 'post-processing*' .git)
    # for d in ${LIST_OF_DIRECTORIES_TO_EXCLUDE[@]}; do
    #     include_rules+=" --exclude=$d"
    # done

    # LIST_OF_DIRECTORIES_TO_INCLUDE=()
    # include_rules+=$(addparam include "${LIST_OF_DIRECTORIES_TO_INCLUDE[@]}")

    # # Directories to include
    # include_rules+=" '--include=$path_proj'"
    # include_rules+=" '--include=$path_proj/install'"

    # DOES NOT WORK MAREMMA MAIALA
    echo "$install_embedded"
    echo "$install_host"
    [ "$install_embedded" != 1 ] && \
        include_rules+=" '--exclude=$path_embedded'"
    [ "$install_host"     != 1 ] && \
        include_rules+=" '--exclude=$path_host'"

    # Rule to exclude everything
    # include_rules+=" '--exclude=*'"
    #include_rules+=" '--exclude=*'"

    # Build installation command
    rsync_flags=" -aviz --delete --prune-empty-dirs"
    rsync_flags+=" -n "

    if [ ! -z "$ssh_host" ]; then
        rsync_flags+=" -e ssh"
        dest_path="${ssh_host}:${dest_path}"
    fi

    command="rsync ${rsync_flags} ${include_rules} '${path_proj}' '$dest_path'"

    # Necessary not to mess with the quotes and everything
    echo ">> INSTALLING USING: ${command}"
    bash -c "${command}"

# # Build parameters from list, first the generic */ include rule,
# # then specific exclude directories,
# # then include directories,
# # and finally the *.
# # Notice that order matters!
# include_rules=''
# include_rules+=" --include='*/'"
#
# include_rules+=$(addparam include "${LIST_OF_DIRECTORIES_TO_INCLUDE[@]}")
# include_rules+=" --exclude='*'"











)

# LIST_OF_DIRECTORIES_TO_INCLUDE=(apps script)
# LIST_OF_DIRECTORIES_TO_EXCLUDE=(bin obj 'post-processing*' .git)
# DESTINATION="$1"

# # Build parameters from list, first the generic */ include rule,
# # then specific exclude directories,
# # then include directories,
# # and finally the *.
# # Notice that order matters!
# include_rules=''
# include_rules+=" --include='*/'"
# include_rules+=$(addparam exclude "${LIST_OF_DIRECTORIES_TO_EXCLUDE[@]}")
# include_rules+=$(addparam include "${LIST_OF_DIRECTORIES_TO_INCLUDE[@]}")
# include_rules+=" --exclude='*'"

# if [ -z "$DESTINATION" ]; then
#     echo "Missing destination (remote) directory argument!"
#     exit 1
# fi

# echo "DESTINATION: $DESTINATION"

# # Building installation command
# command="rsync -avzi -e ssh --delete --prune-empty-dirs $include_rules ${_PROJECTPATH} ${DESTINATION}"

# echo "Executing installation command:"
# echo "--> $command"

# # MUST USE BASH BECAUSE OTHERWISE IT MESSES UP WITH THE QUOTES IN PARAMETERS
# # If command 'rsync' not found on destination, please install 'rsync' on destination first!"
# bash -c "${command}"
