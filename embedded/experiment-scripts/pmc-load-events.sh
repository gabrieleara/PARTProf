#!/bin/bash

tmpfile="/tmp/pmctrack_events$$.tmp"
listfile_final="/tmp/pmctrack_list_events$$.tmp"
listfile_current="/tmp/pmctrack_list_events_curr_$$.tmp"

pmc-events -L >"${tmpfile}"

function trim() {
    xargs
}

indexes=$(grep ${tmpfile} -n -e "\[" | cut -d':' -f1 | tr '\n' ' ' | trim)
num_indexes=$(echo "$indexes" | wc -w)

echo "" >"${listfile_final}"

for i in $(seq 2 $((num_indexes + 1))); do
    icurr=$((i - 1))

    line_start=$(echo "$indexes" | cut -d " " "-f$icurr")
    line_start=$((line_start + 1))
    if (("$i" > "$num_indexes")); then
        line_end=$(wc -l <"${tmpfile}")
        line_end=$((line_end + 1))
    else
        line_end=$(echo "$indexes" | cut -d " " "-f$i")
    fi

    difference=$((line_end - line_start))

    tail -n "+${line_start}" <"${tmpfile}" | head "-${difference}" | sort >"${listfile_current}"

    if [ "$(wc -w <"${listfile_final}")" = "0" ]; then
        cp ${listfile_current} ${listfile_final}
    else
        comm -1 -2 ${listfile_current} ${listfile_final} >${listfile_final}.tmp
        mv -f ${listfile_final}.tmp ${listfile_final}
    fi
done

# Print these somewhere to keep
cat ${listfile_final}

# Cleanup
rm -f ${listfile_final} ${listfile_current} ${listfile_final}.tmp ${tmpfile}
