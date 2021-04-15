#!/bin/bash

(
    function progress() {
        echo "--> $1:" "${@:2}"
    }

    function progress_done() {
        echo "--> $1:" "DONE!"
    }


    set -e

    results_dir="$1"
    out_dir="tables/"
    out_dir=${out_dir%/}

    infiles=$(find "$results_dir" -name outdata.csv)

    # 'single', 'average', 'maximum'
    time_method='single'

    # 'single', 'true_regression', 'fixed_regression'
    power_method='fixed_regression'

    error_tasks=("decrypt" "encrypt" "gzip-1" "gzip-5" "gzip-9" "hash" )

    list_of_error_files=()

    for f in $infiles ; do
        dirname=$(basename "$(realpath "$(dirname "$f")")")
        collapsed="$dirname/collapsed.csv"
        simtable="$dirname/simtable.csv"
        simulation="$dirname/simulation.csv"
        errors="$dirname/simulation_errors.csv"

        # First produce the collapsed table
        progress "$dirname" "COLLAPSING DATA..."
        ./host/pyscripts/collapse.py                        \
            "$f"                                            \
            -o "${out_dir}/${collapsed}"
        progress_done "$dirname"

        # # Expand to other smaller tables (for plotting purposes only)
        # progress "$dirname" "EXPANDING DATA INTO SMALLER TABLES..."
        # ./host/pyscripts/prepare_tables.py                  \
        #     "${out_dir}/${collapsed}"                       \
        #     -o "${out_dir}/${dirname}"
        # progress_done "$dirname"

        # Calculate the actual simulation table from the collapsed one
        # THIS IS THE TABLE THAT WILL BE USED BY RTSIM
        progress "$dirname" "PRODUCING SIMULATION TABLE..."
        ./host/pyscripts/simtable.py                        \
            "${out_dir}/${collapsed}"                       \
            -p "${power_method}" -t "${time_method}"        \
            -o "${out_dir}/${simtable}"
        progress_done "$dirname"

        # Emulate RTSim by simulating homogeneous task executions in Python
        # TODO: add custom table for island-numcores association
        progress "$dirname" "USING SIMTABLE TO SIMULATE..."
        ./host/pyscripts/simulate.py                        \
            "${out_dir}/${simtable}"                        \
            -o "${out_dir}/${simulation}"
        progress_done "$dirname"

        # Calculate errors
        progress "$dirname" "CALCULATING SIMULATION ACCURACY..."
        ./host/pyscripts/errors.py                          \
            "${out_dir}/${collapsed}"                       \
            "${out_dir}/${simulation}"                      \
            -o "${out_dir}/${errors}"
        progress_done "$dirname"

        list_of_error_files+=( "${out_dir}/${errors}" )
    done

    ./host/pyscripts/describe_all_errors.py "${list_of_error_files[@]}" -t "${error_tasks[@]}"
)
