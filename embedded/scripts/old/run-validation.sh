#!/bin/bash

# ============================================================================ #
#                                  Functions                                   #
# ============================================================================ #

# Find a policy different than the current one
# First argument must be the current policy
function policy_find_another() {
    local policy=$1

    for policy_other in $(cpufreq_policy_list | sort -n); do
        if [ "$policy_other" != "$policy" ]; then
            echo "$policy_other"
            return
        fi
    done

    echo "$policy"
}

# Save on the file given as argument the experiment metadata
# TODO: save more detailed metadata
function experiment_save_metadata() {
    cat >"$1" <<EOF
TITLE:                  ${EXP_TITLE}
DESCRIPTION:            ${EXP_DESCRIPTION}

BASE DIRECTORY:         $(pwd)
DATETIME:               $(date)
KERNEL INFO:            $(uname -a)
TASKS LIST:             ${TASKS_NAME[@]}
TASK MIN DURATION:      ${EXP_TASK_MIN_DURATION} seconds
SINGLE TEST DURATION:   ${EXP_TEST_DURATION} seconds
EOF

    if [ "$DEADLINE_USE" = "1" ]; then
        cat >>"$1" <<EOF

NOTE:   This experiment uses SCHED_DEADLINE with the following parameters
        PERIOD:     ${DEADLINE_PERIOD} ns
        RUNTIME:    ${DEADLINE_RUNTIME} ns
EOF
    fi
}

# Get the command to execute from the given command index and the number of
# the current task to be started
# Arguments:
#  1. command index
#  2. task index (depends on how many concurrent runs you launch)
function tasks_get_command_index() {
    task=${TASKS_CMD[$1]}
    echo "${task//fakedata\/fakedata/fakedata\/fakedata${2}}"
}

# Uses following env variables:
#  - policy
#  - freq
#  - task_name
function current_test_directory() {
    echo "policy_${policy}/freq_${freq}/task_${task_name}"
}

# Arguments:
#  1. current repetition
#  2. task index (depends on how many concurrent runs you launch)
function current_test_file_time() {
    local rep="$1"
    local count="$2"

    if [ -n "${FILENAME_OUT_TIME}" ]; then
        echo "$(current_test_directory)/${rep}/${FILENAME_OUT_TIME}_${count}.txt"
    else
        echo "$(current_test_directory)/${rep}/debug.txt"
    fi
}

# Arguments:
#  1. current repetition
function current_test_file_power() {
    local rep="$1"

    if [ -n "${FILENAME_OUT_POWER}" ]; then
        echo "$(current_test_directory)/${rep}/${FILENAME_OUT_POWER}_.txt"
    else
        echo "/dev/null"
    fi
}

function say() {
    (echo "$@" | festival --tts 2>/dev/null) || true
}

function printsay() {
    echo "$@"
    say "$@"
}

# Prints the command that should be used to run applications
# with "high priority"
# TODO: print these parameters in metadata?
# FIXME: SCHED_DEADLINE does not work for some task types
function get_prio_cmd() {
    case $HIGH_PRIO_KIND in
    nice)
        echo "nice -n -20" # Will receive minimum niceness on the system
        ;;
    fifo)
        echo "chrt -f $FIFO_PRIORITY"
        ;;
    deadline)
        echo "chrt -P $DEADLINE_PERIOD -T $DEADLINE_RUNTIME -d 0"
        ;;
    *)
        echo "ERROR: The HIGH_PRIO_KIND parameter is not valid, terminating experiment now." >/dev/stderr
        exit 1
        ;;
    esac
}

# function generate_fakedata() {
#     # TODO: generate encrypted fakedata also for the decrypt command
#     mkdir -p "${FAKEDATA_DIR}"
#     # Create a 2G tmp filesystem in /fakedata
#     mkdir -p /fakedata
#     umount /fakedata &>/dev/null || true
#     mount -t tmpfs -o size=2048m tmpfs /fakedata
#     FILESIZE_PREVIOUS=-1
#     # For each task in the specified task set
#     for ((task_index = 0; task_index < ${#TASKS_CMD[@]}; task_index++)); do
#         task_name=${TASKS_NAME[$task_index]}
#         # Create the fake file in a local directory (will then be copied in tmp later).
#         # This file is used so that tasks that read data will run for desired certain
#         # amount of time (see basic_conf.bash)
#         FILESIZE=$((EXP_TASK_MIN_DURATION * TASKS_FILESIZE_RATIO[task_index]))
#         if [ "$FILESIZE" -ne "$FILESIZE_PREVIOUS" ]; then
#             tput cuu 1 && tput el
#             echo "-----> Creating a ${FILESIZE}M file in ${FAKEDATA_DIR}/fakedata-${FILESIZE} "
#             if [ -f "${FAKEDATA_DIR}/fakedata-${FILESIZE}" ]; then
#                 # File already exists, checking if file size matches
#                 EXISTING_FILE_SIZE=$(stat --printf="%s" "${FAKEDATA_DIR}/fakedata-${FILESIZE}")
#                 FILESIZE_BYTES=$((FILESIZE * 1024 * 1024))
#                 if [ "${FILESIZE_BYTES}" = "${EXISTING_FILE_SIZE}" ]; then
#                     # Do nothing, file already exists with the right dimension
#                     :
#                 else
#                     # | pv -s ${FILESIZE}m
#                     head -c ${FILESIZE}M /dev/urandom >"${FAKEDATA_DIR}/fakedata-${FILESIZE}"
#                 fi
#             else
#                 # | pv -s ${FILESIZE}m
#                 head -c ${FILESIZE}M /dev/urandom >"${FAKEDATA_DIR}/fakedata-${FILESIZE}"
#             fi
#             tput cuu 1 && tput el
#         fi
#         FILESIZE_PREVIOUS=$FILESIZE
#     done
#     FILESIZE_PREVIOUS=-1
# }

function prepare_fakedata() {
    sync
    echo 1 >/proc/sys/vm/drop_caches
    local task_index=0

    # Re-copy the fake file in tmp if the size is not already the right one
    FILESIZE=$((EXP_TASK_MIN_DURATION * TASKS_FILESIZE_RATIO[task_index]))
    if [ "$FILESIZE" -ne "$FILESIZE_PREVIOUS" ]; then
        tput cuu 1 && tput el
        echo "-----> Copying a ${FILESIZE}M file in /fakedata/fakedata "
        cp "${FAKEDATA_DIR}/fakedata-${FILESIZE}" /fakedata/fakedata
        # pv "${FAKEDATA_DIR}/fakedata-${FILESIZE}" >/fakedata/fakedata
        tput cuu 1 && tput el
    fi
    FILESIZE_PREVIOUS=$FILESIZE

    # Custom action!
    cp "${FAKEDATA_DIR}/fakedata4.tmp" /fakedata/fakedata4.tmp

    sync
    echo 1 >/proc/sys/vm/drop_caches
}

function task_is_running() {
    if kill -0 "$1" 2>/dev/null; then
        echo "1"
    else
        echo "0"
    fi
}

function terminate_all() {
    # local tasks_pids="$*"
    local is_anyone_running=1
    local timeout="$1"
    local check_interval=1
    local next_iteration_interval="$2"

    SECONDS=0

    while [ "$is_anyone_running" = 1 ] && [ "$SECONDS" -lt "$timeout" ]; do
        kill -2 "${@:3}" &>/dev/null || true
        sleep "$check_interval"
        check_interval="$next_iteration_interval"

        for task in "${@:3}"; do
            is_anyone_running=$(task_is_running "$task")
            if [ "$is_anyone_running" = 1 ]; then
                break
            fi
        done

    done

    kill -9 "${@:3}" &>/dev/null || true
}

############################### run single test ################################

function run_single_test() {
    #local task_index="$1"
    #local task_name="$2"
    local task_rep="$3"

    # Print a progress status
    tput cuu 1 && tput el
    echo "-----> Running \"${task_name}\" [run ${task_rep}/${HOWMANY_TIMES}]"

    # Create current test output directory
    mkdir -p "$(current_test_directory)/${task_rep}"

    # Prepare data structures
    local tasks_cmds=()
    local tasks_cores=()
    local tasks_time_file=()
    local tasks_grep_pattern=
    local tasks_ppid_pattern=
    local tasks_pids=()
    local power_file

    power_file=$(current_test_file_power "${task_rep}")

    local tasks_count=0
    local task_cmd=
    local task_core=
    local task_time_file=
    local cpu_core=

    local task_index=0

    # Prepare the parameters, commands and whatnot to run N tasks on a same
    # number of cpus
    for cpu_core in $(cpufreq_policy_cpu_list "$policy"); do
        if [ "$tasks_count" -ge "$HOWMANY_TASKS" ]; then
            break
        fi
        tasks_count=$((tasks_count + 1))

        # Retrieve the command to execute
        task_cmd=$(tasks_get_command_index "$task_index" $tasks_count)

        # Custom action for gzip
        # FIXME: could the other benefit from this too?
        # if [[ "$task_cmd" =~ gzip ]]; then
        ln -fs /fakedata/fakedata /fakedata/fakedata"$tasks_count"
        # ln -fs /fakedata/fakedata.tmp /fakedata/fakedata"$tasks_count.tmp" || true
        # fi

        # Append to the list
        tasks_cmds+=("${task_cmd}")
        tasks_cores+=("${cpu_core}")
        tasks_time_file+=("$(current_test_file_time "${task_rep}" ${tasks_count})")
        tasks_grep_pattern="$tasks_grep_pattern\|${task_cmd}"

        task_index=$((task_index + 1))
    done

    # Remove first two characters, they are extra \| at the beginning of the string
    tasks_grep_pattern=${tasks_grep_pattern:2}

    # This may run into an infinite loop if not capped like this
    local test_tries_count=0
    local test_ran_smoothly=0
    while [ "$test_ran_smoothly" = "0" ] && [ "$test_tries_count" -lt 20 ]; do
        # We will start HOWMANY_TASKS concurrently and measure their execution
        # times + power consumption
        tasks_pids=()
        tasks_ppid_pattern=
        test_tries_count=$((test_tries_count + 1))

        # Cooldown between a test and the consecutive one
        sleep "$EXP_SLEEP_INTERVAL"

        # Start the N tasks and save the patterns to use to search them later
        for index in $(seq ${tasks_count}); do
            task_cmd="${tasks_cmds[$index - 1]}"
            task_core="${tasks_cores[$index - 1]}"
            task_time_file="${tasks_time_file[$index - 1]}"

            rm -f "$task_time_file"

            # Run the actual command
            taskset -c "$task_core" $HIGH_PRIO_CMD $TIME_CMD $task_cmd >/dev/null 2>"$task_time_file" &
            tasks_pids+=($!)
            tasks_ppid_pattern="${tasks_ppid_pattern}\|$!"
        done

        tasks_ppid_pattern=${tasks_ppid_pattern:2}

        # At this point the execution path changes whether we are measuring the
        # execution time or the consumed power

        if [ -n "$POWERSAMPLER_CMD" ]; then
            # If we are measuring the power consumption

            # At this point a total of ${tasks_count} tasks should be up and
            # running, let's test it

            # This loop exits in three cases:
            # - at least one of the tasks is already terminated; this is an
            #   erroneous condition and the test should be started again in
            #   this case. test_ran_smoothly = 0
            # - more than 20 seconds elapsed and the tasks are not ready yet;
            #   this is an erroneous condition and the test should be started
            #   again in this case. test_ran_smoothly = 0
            # - all tasks started one sub-process each; this is a good condition
            #   and if verified we start the power sampling application as soon
            #   as we exit the loop. test_ran_smoothly = 1

            # Bash has a built-in variable called SECONDS that tracks elapsed time
            SECONDS=0

            while kill -0 "${tasks_pids[@]}" 2>/dev/null; do
                # Get the actual number of sub-processes of the given tasks that
                # are running (that is, that have been started by the
                # ${TIME_CMD} already!)
                # set +e
                ps_out=$(ps -e -o ppid,args |
                    grep --color=never "${tasks_grep_pattern}" |
                    grep --color=never "${tasks_ppid_pattern}" |
                    grep --color=never -v grep |
                    grep --color=never -v perf)
                # set -e

                if [ -z "${ps_out}" ]; then
                    tasks_running=0
                else
                    tasks_running=$(wc -l <<<"${ps_out}")
                fi

                # Uncomment this for debugging the script
                # echo "${tasks_running}=${tasks_count}?"
                # echo ""

                if [ "$tasks_running" = "$tasks_count" ]; then
                    # Great! The test can run smoothly!
                    test_ran_smoothly="1"
                    break
                fi

                if [ $SECONDS -ge 20 ]; then
                    # Not great at all! 20 seconds and still no good match!
                    # Exit to avoid infinite loop
                    break
                fi
            done

            if [ "$test_ran_smoothly" = "1" ]; then
                # Give some time to reach a steady condition
                # sleep "${POWER_STEADY_TIME}"
                # rm -f "${power_file}"

                # Start tracing sensors data now, since we know that all tasks are up
                # and running!
                chrt -f 99 taskset -c "${CPU_CORE_POWER_SAMPLER}" "$POWERSAMPLER_CMD" >"${power_file}" 2>"${power_file}.ERRORS" &
                POWER_SAMPLER=$!

                # Run for a certain amount of time
                sleep "${EXP_TEST_DURATION}"

                # Stop tracing sensors data (sending a SIGINT=2 signal)
                kill -2 $POWER_SAMPLER &>/dev/null
                wait $POWER_SAMPLER 2>/dev/null
            else
                printsay "ERROR: TEST DID NOT RUN SMOOTHLY!! REPEATING!"
                echo ""
                echo ""
                echo ""
            fi

            # Send a SIGINT=2 signal to all the tasks each second until
            # termination. Force-exits tasks after a certain timeout elapsed
            # with no termination on their behalf.
            # First argument is the timeout in seconds, second one is the checking
            # interval, followed by the list of tasks.
            # # NOTE: If you ever notice tasks waiting for far too long, open a
            # # separate shell and type one of the following (first preferred):
            # # > pkill -2 forever
            # # > pkill -9 forever
            terminate_all "300" "10" "${tasks_pids[@]}"

            # Final check, script should NEVER hang here
            wait "${tasks_pids[@]}" || true # 2>/dev/null
        else
            # If we are measuring the execution time and not the power consumption

            # I have the task pids, I'll just wait for them to finish before
            # starting the next iteration
            wait "${tasks_pids[@]}" 2>/dev/null

            # Go on with the next test
            test_ran_smoothly="1"
        fi
    done

    if [ "$test_ran_smoothly" = "0" ]; then
        echo ""
        echo "WWWW : WAS NOT ABLE TO PERFORM CORRECTLY THIS TEST\!\!\!\!"
        echo ""
        echo ""
    fi

    sleep 2s
}

function printsay_frequency_info() {
    local freq="$1"
    local freq_megahertz

    freq_megahertz=$(bc <<<"$freq / 1000")

    local message1="Selected Frequency $freq_megahertz MHz"
    local message2="Transitioning to the selected frquency..."

    echo "---> $message1"
    echo "-----> $message2"

    say "$message1"
}

function printsay_cpu_policy_info() {
    local policy=$1
    local policy_other=$2

    local message1="Current CPU Policy is ${policy}"
    local message2="Other CPU Policy is   ${policy_other}"

    echo "-> $message1"
    echo "-> $message2"

    say "$message1"
    say "$message2"
}

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

(
    set -e

    export PROJPATH
    export SCRIPT_PATH
    export CONFDIR
    export APPSDIR

    PROJPATH="$(get_project_path '../..')"
    SCRIPT_PATH="$(get_script_path)"
    CONFDIR="${PROJPATH}/embedded/confdir"
    APPSDIR="${PROJPATH}/build/embedded/apps"

    # Importing functions and basic configuration
    . "${SCRIPT_PATH}/cpufreq.bash"
    . "${SCRIPT_PATH}/trip_points.bash"
    . "${SCRIPT_PATH}/fakedata.bash"
    . "${CONFDIR}/conf-base.bash"

    # Load custom parameters to substitute the ones in basic_conf.bash from the specified file, if any
    if [ $# -gt 0 ]; then
        for arg in "$@"; do
            if [ -z "$arg" ]; then
                continue
            fi

            echo "--> Loading file ${arg}"
            . "$arg"
        done
    fi

    # The tasks to be run are always the same
    . "${CONFDIR}/conf-tasks-mixed.bash"

    HOWMANY_TASKS=4 # Length of TASKS_CMD

    # Jump into output directory
    # TODO: remove old data before writing to each file
    # rm -rf "$EXP_BASE_DIR/howmany_${HOWMANY_TASKS}"
    mkdir -p "$EXP_BASE_DIR/howmany_${HOWMANY_TASKS}"
    cd "$EXP_BASE_DIR/howmany_${HOWMANY_TASKS}"

    echo ""
    echo "------------> Experiment Metadata <------------"
    echo ""

    # Save experiment metadata and print them on the screen too
    # TODO: SAVE MORE METADATA!
    experiment_save_metadata "exp_metadata-${EXP_TITLE}.txt"
    cat "exp_metadata-${EXP_TITLE}.txt"

    echo ""
    echo "----------> Rebuilding applications <----------"
    echo ""

    # Rebuild binaries if necessary
    "${PROJPATH}/embedded/build.sh"

    # DO NOT MOVE: This command is necessary to run correctly RT applications,
    # if any!
    sysctl -w kernel.sched_rt_runtime_us=-1 >/dev/null

    # Get the command to run tasks with high priority
    HIGH_PRIO_CMD=$(get_prio_cmd)

    # Initialize some variables for the loop
    FILESIZE_PREVIOUS=-1

    # Now iterate CPU policies
    policy=""
    policy_other=""

    echo ""
    echo "----> Experiment will begin in 30 seconds <----"
    echo ""

    # Unplug everything now
    # sleep 30s

    echo ""
    echo "---------> Experiment will begin now <---------"
    echo ""

    echo "---> Generaring fake data files..."
    generate_fakedata_ondisk
    create_fakedata_inram

    activate_pwm_fans

    echo "POLICIES: "
    cpufreq_policy_list | sort -n

    # Iterate cpufreq policies (cpu islands)
    for policy in $(cpufreq_policy_list | sort -n); do

        skip_policy=1

        # If a set of forced policies is provided,
        # check that the given policy is inside the given set
        if [ "${#EXP_POLICY_FORCED_LIST[@]}" != "0" ]; then
            for policy_forced in "${EXP_POLICY_FORCED_LIST[@]}"; do
                # If the policy is in the list, do not skip
                if [ "$policy" = "$policy_forced" ]; then
                    skip_policy=0
                    break
                fi
            done
        else
            # If list is empty, do not skip
            skip_policy=0
        fi

        if [ "$skip_policy" = "1" ]; then
            echo "---> Skipping $policy policy"
            continue
        fi

        # Get a policy different than the current one
        if [ -z "$policy_other" ] || [ "$policy_other" = "$policy" ]; then
            policy_other=$(policy_find_another "$policy")
        fi

        printsay_cpu_policy_info "$policy" "$policy_other"

        # # # Start a set of background tasks on policy_other
        # # # FIXME: good for two policies only, for more policies we shouls start stress applications on each core that is NOT under the current policy
        # # # NOTICE: REMOVED BECAUSE DEEMED USELESS AND ACTUALLY PROBLEMATIC
        # # echo "---> Starting background processes on policy $policy_other"
        # # for cpu_o in $(cpufreq_policy_cpu_list $policy_other); do
        # #     nice -n 19 taskset -c $cpu_o stress -c 1 >/dev/null &
        # # done

        # Set the core on which run the power sensor to be the last of
        # policy_other
        # NOTICE: assumes there are at least two cores in the current policy!
        # TODO: create a "fake" policy that includes all cores in other policies
        # than the current one and work with that!
        #CPU_OTHER_LIST_STR=$(cpufreq_policy_cpu_list $policy_other)
        readarray -t CPU_OTHER_LIST <<<"$(cpufreq_policy_cpu_list "$policy_other")"

        CPU_CORE_POWER_SAMPLER=${CPU_OTHER_LIST[0]}
        CPU_CORE_EXP_SCRIPT=${CPU_OTHER_LIST[1]}

        # If no other policy is present, use last core for both power and
        # script, even if this will make everything messier, they should affect
        # only execution time of the last command on a multi-core test (and
        # energy measurement like this doesn't really make sense anyway)
        if [ "$policy_other" = "$policy" ]; then
            CPU_CORE_POWER_SAMPLER=${CPU_OTHER_LIST[${#CPU_OTHER_LIST[@]} - 1]}
            CPU_CORE_EXP_SCRIPT=${CPU_OTHER_LIST[${#CPU_OTHER_LIST[@]} - 1]}
        fi

        # Move the current script to another core
        # NOTICE: USING BOTH $BASHPID AND $$ BECAUSE THIS SCRIPT IS TECNICALLY
        # INSIDE A SUBSHELL!
        taskset -c -p "${CPU_CORE_EXP_SCRIPT}" $$ &>/dev/null
        taskset -c -p "${CPU_CORE_EXP_SCRIPT}" ${BASHPID} &>/dev/null

        # Prepare CPU policies (use the commented line to set the other policies
        # to the minimum frequency instead of the maximum one)
        echo "If you see an error here, but the script continues, then it's all fine, don't panic!"
        #(
        cpufreq_governor_setall "performance" || cpufreq_governor_setall "userspace"
        #) 2>/dev/null || (
        #    echo 'NEITHER performance NOR userspace GOVERNORS SUPPORTED!'
        #    false
        #)
        # cpufreq_policy_frequency_maxall
        cpufreq_policy_frequency_minall

        # Set again the cores in the current policy to the original frequency before moving on
        # cpufreq_policy_frequency_maxall
        cpufreq_policy_frequency_minall

        echo "FREQUENCES: "
        cpufreq_policy_frequency_list "$policy" | sort -n

        # For each frequency available for all its cores at once
        # FIXME: remove the -nr and use just -n
        for freq in $(cpufreq_policy_frequency_list "$policy" | sort -n); do

            skip_freq=1

            # If a set of forced frequencies is provided,
            # check that the given frequency is inside the given set
            if [ "${#EXP_FREQ_FORCED_LIST[@]}" != "0" ]; then
                for freq_forced in "${EXP_FREQ_FORCED_LIST[@]}"; do
                    # If the frequency is in the list, do not skip
                    if [ "$freq" = "$freq_forced" ]; then
                        skip_freq=0
                        break
                    fi
                done
            else
                # If list is empty, do not skip
                skip_freq=0
            fi

            if [ "$skip_freq" = "1" ]; then
                echo "---> Skipping $freq frequency"
                continue
            fi

            printsay_frequency_info "$freq"

            # Set the desired frequency for the given policy
            cpufreq_policy_frequency_set "$policy" "$freq"

            ####################################################################

            # This line will be deleted by the print inside the loop
            echo ""

            # For each task in the specified task set
            #for ((task_index = 0; task_index < ${#TASKS_CMD[@]}; task_index++))#; do
            #    task_name=${TASKS_NAME[$task_index]}

            # Copy if necessary a new fakedata file in /fakedata from the
            # fakedata directory created beforehand
            copy_fakedata_inram /fakedata/fakedata \
                    "$((EXP_TASK_MIN_DURATION * TASKS_FILESIZE_RATIO[task_index]))"

            # FIXME: This whole parade here is needed only for the
            # encrypt/decrypt application pair, maybe it would be useful to
            # do a single run at the beginning and store the results
            # somewhere only for those applications!

            # If power sampling test, make a dry run using another time command
            # if [ -n "$POWERSAMPLER_CMD" ]; then
            #     case $task_name in
            #     encrypt | decrypt)
            #         TIME_CMD_BKP="$TIME_CMD"
            #         TIME_CMD="$TIME_CMD_DRY"
            #         POWERSAMPLER_CMD_BKP="$POWERSAMPLER_CMD"
            #         POWERSAMPLER_CMD=""

            #         # Dry run, used to create custom data like for the encrypt and decrypt commands
            #         run_single_test "$task_index" "$task_name" "0"

            #         # Copy the whole content of /fakedata back to another
            #         # directory, before it gets corrupted by interrupted jobs
            #         rm -rf "$HOME/.fakedata-tmp"
            #         mkdir -p "$HOME/.fakedata-tmp"
            #         cp /fakedata/* "$HOME/.fakedata-tmp"

            #         # Drop system cache, it fills up when copying the directory
            #         sync
            #         echo 1 >/proc/sys/vm/drop_caches

            #         TIME_CMD="$TIME_CMD_BKP"
            #         POWERSAMPLER_CMD="$POWERSAMPLER_CMD_BKP"
            #         ;;
            #     *) ;;
            #     esac
            # fi

            sync
            echo 1 >/proc/sys/vm/drop_caches

            # Repeat the test multiple times
            for ((task_rep = 1; task_rep <= "${HOWMANY_TIMES}"; ++task_rep)); do
                run_single_test "$task_index" "$task_name" "$task_rep"

                # Restore content of /fakedata after each interrupted run
                if [ -n "$POWERSAMPLER_CMD" ]; then
                    # case $task_name in
                    # encrypt | decrypt)
                    rm -rf /fakedata/*
                    cp "$HOME/.fakedata-tmp/"* /fakedata

                    # Drop system cache, it fills up when copying the directory
                    sync
                    echo 1 >/proc/sys/vm/drop_caches
                    #     ;;
                    # *) ;;
                    # esac
                fi
            done # For HOWMANY_TIMES
            # done     # FOREACH TASK
            # rm -rf /fakedata/fakedata*.tmp
        done # FOREACH FREQUENCY
    done     # FOREACH CPUFREQ POLICY
)

printsay "Experiment finished!"
