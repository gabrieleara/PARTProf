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

(
    set -e

    SCRIPT_PATH="$(get_script_path)"
    confdir="${SCRIPT_PATH}/../confdir"
    run_multi="${SCRIPT_PATH}/run-multi.sh"

    . "${SCRIPT_PATH}/email.sh"

    # Time and Power Experiments are implemented together
    # (forwarding optional arguments)
    if "${run_multi}" "${confdir}/conf-timepower.bash" 4 "$@"; then
        # send_update_email gabriele.ara@live.it treebeardretis@yandex.com \
        #     "Time and Power"
        :
    else
        # send_error_email gabriele.ara@live.it treebeardretis@yandex.com \
        #     "Time and Power"
        :
    fi

    # # PMC Experiments
    # # TODO: These experiments are disabled for now
    # run_pmc="${SCRIPT_PATH}/run-pmc.sh"
    # if "${run_pmc}" "$@"; then
    #     # send_update_email gabriele.ara@live.it treebeardretis@yandex.com \
    #     #     "PMC"
    #     :
    # else
    #     # send_error_email gabriele.ara@live.it treebeardretis@yandex.com \
    #     #     "PMC"
    #     :
    # fi
)
