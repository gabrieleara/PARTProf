#!/bin/bash

# Experiment base output directory
export EXP_BASE_DIR="./results"

# Experiment title
export EXP_TITLE="Power + Time"

# Experiment description
export EXP_DESCRIPTION="This experiment runs a set of tasks multiple times for each policy and each frequency"

# Number of seconds for which a single task run should roughly execute at least
# (when running on the fastest core at the fastest frequency)
export EXP_TASK_MIN_DURATION=4

# Number of seconds for which each single test (comprising potentially multiple
# task runs) should roughly execute at least.
# Absolute value, invariant to frequency
export EXP_TEST_DURATION=40

# Cooldown period between consecutive test tries
export EXP_SLEEP_INTERVAL=40

#==============================================================================#
# ------------------ TYPICAL COUNTERS AVAILABLE ON ARM CPUs ------------------ #
#==============================================================================#

# NOTE: some of these counters may be fixed! For example, on the Odroid-XU4, of
# the 7 hardware counters on the big CPU at least one must always refer to the
# "cycles" counter.

# The convenience in this is that the hardware events are exactly 7, so we can
# profile them all.

# branch-instructions OR branches                    [Hardware event]
# branch-misses                                      [Hardware event]
# bus-cycles                                         [Hardware event]
# cache-misses                                       [Hardware event]
# cache-references                                   [Hardware event]
# cpu-cycles OR cycles                               [Hardware event]
# instructions                                       [Hardware event]
# L1-dcache-load-misses                              [Hardware cache event]
# L1-dcache-loads                                    [Hardware cache event]
# L1-dcache-store-misses                             [Hardware cache event]
# L1-dcache-stores                                   [Hardware cache event]
# L1-icache-load-misses                              [Hardware cache event]
# L1-icache-loads                                    [Hardware cache event]
# LLC-load-misses                                    [Hardware cache event]
# LLC-loads                                          [Hardware cache event]
# LLC-store-misses                                   [Hardware cache event]
# LLC-stores                                         [Hardware cache event]
# branch-load-misses                                 [Hardware cache event]
# branch-loads                                       [Hardware cache event]
# dTLB-load-misses                                   [Hardware cache event]
# dTLB-store-misses                                  [Hardware cache event]
# iTLB-load-misses                                   [Hardware cache event]
# rNNN                                               [Raw hardware event descriptor]
# cpu/t1=v1[,t2=v2,t3 ...]/modifier                  [Raw hardware event descriptor]
# mem:<addr>[/len][:access]                          [Hardware breakpoint]

# The command to execute to measure elapsed time
export TIME_CMD="${APPSDIR}/forever/forever perf stat -x, -I 1000 -e branches,branch-misses,bus-cycles,cache-misses,cache-references,cycles,instructions -- "

# This command is used to make a single dry run of the application if needed
# (see run.sh script for more details)
export TIME_CMD_DRY="/usr/bin/time perf stat -x, -I 1000 -e branches,branch-misses,bus-cycles,cache-misses,cache-references,cycles,instructions -- "
export TIME=$'\ntime %e\n'

# The command to execute to measure the power consumption
export POWERSAMPLER_CMD="${APPSDIR}/sampler/sampler"

# The number of repetitions to run for each test
export HOWMANY_TIMES=10

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

# This parameter is used to set the RT priority of the task if HIGH_PRIO_KIND="fifo"
export FIFO_PRIORITY=10

# These parameters are used if HIGH_PRIO_KIND="deadline", wrapping each task
# inside a reservation with the following characteristics:
#   DEADLINE_PERIOD     [in nanoseconds] is the period of the reservation (also equal to its deadline);
#   DEADLINE_RUNTIME    [in nanoseconds] is the runtime of the reservation.
#
export DEADLINE_PERIOD=10000000000 # In nanoseconds
export DEADLINE_RUNTIME=4000000000 # In nanoseconds

# Base names of the two files that will be outputed, for time and power
# measurements respectively
export FILENAME_OUT_TIME="measure_time.txt"
export FILENAME_OUT_POWER="measure_power.txt"

# Reset lists of forced policies
export EXP_FREQ_FORCED_LIST=()
export EXP_POLICY_FORCED_LIST=()
