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
usage: $0 [options] [commands...]

The provided PATH is processed, all data is collected, stats are calculated and
output files are produced within the given path.

List of options (all commands):
  -h, --help        Prints this help message and returns with an error.
  -n, --dry-run     Prints out all commands but does not execute them.
  -j, --jobs      JOBS
                    The number of jobs to run simultaneously.
  -c, --col-file  FILE
                    The name of the file to use to remap columns when building.
                    By default, no renaming is used (not recommended).
  -C, --directory DIR
                    Uses the provided directory instead of the default one.
                    Default: ${default_results_dir}

List of commands:
  all               See build.
                    This is the default command if no command is provided.
  build             Produces all files processing the specified directory.
  touch-time        Forces any subsequent build command to re-process all time
                    log files.
  touch-power       Forces any subsequent build command to re-process all power
                    log files.
  touch             Forces any subsequent build command to re-process all files.
                    Same as providing both touch-time and touch-power.
  clean             Removes all intermediary and output files.

Notes:
    If multiple commands are provided, they will be executed in order.
EOF
}

opt_args=()
pos_args=()

function toshortopts() {
    while [ $# -gt 0 ]; do
        case "$1" in
        --help)
            printf ' %s' "-h"
            ;;
        --dry-run)
            printf ' %s' "-n"
            ;;
        --col-file)
            printf ' %s' "-c"
            ;;
        --directory)
            printf ' %s' "-C"
            ;;
        --jobs)
            printf ' %s' "-j"
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

# TODO: more checks

function parse_opt_args() {
    local optstring="$1"
    local OPTION
    shift

    unset OPTIND
    unset OPTARG
    unset OPTION
    while getopts "$optstring" OPTION; do
        case $OPTION in
        h)
            usage
            help_exit=1
            return
            ;;
        n)
            dry_run=1
            ;;
        j)
            use_jobs=1
            njobs="$OPTARG"
            ;;
        c)
            if [ -z "$OPTARG" ]; then
                printf 'ERR: option %s requires and argument!\n' \
                    "-c|--col-file" >&2
                usage
                false
            fi
            col_opt="$OPTARG"
            if [[ "$col_opt" != "/*" ]]; then
                col_opt="$(realpath $(pwd))/$col_opt"
            fi
            ;;

        C)
            if [ -z "$OPTARG" ]; then
                usage
                false
            fi
            results_dir="$OPTARG"
            ;;
        *)
            printf "ERR: unrecognized option '-%s'.\n\n" "$OPTION" >&2
            usage
            false
            ;;
        esac
        unset OPTARG
    done

    # Too many options/unrecognized options
    shift $((OPTIND - 1)) || true
    if [ "$#" -gt 0 ]; then
        printf "ERR: unrecognized options.\n\n" >&2
        usage
        false
    fi
}

function parse_pos_args() {
    if [ "${#pos_args[@]}" -lt 1 ]; then
        pos_args=('all')
    fi

    for cmd in ${pos_args[@]}; do
        if [[ ! " ${commands_list[@]} " =~ " ${cmd} " ]]; then
            printf "ERR: unrecognized command %s !\n" ${cmd} >&2
            usage
            false
        fi
    done
}

function build() {
    # Run this function for each directory in results dir
    # if [ ! -d "$d" ] || [ "$d" = "$results_dir/." ] ||
    #     [ "$d" = "$results_dir/.." ]; then
    #     continue
    # fi

    local cur_dir
    local deps_makefile
    local args
    local log_make_err
    local log_time
    local run_successful

    cur_dir="$results_dir"
    run_successful=0

    if [ ! -d "$cur_dir" ]; then
        printf 'ERR: argument %s is not a directory!\n' $cur_dir >&2
        false
    fi

    deps_makefile="$(mktemp)"
    log_make_err="$(mktemp)"
    log_time="$(mktemp)"

    printf ' --> Generating Dependencies for %s ...\n' "$cur_dir"
    "${path_host}/gen_deps.sh" "$cur_dir" >"${deps_makefile}"
    # cat "${deps_makefile}"

    args=" -r -C ${cur_dir} -f $base_makefile GENERATED_DEPS=$deps_makefile"

    if [ $dry_run = 1 ]; then
        args+=" --dry-run"
    fi

    if [ ! -z "$col_opt" ]; then
        args+=" col_opt=$col_opt"
    fi

    if [ $use_jobs = 1 ]; then
        args+=" -j $njobs"
    fi

    printf ' --> Beginning processing for %s ...\n' "$cur_dir"
    printf ' --> Running the following command:\n  %s\n' "make $args"

    {
        export PATH="${path_pyscripts}:${PATH}"
        time make $args 2>"$log_make_err" && run_successful=1
    } 2>"$log_time"

    cat $log_make_err >&2

    printf ' --> That took exactly'
    cat "$log_time"

    rm $log_time $log_make_err $deps_makefile

    if [ "$run_successful" = 1 ]; then
        printf ' --> Run successful!\n'
    else
        printf ' --> Run exited with error!\n' >&2
        false
    fi
}

function clean() {
    printf "ERR: Command %s not implemented yet!\n" 'clean' >&2
    false
}

function touch_s() {
    find "$results_dir" -name "$1" -exec touch {} \+
}

function touch_time() {
    touch_s 'measure_time.txt'
}

function touch_power() {
    touch_s 'measure_power.txt'
}

# Depends on: pandas (through python3-pip); use:
# sudo apt update && sudo apt install python3-pip -y && pip3 install pandas

(
    set -e

    path_proj="$(get_project_path "..")"
    path_embedded="$(realpath "${path_proj}/embedded")"
    path_host="$(realpath "${path_proj}/host")"
    path_pyscripts="${path_host}/pyscripts"

    optstring="hnj:c:C:"

    # Optional arguments
    dry_run=0
    use_jobs=0
    njobs=
    help_exit=
    default_results_dir="$path_proj/results"
    results_dir="$default_results_dir"

    commands_list=(
        all
        build
        clean
        touch
        touch-time
        touch-power
    )

    OPTERR=0

    # Separate optional from positional arguments, then parse them
    separate_args "$optstring" $(toshortopts "$@")
    parse_opt_args "$optstring" "${opt_args[@]}"

    if [ "$help_exit" != 1 ]; then
        parse_pos_args

        # Recompile scripts if needed
        python3 -m compileall "${path_pyscripts}/*" >/dev/null || true

        base_makefile="$path_host/base.makefile"

        for cmd in ${pos_args[@]}; do
            printf " -> Running command %s...\n" "$cmd"
            case $cmd in
            all | build) build ;;
            clean) clean ;;
            touch)
                touch_time
                touch_power
                ;;
            touch-time) touch_time ;;
            touch-power) touch_power ;;
            esac
        done
    fi

    #------------------------------------------------------#

    # # TODO: optional arguments to enable/disable parallelism
    # # and where to log outputs and errors

    # if [ $# -gt 0 ]; then
    #     results_dir="$1"
    # fi

    # # NOTE: next command is virtually equivalent to a clean
    # # find "$results_dir" -name measure_power.txt -exec touch {} \;
    # # find "$results_dir" -name measure_time.txt  -exec touch {} \;

    # # cpumask="0-$((nprocs - 1))"

    # deps_makefile_list=()

    # for d in "$results_dir/"*; do
    #     if [ ! -d "$d" ] || [ "$d" = "$results_dir/." ] ||
    #         [ "$d" = "$results_dir/.." ]; then
    #         continue
    #     fi

    #     deps_makefile="$(mktemp)"

    #     echo "GENERATING DEPENDENCIES FOR : $d"
    #     echo "..."
    #     "$HOST_PATH/gen_deps.sh" "$d" >>"${deps_makefile}"

    #     COL_OPT="$HOST_PATH/cmaps/raw_$(basename "$d").cmap"

    #     echo "STARTING GENERATION"
    #     time taskset -c "$cpumask" make -r -C "$d" -f "$MAKEFILE" \
    #         GENERATED_DEPS="${deps_makefile}" \
    #         col_opt="$COL_OPT" -j"${nprocs}"
    #     # >"$d.log" 2>"$d.error_log" &

    #     deps_makefile_list+=("${deps_makefile}")
    # done

    # wait

    # rm -f "${deps_makefile_list[@]}"
)
