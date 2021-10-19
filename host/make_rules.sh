#!/bin/bash

function is_zero_repetition() {
    [[ "$1" =~ "/0/" ]]
}

function print_all_matching_no_zero() {
    # NOTE: printing absolute paths is a must!
    for f in $(find "$(realpath "$1")" "${@:2}"); do
        if is_zero_repetition "$f" ; then
            continue
        fi
        echo "$f"
    done
}

function print_files_samples_perf() {
    print_all_matching_no_zero "$1" -name 'measure_time.txt*'
}

function print_files_samples_power() {
    print_all_matching_no_zero "$1" -name 'measure_power.txt'
}

function sample2table_perf() {
    sed 's#measure_time\.txt\(\d+\)#perf_table.\1.csv#' "$@"
}

function sample2table_power() {
    sed 's#measure_power\.txt#table_power.csv#' "$@"
}

(
    set -e

    # Arguments:
    # - 1  the name of the base directory.
    # - 2+ the mapping of the cores as required by the power_tables_collect.py

    # Process arguments
    base_path="$1"

    files_samples_perf=$(mktemp)
    files_samples_power=$(mktemp)
    files_tables_perf=$(mktemp)
    files_tables_power=$(mktemp)

    print_files_samples_perf    "$base_path"        >"${files_samples_perf}"
    print_files_samples_power   "$base_path"        >"${files_samples_power}"
    sample2table_perf   "${files_samples_perf}"     >"${files_tables_perf}"
    sample2table_power  "${files_samples_power}"    >"${files_tables_power}"

    # Printing the actual rules on the final Makefile

    # The collapsed table for perf has all perf tables as dependencies
    echo 'collapsed_table_perf.csv: ' \
        "$(cat "${files_tables_perf}" | tr '\n' ' ')" \
        ''
    echo -e '\t' 'time_tables_collect.py -o $@ $^'
    echo ''

    # The collapsed table for power domain has all power tables as dependencies
    echo 'collapsed_table_power.csv: ' \
        "$(cat "${files_tables_power}" | tr '\n' ' ')" \
        ''
    echo -e '\t' 'power_tables_collect.py -o $@ $^' "${@:2}"
    echo ''

    # Also the "megadb" thermal table has all power tables as dependencies
    echo 'th_megadb.csv: ' \
        "$(cat "${files_tables_power}" | tr '\n' ' ')" \
        ''
    echo -e '\t' 'power_tables_to_megadb.py -o $@ $^' "${@:2}"
    echo ''

    rm -f "${files_samples_perf}"
    rm -f "${files_samples_power}"
    rm -f "${files_tables_perf}"
    rm -f "${files_tables_power}"
)
