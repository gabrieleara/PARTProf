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
    function progress() {
        echo "--> $1:" "${@:2}"
    }

    function progress_done() {
        echo "--> $1:" "DONE!"
    }

    set -e
    export XDG_RUNTIME_DIR=/tmp/fakexdgruntime
    export RUNLEVEL=3

    mkdir -p "$XDG_RUNTIME_DIR"

    PROJ_PATH=$(get_project_path "..")
    HOST_PATH="$PROJ_PATH/host"
    PYSCRIPTS_PATH="$HOST_PATH/pyscripts"

    python3 -m compileall "${PYSCRIPTS_PATH}"/* >/dev/null

    # Argument: results dir, out_dir
    results_dir="$PROJ_PATH/results"
    out_dir="$PROJ_PATH/tables"

    if [ $# -gt 0 ]; then
        results_dir="$1"
    fi
    if [ $# -gt 1 ]; then
        out_dir="$2"
    fi

    results_dir=${results_dir%/}
    out_dir=${out_dir%/}

    infiles=$(find "$results_dir" -name outdata.csv)

    # 'single', 'average', 'maximum'
    time_method='single'

    # 'single', 'true_regression', 'fixed_regression'
    power_method='fixed_regression'

    error_tasks=("decrypt" "encrypt" "gzip" "gzip-1" "gzip-5" "gzip-9" "hash" "idle")

    list_of_error_files=()

    for f in $infiles; do
        dirname=$(basename "$(realpath "$(dirname "$f")")")
        collapsed="$dirname/collapsed.csv"
        simtable="$dirname/simtable.csv"
        simulation="$dirname/simulation.csv"
        errors="$dirname/simulation_errors.csv"

        # First produce the collapsed table
        progress "$dirname" "COLLAPSING DATA..."
        "${PYSCRIPTS_PATH}"/collapse.py \
            "$f" \
            -o "${out_dir}/${collapsed}" \
            -c "${out_dir}/${collapsed}.corr"
        progress_done "$dirname"

        # Expand to other smaller tables (for plotting purposes only)
        progress "$dirname" "EXPANDING DATA INTO SMALLER TABLES..."
        "${PYSCRIPTS_PATH}"/prepare_tables.py \
            "${out_dir}/${collapsed}" \
            -o "${out_dir}/${dirname}"
        progress_done "$dirname"

        # Plot all kinds of values, first for each number of concurrent tasks...
        progress "$dirname" "PLOTTING THE EXPANDED TABLES (takes a while)..."
        for howmany in "${out_dir}/${dirname}/howmany"*; do
            if [ ! -d "$howmany" ]; then continue; fi
            for island in "${howmany}/island"*; do
                if [ ! -d "$island" ]; then continue; fi
                # Execution time
                "${PYSCRIPTS_PATH}"/plotstuff.py \
                    "${island}"/task_* \
                    -x frequency \
                    -y time_rel \
                    -X 'Frequency [Hz]' \
                    -Y 'Relative Execution Time' \
                    -o "${island}"/time \
                    -O .png \
                    -O .pdf

                # Power consumption
                "${PYSCRIPTS_PATH}"/plotstuff.py \
                    "${island}"/task_* \
                    -x frequency \
                    -y power_mean \
                    -X 'Frequency [Hz]' \
                    -Y 'Power Consumption [µW]' \
                    -o "${island}"/power \
                    -O .png \
                    -O .pdf
            done
        done

        # ... Then for scalability
        for island in "${out_dir}/${dirname}/MULTI/island"*; do
            if [ ! -d "$island" ]; then continue; fi
            for freq in "${island}/freq_"*; do
                if [ ! -d "$freq" ]; then continue; fi
                # Execution time
                "${PYSCRIPTS_PATH}"/plotstuff.py \
                    "${freq}"/task_* \
                    -x howmany \
                    -y time_rel \
                    -X 'Number of concurrent tasks' \
                    -Y 'Relative Execution Time' \
                    -o "${freq}"/time \
                    -O .png \
                    -O .pdf

                # Power consumption
                "${PYSCRIPTS_PATH}"/plotstuff.py \
                    "${freq}"/task_* \
                    -x howmany \
                    -y time_rel \
                    -X 'Number of concurrent tasks' \
                    -Y 'Power Consumption [µW]' \
                    -o "${freq}"/power \
                    -O .png \
                    -O .pdf
            done
        done
        progress_done "$dirname"

        # Calculate the actual simulation table from the collapsed one
        # THIS IS THE TABLE THAT WILL BE USED BY RTSIM
        progress "$dirname" "PRODUCING SIMULATION TABLE..."
        "${PYSCRIPTS_PATH}"/simtable.py \
            "${out_dir}/${collapsed}" \
            -p "${power_method}" -t "${time_method}" \
            -o "${out_dir}/${simtable}"
        progress_done "$dirname"

        # Emulate RTSim by simulating homogeneous task executions in Python
        # TODO: add custom table for island-numcores association
        progress "$dirname" "USING SIMTABLE TO SIMULATE..."
        "${PYSCRIPTS_PATH}"/simulate.py \
            "${out_dir}/${simtable}" \
            -o "${out_dir}/${simulation}"
        progress_done "$dirname"

        # Calculate errors
        progress "$dirname" "CALCULATING SIMULATION ACCURACY..."
        "${PYSCRIPTS_PATH}"/errors.py \
            "${out_dir}/${collapsed}" \
            "${out_dir}/${simulation}" \
            -o "${out_dir}/${errors}"
        progress_done "$dirname"

        list_of_error_files+=("${out_dir}/${errors}")
    done

    "${PYSCRIPTS_PATH}"/describe_all_errors.py "${list_of_error_files[@]}" -t "${error_tasks[@]}"
)
