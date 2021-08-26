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

function get_max_cpus() {
    local max_cpus=0
    local policy=
    local cpus=()

    for policy in $(cpufreq_policy_list); do
        cpus=($(cpufreq_policy_cpu_list "$policy"))

        if [ "${#cpus[@]}" -gt $max_cpus ]; then
            max_cpus="${#cpus[@]}"
        fi
    done

    echo "$max_cpus"
}

function sweep() {
    local max_cpus=
    local i=

    max_cpus=$(get_max_cpus)

    for ((i = 1; i <= max_cpus; i += 1)); do
        time "${RUN_CMD}" \
            "${CONF_PATH}/base/timeperfpower.sh" \
            "${CONF_PATH}/tasks/simple.sh" \
            "${CONF_PATH}/howmany_tasks/${i}.sh" \
            "${CONF_PATH}/freqs-only-in-list.sh" \
            "${CONF_PATH}/policies-only-in-list.sh" \
            "$@"
    done
}


function hostname_waddress() {
    echo "$(hostname) ($(hostname -I | cut -d' ' -f1))"
}

(
    set -e

    PROJPATH="$(get_project_path '../..')"
    SCRIPT_PATH="$(get_script_path)"
    CONF_PATH="${SCRIPT_PATH}/../confdir"
    RUN_CMD="${SCRIPT_PATH}/run.sh"

    . "${SCRIPT_PATH}/util/output.sh"
    . "${SCRIPT_PATH}/util/cpufreq.sh"

    sweep "$@"

    . "${SCRIPT_PATH}/util/telegram-tokens.sh" 2>/dev/null || true
    . "${SCRIPT_PATH}/util/telegram.sh"

    telegram_notify "Sweep experiment on $(hostname_waddress) terminated!"
)
