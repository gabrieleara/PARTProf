#!/bin/bash

# Suppose pmctrack is installed in home directory

cd ~/pmctrack-1.5 &>/dev/null || (
    echo "Couldn't find pmctrack directory in $HOME"
    return
)
# Initialize pmctrack
. shrc
cd - &>/dev/null || return

# Select second option, then deny automatically if asked to reaload the module
# (i.e. if already loaded)
cat >/tmp/load-module-input.txt <<EOF
2
n
EOF
pmctrack-manager load-module </tmp/load-module-input.txt >/dev/null
rm -f /tmp/load-module-input.txt

# TODO: the module can also be used to measure power consumption using the
# ODROID Power Meter, useful maybe in the future!
