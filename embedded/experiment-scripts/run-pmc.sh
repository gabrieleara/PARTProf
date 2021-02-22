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

function trim() {
    # Cool bash trick: xargs can trim strings
    xargs
}

(
    set -e

    SCRIPT_PATH="$(get_script_path)"
    confdir="${SCRIPT_PATH}/../confdir"
    run="${SCRIPT_PATH}/run.sh"

    . "${SCRIPT_PATH}/email.sh"

    # Initialize pmctrack
    . "${SCRIPT_PATH}/pmc-init.bash"

    # Load the list of values we want to track:
    eventslist=$("${SCRIPT_PATH}/pmc-load-events.bash")
    eventsnum=$(echo "${eventslist}" | wc -w)

    # Get the max number of simultaneous counters supported
    # by all core types
    counters_per_cpu=$(pmc-events -I | grep -e "nr_gp_pmcs=" | cut -d'=' -f2)
    counters_common=1000
    for c in ${counters_per_cpu}; do
        if (("$c" < "$counters_common")); then
            counters_common="$c"
        fi
    done

    # I now have the list of events and the number of
    # counters that can be used at the same time. I can
    # iterate over the list by groups of size
    # counters_common

    # Total number of iterations
    iterations=$((eventsnum / counters_common))

    if [ $((iterations * counters_common)) != "$eventsnum" ]; then
        iterations=$((iterations + 1))
    fi

    # Run experiments multiple times, each time changing the included counters
    for ((i = 1; i <= "${iterations}"; i++)); do
        start_index=$(((i - 1) * counters_common + 1))

        # List of events to be used in this iteration
        PMC_CURRENT_EVENTS=$(echo "${eventslist}" | tr ' ' '\n' |
            tail -n "+${start_index}" | head "-${counters_common}" |
            tr '\n' ' ' | trim | tr ' ' ',')
        PMC_CURRENT_EXP_INDEX="$i"

        export PMC_CURRENT_EVENTS
        export PMC_CURRENT_EXP_INDEX

        echo "++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo "+       WILL RUN FOLLOWING SET OF EVENTS:"
        echo "+   PMC_CURRENT_EVENTS=$PMC_CURRENT_EVENTS"
        echo "+   PMC_CURRENT_EXP_INDEX=$PMC_CURRENT_EXP_INDEX"
        echo "++++++++++++++++++++++++++++++++++++++++++++++++++"
        echo ""

        # Now run the experiments for each of the cpus with all configurations
        "${run}" "${confdir}/conf-pmc.bash" "${confdir}/howmany_1.bash" "$@"

        # send_update_email gabriele.ara@live.it treebeardretis@yandex.com \
        #     "PMC Test ${i}/${iterations}"
    done
)
