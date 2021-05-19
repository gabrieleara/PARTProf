#!/bin/bash

function check_number() {
    re='^[0-9]+$'
    if ! [[ $1 =~ $re ]]; then
        echo "error: Not a number" >&2
        return 1
    fi

    if [ ! $1 -gt 0 ]; then
        echo "error: 0 is not admissible " >&2
}

check_number "$1" && export HOWMANY_TASKS="$1"
