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

(
    set -e

    SCRIPT_PATH="$(get_script_path)"
    confdir="${SCRIPT_PATH}/../confdir"
    run="${SCRIPT_PATH}/run.sh"

    # NOTICE: first argument MUST correspond to the path of
    # a valid test configuration file. Subsequent arguments
    # can link to additional configuration files (will be
    # executed in order).
    if [ "$#" -lt 1 ]; then
        echo "ERROR: MUST PROVIDE EXPERIMENT TYPE!" \
            >/dev/stderr
        false
    fi

    if [ "$#" -lt 2 ]; then
        echo "ERROR: MUST PROVIDE MAXIMUM NUMBER OF PARALLEL TASKS!" \
            >/dev/stderr
        false
    fi

    test_conf="$1"
    max_tasks="$2"

    for ((i = 1; i <= "${max_tasks}"; i++)); do
        "${run}" "${test_conf}" "${confdir}/howmany_${i}.bash" "${@:2}"
    done
)
