#!/bin/bash

# -------------------------------------------------------- #
#                     path management                      #
# -------------------------------------------------------- #

function jump_and_print_path() {
    cd -P "$(dirname "$_SOURCE")" >/dev/null 2>&1 && pwd
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
    _PROJPATH=$(jump_and_print_path "${_PATH}/$1")

    echo "${_PROJPATH}"
}

# -------------------------------------------------------- #
#                          output                          #
# -------------------------------------------------------- #

function print_msg() {
    printf '%s\n' "$*"
}

function say_msg() {
    (print_msg "$@" | festival --tts 2>/dev/null) || true
}

function delline() {
    # Active only when running in a terminal (not when output is redirected)
    if [ -t 1 ]; then
        tput cuu 1 && tput el
    fi
}

function pinfo() {
    print_msg "$@"
}

function pinfo_say() {
    print_msg "$@"
    say "$@"
}

function perr() {
    print_msg 'ERR:' "$@" >&2
    say 'ERROR:' "$@"
}

function pwarn() {
    print_msg 'WARN:' "$@" >&2
    say 'ERROR:' "$@"
}

function pinfo_newline() {
    print_msg ''
}

function perr_newline() {
    print_msg '' >&2
}

function pwarn_newline() [
print_msg '' >&2
]

# Env variables:
#  - freq
function pinfo_frequency() {
    pinfo_say "Selecting frequency $(bc <<<"$freq / 1000") MHz..."
    pinfo_newline
}

# Env variables:
#  - policy
#  - policy_other
function pinfo_cpupolicy() {
    pinfo_say "Current CPU Island is ${policy}"
    pinfo_say "Other   CPU Island is ${policy_other}"
    pinfo_newline
}

# -------------------------------------------------------- #
#                   experiment metadata                    #
# -------------------------------------------------------- #

# Save on the file given as argument the experiment metadata
# TODO: save more detailed metadata
# TODO: move to yml?
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

# -------------------------------------------------------- #
#                     task management                      #
# -------------------------------------------------------- #

# Get the command to execute from the given command index and the number of
# the current task to be started
# Arguments:
#  1. command index
#  2. task index (depends on how many concurrent runs you launch)
function tasks_get_command_index() {
    task=${TASKS_CMD[$1]}
    echo "${task//fakedata\/fakedata/fakedata\/fakedata${2}}"
}

function task_is_running() {
    kill -0 "$1" 2>/dev/null
}

# Send a SIGINT=2 signal to all the tasks each second until termination.
# Force-exits tasks after a certain timeout elapsed with no termination on their
# behalf.
#
# Arguments:
#  1. Timeout in seconds
#  2. Check interval in seconds 3+. List task PIDs to check
function terminate_all() {
    local timeout
    local check_interval
    local at_least_one_running
    local pids
    local p

    timeout="$1"
    check_interval="$2"
    pids="${@:3}"

    SECONDS=0
    at_least_one_running=1
    while [ "$at_least_one_running" = 1 -a "$SECONDS" -lt "$timeout" ]; do
        kill -2 $pids &>/dev/null || true
        sleep "$check_interval"

        at_least_one_running=0
        for p in $pids; do
            if task_is_running "$p"; then
                at_least_one_running=1
                break
            fi
        done
    done

    if [ "$at_least_one_running" = 1 ]; then
        print_error "terminating tasks that are still running after" \
            "finishing the waiting loop!"
        err_extra_line
    fi

    kill -9 $pids &>/dev/null || truekill -9 "${@:3}" &>/dev/null || true
}

# -------------------------------------------------------- #
#                        filenames                         #
# -------------------------------------------------------- #

# Env variables:
#  - policy
#  - freq
#  - task_name
function this_test_directory() {
    echo "policy_${policy}/freq_${freq}/task_${task_name}"
}

# Env variables:
#  - task_rep
#
# Arguments:
#  1. task instance index (depends on how many concurrent runs you launch)
function this_test_file_time() {
    local count="$1"

    if [ -n "${FILENAME_OUT_TIME}" ]; then
        echo "$(this_test_directory)/${task_rep}/${FILENAME_OUT_TIME}_${count}.txt"
    else
        echo "$(this_test_directory)/${task_rep}/debug.txt"
    fi
}

# Env variables:
#  - task_rep
function this_test_file_power() {
    if [ -n "${FILENAME_OUT_POWER}" ]; then
        echo "$(this_test_directory)/${task_rep}/${FILENAME_OUT_POWER}_.txt"
    else
        echo "/dev/null"
    fi
}

# -------------------------------------------------------- #
#                      configuration                       #
# -------------------------------------------------------- #

# Prints the command that should be used to run applications
# with "high priority"
# TODO: print these parameters in metadata?
# FIXME: SCHED_DEADLINE does not work for some task types
function high_prio_kind_to_cmd() {
    case $HIGH_PRIO_KIND in
    nice)
        echo "nice -n -100" # Will receive minimum niceness on the system
        ;;
    fifo)
        echo "chrt -f $FIFO_PRIORITY"
        ;;
    deadline)
        echo "chrt -P $DEADLINE_PERIOD -T $DEADLINE_RUNTIME -d 0"
        ;;
    *)
        print_error "the HIGH_PRIO_KIND parameter is not valid!"
        print_error "invalid value: $HIGH_PRIO_KIND"
        print_error "terminating experiment now."
        err_extra_line
        return 1
        ;;
    esac
}

# ============================================================================ #
#                          Body of a Single Test Run                           #
# ============================================================================ #

# Arguments: none.
#
# Accessed env variables:
#  - freq
#  - policy
#  - rep
#  - task_index
#  - task_name
#  - task_rep
#  - CPU_CORE_POWER_SAMPLER
#  - EXP_SLEEP_INTERVAL
#  - EXP_TEST_DURATION
#  - FILENAME_OUT_POWER
#  - FILENAME_OUT_TIME
#  - HIGH_PRIO_CMD
#  - HOWMANY_TIMES
#  - POWERSAMPLER_CMD
#  - SECONDS
#  - TASKS_CMD
#  - TASKS_NAME
#  - TIME_CMD
function single_test_run() {
    # local task_num
    # local task_index
    # local task_rep
    # local task_name
    # local policy

    # task_index="$1"
    # task_rep="$2"
    # policy="$3"
    # task_name="${TASKS_NAME[$task_index]}"
    # task_num=

    # Print progress status
    delline
    pinfo \
        "-->" \
        "[Task $((task_index + 1))/${#TASKS_NAME[@]}]" \
        "Running '${task_name}'" \
        "[run ${task_rep}/${HOWMANY_TIMES}"

    # Create current test output directory
    mkdir -p "$(this_test_directory)/${task_rep}"

    # Variables that hold data for the actual runs
    local tasks_cmds=()
    local tasks_cores=()
    local tasks_time_file=()
    local tasks_grep_pattern=
    local tasks_ppid_pattern=
    local tasks_pids=()
    local power_file

    # Same for all tasks
    power_file=$(this_test_file_power "${task_rep}")

    # Local variables for the following loop
    local tasks_count=0
    local task_cmd=
    local task_core=
    local task_time_file=
    local cpu_core=

    # For each CPU, but no more tasks than requested,
    # prepare parameters for all tasks to start before
    # actually starting them
    for cpu_core in $(cpufreq_policy_cpu_list "$policy"); do
        if [ "$tasks_count" -ge "$HOWMANY_TASKS" ]; then
            break
        fi
        tasks_count=$((tasks_count + 1))

        # Input files are all symbolic links to the same
        # file (assumes homogeneous runs)
        ln -fs /fakedata/fakedata /fakedata/fakedata"$tasks_count"

        # Command to execute
        task_cmd=$(tasks_get_command_index "$task_index" $tasks_count)
        tasks_cmds+=("$task_cmd")

        # On which core
        tasks_cores+=("$cpu_core")

        # Outputing where
        tasks_time_file+=("$(this_test_file_time "$task_rep" $tasks_count)")

        # How to grep all running tasks
        tasks_grep_pattern="$tasks_grep_pattern\|$task_cmd"
    done # foreach CPU

    # Remove first two characters, they are extra \| at the
    # beginning of the string
    tasks_grep_pattern=${tasks_grep_pattern:2}

    # Runs may not finish smoothly if not enough tasks are "seen" concurrently
    # running at the same time. This loops repeats the actual experiment until
    # that happens (for at most 20 times!).
    local test_tries_count=0
    local test_ran_smoothly=0
    while [ "$test_ran_smoothly" = "0" -a "$test_tries_count" -lt 20 ]; do
        # Start tasks_count parallel executions
        tasks_pids=()
        tasks_ppid_pattern=
        test_tries_count=$((test_tries_count + 1))

        # Cooldown between a test and the consecutive one
        sleep "$EXP_SLEEP_INTERVAL"

        # Start the tasks and save a pattern based on the pids to look for them
        # later

        # Start the tasks and save the patterns to use to search them later
        local index
        for ((index = 0; index < $tasks_count; ++index)); do
            task_cmd="${tasks_cmds[$index]}"
            task_core="${tasks_cores[$index]}"
            task_time_file="${tasks_time_file[$index]}"

            # NOTE: assumes the time measuring command prints to stderr

            # Order of operations:
            # - set the cpu
            # - set the priority (WARN: DEADLINE WILL NOT WORK LIKE THIS)
            # - start time measuring
            # - actual command to run
            taskset -c "$task_core" \
                $HIGH_PRIO_CMD \
                $TIME_CMD \
                $task_cmd \
                >/dev/null 2>"$task_time_file" &

            # Save pids for later
            tasks_pids+=($!)
            tasks_ppid_pattern="${tasks_ppid_pattern}\|$!"
        done

        # Remove first two characters, they are extra \| at
        # the beginning of the string
        tasks_ppid_pattern=${tasks_ppid_pattern:2}

        # NOTE: see old implementation (commits before
        # 6ca464a) for what to do when no power estimation
        # is running

        # Assuming we are measuring the power consumption as well

        # The following loop exits in three cases:
        # 1. at least one of the tasks is already
        #    terminated; this is an erroneous condition!
        #    test_ran_smoothly = 0
        # 2. more than 20 seconds elapsed and the tasks are
        #    not ready yet; this is an erroneous condition!
        #    test_ran_smoothly = 0
        # 3. all tasks started one sub-process each; this is
        #    a good condition and if verified we start the
        #    power sampling application as soon as we exit
        #    the loop. test_ran_smoothly = 1

        # Using Bash builtin variable to roughly track elapsed time
        SECONDS=0
        # While condition: test (1)
        while kill -0 "${tasks_pids[@]}" 2>/dev/null; do
            # They are still all running. Since
            # taskset/nice/chrt do not spawn processes, the
            # time measuring is the father and the actual
            # task is the child. Hence, check if each top
            # process has each one sub-process.

            # MAGIC TRICK, DO NOT TOUCH. Brief explanation, line per line:
            # - output all tasks by pid and list of arguments
            # - filter the ones with the correct arguments
            # - filter the ones with the right PARENT pid
            # - filter OUT grep itself, which happens to match both filters
            # - filter OUT perf, which happens to match both filters

            # TODO: PMC?

            # set +e
            ps_out=$(ps -e -o ppid,args |
                grep --color=never "${tasks_grep_pattern}" |
                grep --color=never "${tasks_ppid_pattern}" |
                grep --color=never -v grep |
                grep --color=never -v perf || true)
            # set -e

            # Output has exactly one line per desired task
            if [ -z "${ps_out}" ]; then
                tasks_running=0
            else
                tasks_running=$(wc -l <<<"${ps_out}")
            fi

            # Uncomment this for debugging the script
            # echo "${tasks_running}=${tasks_count}?"
            # echo ""

            # Number of tasks: test (3)
            if [ "$tasks_running" = "$tasks_count" ]; then
                # Great! The test can run smoothly!
                test_ran_smoothly="1"
                break
            fi

            # Timeout: test (2)
            if [ $SECONDS -ge 20 ]; then
                # Not great at all! 20 seconds and still no good match!
                # Exit to avoid infinite loop
                break
            fi
        done

        if [ "$test_ran_smoothly" = "1" ]; then
            local power_task

            # Tasks reached a steady condition, start
            # tracing sensors data now!
            taskset -c "${CPU_CORE_POWER_SAMPLER}" \
                chrt -f 99 \
                "$POWERSAMPLER_CMD" \
                >"${power_file}" 2>"${power_file}.ERRORS" &
            power_task=$!

            # Run for a certain amount of time
            sleep "${EXP_TEST_DURATION}"

            # Stop tracing sensors data (sending a SIGINT=2 signal)
            kill -2 $power_task &>/dev/null
            wait $power_task 2>/dev/null
        else
            print_warn "===> TEST DID NOT RUN SMOOTHLY!! REPEATING! <==="
            err_extra_line
        fi

        terminate_all "300" "10" "${tasks_pids[@]}"

        # NOTE: If you ever notice tasks waiting for far too
        # long and TIME_CMD is `forever`, open a separate
        # shell and type one of the following (first one
        # preferred):
        #  - pkill -2 forever
        #  - pkill -9 forever

        # Final check, script should NEVER hang here
        wait "${tasks_pids[@]}" || true # 2>/dev/null
    done
    # until test ran smoothly

    if [ "$test_ran_smoothly" = "0" ]; then
        err_extra_line
        print_error 'was not able to perform correctly a test!'
        print_error 'test parameters:'
        print_error "POLICY ${policy}"
        print_error "HOWMANY ${tasks_count}"
        print_error "TASK ${task_name}"
        print_error "REP ${task_rep}"
        err_extra_line
        err_extra_line
    fi

    sleep 2s
}

# Returns whether the policy should be skipped (i.e. not
# part of the "forced policy list", if any) or not.
#
# Env variables:
#  - policy
function should_skip_policy() {
    local policy_forced

    # First check if the list is provided
    if [ "${#EXP_POLICY_FORCED_LIST[@]}" -gt 0 ]; then
        # It is, then the policy must be in the list
        for policy_forced in "${EXP_POLICY_FORCED_LIST[@]}"; do
            [ "$policy" = "$policy_forced" ] && return 0
        done

        # Not in the list
        return 1
    fi

    return 0
}

# Returns whether the frequency should be skipped (i.e. not
# part of the "forced frequency list", if any) or not.
#
# Env variables:
#  - freq
function should_skip_policy() {
    local freq_forced

    # First check if the list is provided
    if [ "${#EXP_FREQ_FORCED_LIST[@]}" -gt 0 ]; then
        # It is, then the frequency must be in the list
        for freq_forced in "${EXP_FREQ_FORCED_LIST[@]}"; do
            [ "$freq" = "$freq_forced" ] && return 0
        done

        # Not in the list
        return 1
    fi

    return 0
}

function load_conf_files() {
    for arg in "$@"; do
        [ ! -f "$arg" ] && continue

        pinfo "--> Loading file $arg"
        . "$arg"
    done
}

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
    . "${SCRIPT_PATH}/cpufreq.sh"
    . "${SCRIPT_PATH}/fix-trip-points.sh"
    . "${SCRIPT_PATH}/fakedata.sh"

    # Load base parameters
    . "${CONFDIR}/base/base.sh"

    # The tasks to be run typically are these, but they can
    # be overwritten with files in parameters
    . "${CONFDIR}/tasks/simple.bash"

    # Load custom parameters to substitute the ones in
    # base.sh from the specified file, if any
    load_conf_files "$@"

    # Jump into output directory.
    mkdir -p "$EXP_BASE_DIR/howmany_${HOWMANY_TASKS}"
    cd "$EXP_BASE_DIR/howmany_${HOWMANY_TASKS}"

    # NOTE: this will NOT delete old data, old data is
    # overwritten only new data is actually written on top!

    pinfo_newline
    pinfo '--> Printing experiment metadata'
    pinfo_newline

    # Save experiment metadata and print them on the screen too
    # TODO: SAVE MORE METADATA!
    experiment_save_metadata "exp_metadata-${EXP_TITLE}.txt"
    cat "exp_metadata-${EXP_TITLE}.txt"

    pinfo_newline
    pinfo '--> Rebuilding applications'
    pinfo_newline

    # Rebuild binaries if necessary
    "${PROJPATH}/embedded/build.sh"

    # DO NOT MOVE: This command is necessary to run
    # correctly RT applications, if any!
    sysctl -w kernel.sched_rt_runtime_us=-1 >/dev/null

    # Get the command to run tasks with high priority
    HIGH_PRIO_CMD=$(high_prio_kind_to_cmd)

    pinfo_newline
    pinfo '--> Generating fake data for the experiment'
    pinfo_newline
    generate_fakedata_ondisk
    create_fakedata_inram /fakedata 2048

    activate_pwm_fans

    pinfo_newline
    pinfo '--> Experiment will begin in 30 seconds...'
    pinfo_newline

    # Unplug everything now
    sleep 30s

    pinfo_newline
    pinfo '--> Experiment will begin NOW!'
    pinfo_newline

    policy_list=$(cpufreq_policy_list | sort -n)

    pinfo '--> List of policies available:' "$policy_list"

    #------------------------------------------------------#
    #------------------- FOREACH POLICY -------------------#
    #------------------------------------------------------#

    policy=
    policy_other=
    for policy in $policy_list; do
        if should_skip_policy; then
            pinfo "--> Skipping policy $policy"
            continue
        fi

        # Get a policy different than the current one (it
        # may remain the same one, but it's okay in that
        # case, we at least try)
        if [ -z "$policy_other" -o "$policy_other" = "$policy" ]; then
            policy_other=$(cpufreq_policy_find_another "$policy")
        fi

        pinfo_cpupolicy

        #--------------------------------------------------#
        #-------- TASKSET SCRIPT AND POWER SAMPLER --------#
        #--------------------------------------------------#

        # If no other policy is present, use last core for both power and
        # script, even if this will make everything messier, they should affect
        # only execution time of the last command on a multi-core test. It is
        # inevitable...
        if [ "$policy_other" = "$policy" ]; then
            CPU_CORE_POWER_SAMPLER=${CPU_OTHER_LIST[${#CPU_OTHER_LIST[@]} - 1]}
            CPU_CORE_EXP_SCRIPT=${CPU_OTHER_LIST[${#CPU_OTHER_LIST[@]} - 1]}
        else
            # NOTE: we no longer start stress tasks on the other policy

            # Select the core on which the power sensor will run
            # as the last one in policy_other.
            readarray -t CPU_OTHER_LIST <<<"$(cpufreq_policy_cpu_list "$policy_other")"
            CPU_CORE_POWER_SAMPLER=${CPU_OTHER_LIST[0]}
            CPU_CORE_EXP_SCRIPT=${CPU_OTHER_LIST[1]}

            # TODO: how about having a "fake" policy that instead includes all cores
            # that are NOT in the current policy?

            # Fix in the remote case the CPU_OTHER_LIST has only one core:
            if [ "${#CPU_OTHER_LIST[@]}" -lt 2 ]; then
                CPU_CORE_EXP_SCRIPT=$CPU_CORE_POWER_SAMPLER
            fi
        fi

        if [ "$CPU_CORE_EXP_SCRIPT" = "$CPU_CORE_POWER_SAMPLER" ]; then
            pwarn "Running the original script on the same core as the power sampler!"
            pwarn_newline
        fi

        # Move the current script to another core
        # NOTICE: USING BOTH $BASHPID AND $$ BECAUSE THIS SCRIPT IS TECHNICALLY
        # INSIDE A SUBSHELL!
        taskset -c -p "${CPU_CORE_EXP_SCRIPT}" $$ &>/dev/null
        taskset -c -p "${CPU_CORE_EXP_SCRIPT}" ${BASHPID} &>/dev/null

        #--------------------------------------------------#
        #--------- PREPARE POLICY AND FREQURENCY ----------#
        #--------------------------------------------------#

        # Prepare CPU policies for manual frequency switching
        pwarn "If you see an error message here," \
            "but the script keeps going, don't panic. It's all good."
        (
            cpufreq_governor_setall "performance" || cpufreq_governor_setall "userspace"
        ) 2>/dev/null || (
            perr 'NEITHER performance NOR userspace GOVERNORS SUPPORTED!'
            perr 'Run will terminate now.'
            false
        )

        # Use the commented command to set the other policies to the maximum
        # instead of the minimum frequency.
        cpufreq_policy_frequency_minall
        # cpufreq_policy_frequency_maxall

        policy_frequencies="$(cpufreq_policy_frequency_list "$policy" | sort -n)"
        pinfo "--> Policy $policy supported frequencies: $policy_frequencies"

        #--------------------------------------------------#
        #--------------- FOREACH FREQUENCY ----------------#
        #--------------------------------------------------#

        # For each frequency available for all its cores at once
        for freq in $policy_frequencies; do
            if should_skip_frequency; then
                pinfo "--> Skipping frequency $freq"
                continue
            fi

            pinfo_frequency

            # Set the desired frequency for the given policy
            cpufreq_policy_frequency_set "$policy" "$freq"

            # This line will be deleted by the print inside the single test run
            pinfo_newline ""

            #----------------------------------------------#
            #---------------- FOREACH TASK ----------------#
            #----------------------------------------------#
            for ((task_index = 0; task_index < ${#TASKS_CMD[@]}; ++task_index)); do
                task_name=${TASKS_NAME[$task_index]}
                fakefile_size=$((EXP_TASK_MIN_DURATION * TASKS_FILESIZE_RATIO[task_index]))

                # Copy if necessary a new fakedata file in /fakedata from the
                # fakedata directory created beforehand
                copy_fakedata_inram /fakedata/fakedata "$fakefile_size"
                sync
                echo 1 >/proc/sys/vm/drop_caches

                # FIXME: This whole parade here is needed only for the
                # encrypt/decrypt application pair, maybe it would be useful to
                # do a single run at the beginning and store the results
                # somewhere only for those applications!

                # # If power sampling test, make a dry run using another time command
                # if [ -n "$POWERSAMPLER_CMD" ]; then
                #     case $task_name in
                #     encrypt | decrypt)
                #         TIME_CMD_BKP="$TIME_CMD"
                #         TIME_CMD="$TIME_CMD_DRY"
                #         POWERSAMPLER_CMD_BKP="$POWERSAMPLER_CMD"
                #         POWERSAMPLER_CMD=""
                #         # Dry run, used to create custom data like for the encrypt and decrypt commands
                #         task_rep=0
                #         single_test_run
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

                # Repeat the test multiple times
                for ((task_rep = 1; task_rep <= "${HOWMANY_TIMES}"; ++task_rep)); do
                    single_test_run

                    # Restore content of fakedata after each run
                    rm -rf /fakedata/*
                    copy_fakedata_inram /fakedata/fakedata "$fakefile_size"
                    sync
                    echo 1 >/proc/sys/vm/drop_caches

                    # if [ -n "$POWERSAMPLER_CMD" ]; then
                    #     case $task_name in
                    #     encrypt | decrypt)
                    #         rm -rf /fakedata/*
                    #         cp "$HOME/.fakedata-tmp/"* /fakedata
                    #         # Drop system cache, it fills up when copying the directory
                    #         sync
                    #         echo 1 >/proc/sys/vm/drop_caches
                    #         ;;
                    #     *) ;;
                    #     esac
                    # fi
                done # FOREACH REPETITION
            done     # FOREACH TASK
        done         # FOREACH FREQUENCY
    done             # FOREACH POLICY
)

pinfo_say "Experiment terminated!"
