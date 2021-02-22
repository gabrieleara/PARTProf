#!/bin/bash

# Experiment base output directory
export EXP_BASE_DIR="./results-power"

# Experiment title
export EXP_TITLE="Power Measurement"


# Number of seconds for which a single task run should roughly execute at least
# (when running on the fastest core at the fastest frequency)
export EXP_TASK_MIN_DURATION=2

# The command to execute to measure elapsed time
export TIME_CMD="${APPSDIR}/forever/forever"

# This command is used to make a single dry run of the application if needed
# (see run.sh script for more details)
export TIME_CMD_DRY="/usr/bin/time"
export TIME=$'\ntime %e\n'

# The command to execute to measure the power consumption
export POWERSAMPLER_CMD="${APPSDIR}/sampler/sampler"

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
export FILENAME_OUT_TIME="measure_time"
export FILENAME_OUT_POWER="measure_power"
