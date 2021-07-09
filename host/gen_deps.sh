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

function find_uniq_depth() {
    local depth="$1"

    find . -maxdepth "$depth" ! -path . -type d | cut -d/ -f $((depth + 1)) | sort | uniq
}

function find_all_runs() {
    local cur_path="$1"
    local depth="$2"

    # Find all numbered subdirs with index greater than 0

    find "${cur_path}" -type d -regextype sed -regex '.\+/[0-9]\+' |
        cut -d/ -f "${depth}" |
        awk '($1 > 0){ print $1 }'
}

function find_all_deps() {
    local cur_path="$1"

    # Power
    find "${cur_path}" -type f -name 'measure_power.txt' |
        grep -v '/0/' |
        sed -e 's#\(.\+\)/measure_power.txt#\1/raw_measure_power.csv#'

    # For time, there may be multiple files now
    find "${cur_path}" -type f -name 'measure_time.txt*' |
        grep -v '/0/' |
        sed -e 's#\(.\+\)/measure_time.txt\(.*\)#\1/raw_measure_time\2.csv#'

}

(
    set -e

    # Wants the name of a directory where to look files into as argument

    base_path="$1"
    cd "$base_path"

    howmanies="$(find_uniq_depth 1)"
    policies="$(find_uniq_depth 2)"
    freqs="$(find_uniq_depth 3)"
    tasks="$(find_uniq_depth 4)"

    all_stats_files_fname=$(mktemp)
    all_samples_files_fname=$(mktemp)

    for a in ${howmanies}; do
        for b in ${policies}; do
            for c in ${freqs}; do
                for d in ${tasks}; do
                    cur_path="$a/$b/$c/$d"
                    if [ ! -d "$cur_path" ]; then continue; fi

                    deps=$(find_all_deps ${cur_path})
                    cur_file="${cur_path}/stats.csv"

                    echo "${cur_file}" >> "${all_stats_files_fname}"
                    echo "${deps}" >> "${all_samples_files_fname}"

                    # TODO: change
                    # echo "all: ${cur_file}"
                    # echo ""

                    echo -n "${cur_file}: "

                    for dep in ${deps}; do
                        echo -n "${dep} "
                    done
                    echo ''

                    echo -e '\t' 'raw_csv_to_stats.py -o $@ $^'
                    echo ''
                done
            done
        done
    done

    # Generate rule for the outdata file

    echo -n 'outdata.csv: '
    tr '\n' ' ' < "${all_stats_files_fname}"
    echo '' # tr removes also the last newline, so I have to add it manually
    echo -e '\t' 'collect_stats.py -o $@ $^'
    echo ''

    echo -n 'allsamples.csv: '
    tr '\n' ' ' < "${all_samples_files_fname}"
    echo '' # tr removes also the last newline, so I have to add it manually
    echo -e '\t' 'collect_samples.py -o $@ $^'
    echo ''

    rm "${all_stats_files_fname}"
)
