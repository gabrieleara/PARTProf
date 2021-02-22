#!/bin/bash

# Experiment base output directory
export EXP_BASE_DIR="./results-pmc"

# Experiment title
export EXP_TITLE="PMC Measurement"

# Number of seconds for which a single task run should roughly execute at least
# (when running on the fastest core at the fastest frequency)
export EXP_TASK_MIN_DURATION=2

# Number of seconds for which each single test (comprising potentially multiple
# task runs) should roughly execute at least.
# Absolute value, invariant to frequency
export EXP_TEST_DURATION=20

# Cooldown period between consecutive test tries
export EXP_SLEEP_INTERVAL=10

# The command to execute to measure elapsed time
export TIME_CMD="pmctrack -o /dev/stderr -T 0.1 -c ${PMC_CURRENT_EVENTS}"

# This command is used to make a single dry run of the application if needed
# (see run.sh script for more details)
export TIME_CMD_DRY="/usr/bin/time"
export TIME=$'\ntime %e\n'

# The command to execute to measure the power consumption
export POWERSAMPLER_CMD=""

# The number of repetitions to run for each test
export HOWMANY_TIMES=5

# The number of instances to run in parallel on the same policy
# (at most one per cpu, may be less than this number if the number of cpus is
# not enough)
export HOWMANY_TASKS=1

# This variable determines what kind of command will be used to start the test tasks
# with a high priority:
# - nice        ->  "nice -n -20"
# - fifo        ->  "chrt -f $FIFO_PRIORITY"
# - deadline    ->  "chrt -P $DEADLINE_PERIOD -T $DEADLINE_RUNTIME -d 0"
export HIGH_PRIO_KIND="nice"

# Base names of the two files that will be outputed, for time and power
# measurements respectively
export FILENAME_OUT_TIME="measure_pmc_${PMC_CURRENT_EXP_INDEX}"
export FILENAME_OUT_POWER=""
