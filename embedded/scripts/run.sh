#!/bin/bash

success_file="$(mktemp)"

function hostname_waddress() {
    echo "$(hostname) ($(hostname -I | cut -d' ' -f1))"
}

function notify_termination() {
    pinfosay1 "Experiment terminated correctly!"
    telegram_notify "Your experiment on $(hostname_waddress) terminated correctly!"
    echo OK >"$success_file"
}

function notify_premature_termination() {
    echo "Experiment terminated prematurely!" >&2

    local PROJPATH
    local SCRIPT_PATH

    PROJPATH="$(get_project_path '../..')"
    SCRIPT_PATH="$(get_script_path)"

    . "${SCRIPT_PATH}/util/telegram-tokens.sh" 2>/dev/null || true
    . "${SCRIPT_PATH}/util/telegram.sh"

    telegram_notify "Your experiment on $(hostname_waddress) terminated prematurely!"
}

# -------------------------------------------------------- #
#                     path management                      #
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

# Uses a few patterns to generate the command to run (namely substitutes input
# and output files).
#
# Env variables:
#  - TASKS_CMD
#  - task_index
#
# Arguments:
#  1. infile path (the outfile is the infile followed by the out extension)
function task_command() {
    local infile_pattern="INFILE"
    local outext_pattern="OUTFILE_EXT"
    local task

    local infile=$1

    task=${TASKS_CMD[$task_index]}

    local safe_sed_separator_list=("/" "#" "@" "£" "€" "")
    local safe_sed_separator
    for safe_sed_separator in ${safe_sed_separator_list[@]}; do
        # Checking if the separator is okay or sed will
        # wrongly interpret the regex

        [[ "${infile_pattern}" == *"${safe_sed_separator}"* ]] && continue
        [[ "${outfile_pattern}" == *"${safe_sed_separator}"* ]] && continue
        [[ "${infile}" == *"${safe_sed_separator}"* ]] && continue
        [[ "${outfile_ext}" == *"${safe_sed_separator}"* ]] && continue

        break
    done

    if [ -z "$safe_sed_separator" ]; then
        perr "Could not find a safe separator to substitute! Terminating!"
        false
    fi

    local _SSS_=${safe_sed_separator}

    task=$(echo $task | sed -e "s${_SSS_}${infile_pattern}${_SSS_}${infile}${_SSS_}")
    task=$(echo $task | sed -e "s${_SSS_}${outext_pattern}${_SSS_}${outfile_ext}${_SSS_}")

    echo $task
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
#  2. Check interval in seconds
#  3. List task PIDs to check
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
#  - task_rep
function this_test_directory() {
    echo "policy_${policy}/freq_${freq}/task_${task_name}/${task_rep}"
}

# Env variables:
#  - FILENAME_OUT_TIME
#
# Arguments:
#  1. task instance index (depends on how many concurrent runs you launch)
function logfile_time() {
    local basename="debug.txt"
    local count="$1"

    if [ ! -z "${FILENAME_OUT_TIME}" ]; then
        basename="${FILENAME_OUT_TIME}"
    fi

    echo "${basename}.${count}"
}

function logfile_power() {
    echo "${FILENAME_OUT_POWER}"
}

function logfile_power_err() {
    echo "${FILENAME_OUT_POWER}.err"
}

ramfs_size=2048
ramfs_path="/ramfs"
ramfs_logpath="${ramfs_path}/log"
ramfs_datapath="${ramfs_path}/data"
ramfs_infile="${ramfs_datapath}/data"

outfile_ext="out"

# Argument
#  1. task count
function ramfs_current_infile() {
    echo "${ramfs_infile}.$1"
}

# Argument
#  1. task count
function ramfs_current_outfile() {
    echo "${ramfs_current_infile}.${outfile_ext}"
}

# Argument
#  1. task count
function ramfs_current_logfile_time() {
    echo "${ramfs_logpath}/$(logfile_time $1)"
}

function ramfs_current_logfile_power() {
    echo "${ramfs_logpath}/$(logfile_power)"
}

function ramfs_current_logfile_power_err() {
    echo "${ramfs_logpath}/$(logfile_power_err)"
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

# If you need something more sophisticated, change this function
function wait_cooldown() {
    sleep "$EXP_SLEEP_INTERVAL"
}

function wait_test_duration() {
    sleep "${EXP_TEST_DURATION}"
}

# Env variables:
#
#  - HOWMANY_TIMES
#  - TASKS_NAME
#
#  - task_index
#  - task_name
#  - task_rep
function run_a_test() {
    # Print progress status
    delline
    pinfo2 \
        "[Task $((task_index + 1))/${#TASKS_NAME[@]}]" \
        "Running '${task_name}'" \
        "[run ${task_rep}/${HOWMANY_TIMES}] ..."

    # Variables that hold data for the actual runs
    local tasks_cmds=()
    local tasks_cores=()
    local tasks_logfile=()
    local tasks_infile=()
    local tasks_outfile=()

    # Local variables for the following loop
    local tasks_count=0
    local task_cmd=
    local task_core=
    local task_logfile=
    local task_infile=
    local task_outfile=
    local task_core=

    # For each CPU, but no more tasks than requested,
    # prepare parameters for all tasks to start before
    # actually starting them
    for task_core in $(cpufreq_policy_cpu_list "$policy"); do
        if [ "$tasks_count" -ge "$HOWMANY_TASKS" ]; then
            break
        fi
        tasks_count=$((tasks_count + 1))

        task_infile="$(ramfs_current_infile ${tasks_count})"
        task_outfile="$(ramfs_current_outfile ${tasks_count})"
        task_logfile="$(ramfs_current_logfile_time ${tasks_count})"

        # Input files are all numbered symbolic links to the same input file.
        # This assumes homogeneous runs, for heterogeneous runs modify this.
        ln -fs "${ramfs_infile}" "${task_infile}"

        # Save lists of files managed in this run
        tasks_logfile+=("$task_logfile")
        tasks_infile+=("$task_infile")
        tasks_outfile+=("$task_outfile")

        # Command to execute
        task_cmd=$(task_command "${task_infile}")
        tasks_cmds+=("$task_cmd")

        # On which core
        tasks_cores+=("$task_core")

        # How to grep all running tasks
        # tasks_grep_pattern="$tasks_grep_pattern\|$task_cmd"
    done # foreach CPU

    # Cooldown between a test and the consecutive one
    # TODO: move at the bottom?
    wait_cooldown

    # Start the power sampler
    local sampler_logfile=
    local sampler_logfile_err=
    local sampler_pid

    sampler_logfile="$(ramfs_current_logfile_power)"
    sampler_logfile_err="$(ramfs_current_logfile_power_err)"

    # NOTE: do not move these commands to a function, it
    # will mess up the waits later!
    taskset -c "${POWERSAMPLER_CPUCORE}" \
        chrt -f 99 \
        ${POWERSAMPLER_CMD} \
        >"${sampler_logfile}" 2>"${sampler_logfile_err}" &

    sampler_pid="$!"

    # Start one by one all tasks
    local tasks_pids=()
    local index
    for ((index = 0; index < $tasks_count; ++index)); do
        task_cmd="${tasks_cmds[$index]}"
        task_core="${tasks_cores[$index]}"
        task_logfile="${tasks_logfile[$index]}"

        # NOTE: Assumes the time measuring command prints to stderr. The order
        # of these commands must remain like this in order for all experiments
        # to work (including the ones using SCHED_DEADLINE).
        taskset -c "$task_core" \
            $TIME_CMD \
            $HIGH_PRIO_CMD \
            $task_cmd \
            >/dev/null 2>"$task_logfile" &

        tasks_pids+=("$!")
    done

    # Wait a predetermined time
    wait_test_duration

    # Signal the power sampler to stop sending a SIGINT=2 signal
    kill -2 ${sampler_pid} &>/dev/null
    wait ${sampler_pid} # 2>/dev/null

    # Signal all tasks to stop
    terminate_all "300" "10" "${tasks_pids[@]}"

    # NOTE: If you ever notice tasks waiting for far too long and TIME_CMD is
    # `forever`, open a separate shell and type one of the following (first one
    # preferred):
    #  - pkill -2 forever
    #  - pkill -9 forever

    # Final check, script should NEVER hang here
    wait "${tasks_pids[@]}" || true # 2>/dev/null

    # Now all logfiles are still in the ramfs, we need to copy them back to disk

    # Create current test output directory
    local testdir="$(this_test_directory)"
    rm -rf "$testdir"
    mkdir -p "$testdir"

    # Copy back log files to disk
    cp "${sampler_logfile}" \
        "${sampler_logfile_err}" \
        "${tasks_logfile[@]}" \
        "$testdir"

    # Delete all output files
    # NOTE: Input files are assumed not to be modified! Is this always true??
    rm -f "${sampler_logfile}" "${sampler_logfile_err}" "${tasks_logfile[@]}" \
        "${tasks_outfile[@]}"
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
            if [ "$policy" = "$policy_forced" ]; then
                # Should not skip!
                return 1
            fi
        done

        # Should skip
        return 0
    fi

    # Should not skip
    return 1
}

# Returns whether the frequency should be skipped (i.e. not
# part of the "forced frequency list", if any) or not.
#
# Env variables:
#  - freq
function should_skip_frequency() {
    local freq_forced

    # First check if the list is provided
    if [ "${#EXP_FREQ_FORCED_LIST[@]}" -gt 0 ]; then
        # It is, then the frequency must be in the list
        for freq_forced in "${EXP_FREQ_FORCED_LIST[@]}"; do
            if [ "$freq" = "$freq_forced" ]; then
                # Should not skip!
                return 1
            fi
        done

        # Should skip
        return 0
    fi

    # Should not skip
    return 1
}

function load_conf_files() {
    for arg in "$@"; do
        if [ ! -f "$arg" ]; then
            pwarn "$arg is not a file! Skipping..."
            continue
        fi

        pinfo2 "Loading file $arg"
        . "$arg"
    done
}

function sort_and_lineup() {
    sort -n | tr '\n' ' '
}

(
    set -e

    # export PROJPATH
    # export SCRIPT_PATH
    # export CONFDIR
    # export APPSDIR

    PROJPATH="$(get_project_path '../..')"
    SCRIPT_PATH="$(get_script_path)"
    CONFDIR="${PROJPATH}/embedded/confdir"
    APPSDIR="${PROJPATH}/build/embedded/apps"

    # Importing functions and basic configuration
    . "${SCRIPT_PATH}/util/output.sh"
    . "${SCRIPT_PATH}/util/cpufreq.sh"
    . "${SCRIPT_PATH}/util/fix-trip-points.sh"
    . "${SCRIPT_PATH}/util/fakedata.sh"

    # Put tokens for default Telegram channel and your
    # chatID to get notified about the completion of your
    # runs! See
    # https://blog.bj13.us/2016/09/06/how-to-send-yourself-a-telegram-message-from-bash.html
    . "${SCRIPT_PATH}/util/telegram-tokens.sh" 2>/dev/null || true
    . "${SCRIPT_PATH}/util/telegram.sh"

    # Load base parameters
    . "${CONFDIR}/base/base.sh"

    # The tasks to be run typically are these, but they can
    # be overwritten with files in parameters
    . "${CONFDIR}/tasks/simple.sh"

    # Load custom parameters to substitute the ones in
    # base.sh from the specified file, if any
    pinfo1 "About to load configuration files provided via command line..."
    load_conf_files "$@"

    # Jump into output directory.
    mkdir -p "$EXP_BASE_DIR/howmany_${HOWMANY_TASKS}"
    cd "$EXP_BASE_DIR/howmany_${HOWMANY_TASKS}"

    # NOTE: this will NOT delete old data, old data is
    # overwritten only new data is actually written on top!

    pinfo1 'Printing experiment metadata'

    # Save experiment metadata and print them on the screen too
    # TODO: SAVE MORE METADATA!
    experiment_save_metadata "exp_metadata-${EXP_TITLE}.txt"
    cat "exp_metadata-${EXP_TITLE}.txt"

    pinfo1 'Rebuilding applications'

    # Rebuild binaries if necessary
    "${PROJPATH}/embedded/build.sh"

    # DO NOT MOVE: This command is necessary to run
    # correctly RT applications, if any!
    sysctl -w kernel.sched_rt_runtime_us=-1 >/dev/null

    # Get the command to run tasks with high priority
    HIGH_PRIO_CMD=$(high_prio_kind_to_cmd)

    pinfo_newline
    pinfo1 'Generating fake data for the experiment'
    generate_fakedata_ondisk
    create_ramfs "$ramfs_path" "$ramfs_size"

    # Create necessary directories
    mkdir -p "$ramfs_datapath"
    mkdir -p "$ramfs_logpath"

    trip_points_force_fan

    pinfo1 'Experiment will begin in 30 seconds...'

    # Unplug everything now
    # sleep 30s

    pinfo1 'Experiment will begin NOW!'

    policy_list=$(cpufreq_policy_list | sort_and_lineup)

    pinfo2 'List of policies available:' "$policy_list"

    #------------------------------------------------------#
    #------------------- FOREACH POLICY -------------------#
    #------------------------------------------------------#

    policy=
    policy_other=
    for policy in $policy_list; do
        if should_skip_policy; then
            pinfo1 "Skipping policy $policy"
            continue
        fi

        # Get a policy different than the current one (it
        # may remain the same one, but it's okay in that
        # case, we at least try)
        if [ -z "$policy_other" -o "$policy_other" = "$policy" ]; then
            policy_other=$(cpufreq_policy_find_another "$policy")
        fi

        pinfosay1 "Selected CPU Island is ${policy}"
        pinfosay2 "Other CPU Island is ${policy_other}"

        #--------------------------------------------------#
        #-------- TASKSET SCRIPT AND POWER SAMPLER --------#
        #--------------------------------------------------#

        # NOTE: using a core on the same island if the system has only one
        # island available (it is inevitable). In that case, only the last core
        # of that island will be used (should not affect significantly
        # experiments with less concurrent tasks than the number of cores per
        # island...)

        # NOTE: we no longer start stress tasks on the other policy

        # Select the core on which the power sensor will run
        # as the last one in policy_other.
        readarray -t CPU_OTHER_LIST <<<"$(cpufreq_policy_cpu_list "$policy_other")"
        POWERSAMPLER_CPUCORE=${CPU_OTHER_LIST[${#CPU_OTHER_LIST[@]} - 1]}
        SCRIPT_CPUCORE=$POWERSAMPLER_CPUCORE

        # TODO: how about having a "fake" policy that instead includes all cores
        # that are NOT in the current policy?

        # There is room for more use it
        if [ "$policy_other" != "$policy" ] && [ "${#CPU_OTHER_LIST[@]}" -gt 1 ]; then
            SCRIPT_CPUCORE=${CPU_OTHER_LIST[${#CPU_OTHER_LIST[@]} - 2]}
        fi

        if [ "$SCRIPT_CPUCORE" = "$POWERSAMPLER_CPUCORE" ]; then
            pwarn "Running the experiment script on the same core as the power sampler!"
        fi

        # Move the current script to another core
        # NOTICE: USING BOTH $BASHPID AND $$ BECAUSE THIS SCRIPT IS TECHNICALLY
        # INSIDE A SUBSHELL!
        taskset -c -p "${SCRIPT_CPUCORE}" $$ &>/dev/null
        taskset -c -p "${SCRIPT_CPUCORE}" ${BASHPID} &>/dev/null

        #--------------------------------------------------#
        #--------- PREPARE POLICY AND FREQURENCY ----------#
        #--------------------------------------------------#

        # Prepare CPU policies for manual frequency switching
        pwarn "If you see an error message here, but the script keeps going," \
            "don't panic. It's all good."

        if cpufreq_governor_setall "performance" ||
            cpufreq_governor_setall "userspace"; then
            # All good
            :
        else
            perr 'NEITHER performance NOR userspace GOVERNORS SUPPORTED!'
            perr 'Run will terminate now.'
            false
        fi

        # Use the commented command to set the other policies to the maximum
        # instead of the minimum frequency.
        cpufreq_policy_frequency_minall
        # cpufreq_policy_frequency_maxall

        policy_frequencies="$(cpufreq_policy_frequency_list "$policy" | sort_and_lineup)"

        pinfo1 "Policy $policy supported frequencies: $(format_frequency $policy_frequencies)"

        #--------------------------------------------------#
        #--------------- FOREACH FREQUENCY ----------------#
        #--------------------------------------------------#

        # For each frequency available for all its cores at once
        for freq in $policy_frequencies; do
            if should_skip_frequency; then
                pinfo1 "Skipping frequency $(format_frequency $freq)"
                continue
            fi

            pinfosay1 "Selected frequency $(format_frequency $freq)"

            # Set the desired frequency for the given policy
            cpufreq_policy_frequency_set "$policy" "$freq"

            # This line will be deleted by the print inside the single test run
            # pinfo_newline

            #----------------------------------------------#
            #---------------- FOREACH TASK ----------------#
            #----------------------------------------------#
            for ((task_index = 0; task_index < ${#TASKS_CMD[@]}; ++task_index)); do
                task_name=${TASKS_NAME[$task_index]}
                infile_size=$((EXP_TASK_MIN_DURATION * TASKS_FILESIZE_RATIO[task_index]))

                # Create the directory to hold the data in the ramfs
                mkdir -p "${ramfs_datapath}"

                # Copy if necessary a new (fake) data file in the desired path
                # from disk
                copy_fakedata_inram "${ramfs_infile}" "${infile_size}"

                # FIXME: some commands may require the data as input to be a
                # certain format! If so, make a call here to support that!

                # Drop caches before the 0-execution only, then keep the data in
                # ram for all subsequent runs
                sync
                echo 1 >/proc/sys/vm/drop_caches

                # Repeat the test multiple times (with a 0 run too, which shall
                # be ignored later!)
                for ((task_rep = 0; task_rep <= "${HOWMANY_TIMES}"; ++task_rep)); do
                    run_a_test

                    # FIXME: if for certain commands some restoration actions
                    # are to be performed on the input file, do it here. But
                    # restoation means that the command modifies its input file,
                    # that is a much bigger issue for the way we handle
                    # homogeneous tests (all the input files are the same file
                    # with multiple symbolic links)!
                done # FOREACH REPETITION
            done     # FOREACH TASK
        done         # FOREACH FREQUENCY
    done             # FOREACH POLICY

    notify_termination
)

if [ "$(cat "$success_file")" != 'OK' ]; then
    notify_premature_termination
    rm "$success_file"
    false
else
    rm "$success_file"
fi
