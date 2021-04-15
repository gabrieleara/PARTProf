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

# Depends on: pandas (through python3-pip); use:
# sudo apt update && sudo apt install python3-pip -y && pip3 install pandas

(
    set -e

    PROJ_PATH=$(get_project_path "..")
    HOST_PATH="$PROJ_PATH/host"
    PYSCRIPTS_PATH="$HOST_PATH/pyscripts"

    python3 -m compileall "${PYSCRIPTS_PATH}/*" >/dev/null

    # Arguments: [results-dir]
    results_dir=results

    # TODO: optional arguments to enable/disable parallelism
    # and where to log outputs and errors

    if [ $# -gt 1 ]; then
        results_dir="$1"
    else
        results_dir=$(realpath "$PROJ_PATH/$results_dir")
    fi

    export PATH="${PYSCRIPTS_PATH}:${PATH}"
    MAKEFILE="$HOST_PATH/base.makefile"

    # NOTE: next command is virtually equivalent to a clean
    # find "$results_dir" -name measure_power.txt -exec touch {} \;
    # find "$results_dir" -name measure_time.txt  -exec touch {} \;

    nprocs=$(nproc)
    nprocs=$((nprocs / 2))

    cpumask="0-$((nprocs-1))"

    deps_makefile_list=()

    for d in "$results_dir/"*; do
        if [ ! -d "$d" ] || [ "$d" = "$results_dir/." ] ||
            [ "$d" = "$results_dir/.." ]; then
            continue
        fi

        deps_makefile="$(mktemp)"

        echo "GENERATING DEPENDENCIES FOR : $d"
        echo "..."
        "$HOST_PATH/gen_deps.sh" "$d" >> "${deps_makefile}"

        COL_OPT="$HOST_PATH/cmaps/raw_$(basename "$d").cmap"

        echo "STARTING GENERATION"
        time taskset -c "$cpumask" make -r -C "$d" -f "$MAKEFILE" \
            GENERATED_DEPS="${deps_makefile}" \
            col_opt="$COL_OPT" -j"${nprocs}" \
        # >"$d.log" 2>"$d.error_log" &

        deps_makefile_list+=( "${deps_makefile}" )
    done

    wait

    rm -f "${deps_makefile_list[@]}"
)
