#!/bin/bash

results_dir="$1"
out_dir="tables/"
out_dir=${out_dir%/}

infiles=$(find "$results_dir" -name outdata.csv)

for f in $infiles ; do
    dirname=$(basename $(realpath $(dirname "$f")))
    tname="$dirname/table.csv"

    # First produce the collapsed table
    ./host/pyscripts/collapse.py "$f" -o "${out_dir}/${tname}"

    # Then expand it to the new smaller tables
    ./host/pyscripts/prepare_tables.py "${out_dir}/${tname}" -o "${out_dir}/${dirname}"
done
