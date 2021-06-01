#!/bin/bash

# TODO: add custom hooks to generate more kinds of fake data
# (e.g. encrypted data for the decrypt commandf)

export FAKEDATA_DIR="$HOME/.fakedata"

# Arguments:
# 1. File path to check
# 2. Expected size in MB of of the file (only number)
function test_file_size_mb() {
    local filepath
    local filesize
    local expected_bytes
    local filesize_bytes

    filepath="$1"
    filesize="$2"
    expected_bytes=$((filesize * 1024 * 1024))
    filesize_bytes=$(stat --printf="%s" "$filepath")

    [ $expected_bytes = $filesize_bytes ]
}

# Create fakedata files on disk in the designated directory if they do not exist
# Uses environment variables:
#  - FAKEDATA_DIR       Path of the fakedata directory on disk
#  - TASKS_NAME         The list of task names for this experiment
#  - EXP_TASK_MIN_DURATION The minimum duration of the experiment
#  - TASKS_FILESIZE_RATIO An approximation of a ratio at which the program
#                       consumes data over time at the highest frequency
function generate_fakedata_ondisk() {
    local task_index
    local task_name
    local task_fileratio
    local filesize
    local filename
    local filediskpath
    local should_create_file

    mkdir -p "$FAKEDATA_DIR"

    # For each task in the taskset
    for ((task_index = 0; task_index < ${#TASKS_NAME[@]}; task_index++)); do
        task_name="${TASKS_NAME[$task_index]}"
        task_fileratio="${TASKS_FILESIZE_RATIO[task_index]}"

        # We create a file on disk (which will then be copied in /tmp later).
        # Files are created only once and then reused for future experiments.

        # Files like this are used to force certain tasks to have something to
        # process for a while.

        filesize=$((EXP_TASK_MIN_DURATION * task_fileratio))
        filename="fakedata-$filesize"
        filediskpath="$FAKEDATA_DIR/$filename"

        # File exists?
        if [ -f "$filediskpath" ]; then
            if test_file_size_mb "$filediskpath" "$filesize"; then
                should_create_file=0
            else
                should_create_file=1
            fi
        else
            # File does not exist
            should_create_file=1
        fi

        if [ "$should_create_file" != 1 ]; then
            pinfo2 "File $filediskpath already exists with the right size!"
        else
            pinfo2 "Creating a $filesizeMB file in $filediskpath"
            head -c "${filesize}M" /dev/urandom >"$filediskpath"
        fi
    done
}

# Create location for the ramfs in the filesystem
# Arguments:
#  1. Path in which the ramfs will be mounted
#  2. Size in MB (only number)
function create_ramfs() {
    local ramfs_path
    local ramfs_size

    ramfs_path="$1"
    ramfs_size="$2"M

    mkdir -p "$ramfs_path"
    umount "$ramfs_path" &>/dev/null || true
    mount -t tmpfs -o size="$ramfs_size" tmpfs "$ramfs_path"
}

# Copies files from disk to ram (but only if needed)
# Assumes all files are created using the generate_fakedata_ondisk
#
# Arguments:
#  1. File path in ramfs
#  2. Desired size in MB (number only)
function copy_fakedata_inram() {
    local file_inram
    local file_ondisk
    local file_desired_size
    local should_copy
    local silent

    file_inram="$1"
    file_desired_size="$2"
    silent="$3"

    if [ -f "$file_inram" ]; then
        if test_file_size_mb "$file_inram" "$file_desired_size"; then
            should_copy=0
        else
            should_copy=1
        fi
    else
        should_copy=1
    fi

    if [ "$should_copy" = 1 ]; then
        if [ -z "$silent" ]; then
            pinfo2 "Copying a ${file_desired_size}MB file in ramfs..."
        fi
        file_ondisk="${FAKEDATA_DIR}/fakedata-${file_desired_size}"
        cp "$file_ondisk" "$file_inram"
    else
        if [ -z "$silent" ]; then
            pinfo_newline
        fi
    fi
}

function prepare_fakedata() {
    sync
    echo 1 >/proc/sys/vm/drop_caches

    # Re-copy the fake file in tmp if the size is not already the right one
    FILESIZE=$((EXP_TASK_MIN_DURATION * TASKS_FILESIZE_RATIO[task_index]))
    if [ "$FILESIZE" -ne "$FILESIZE_PREVIOUS" ]; then
        tput cuu 1 && tput el
        pinfo2 "Copying a ${FILESIZE}M file in /fakedata/fakedata "
        cp "${FAKEDATA_DIR}/fakedata-${FILESIZE}" /fakedata/fakedata
        # pv "${FAKEDATA_DIR}/fakedata-${FILESIZE}" >/fakedata/fakedata
        tput cuu 1 && tput el
    fi
    FILESIZE_PREVIOUS=$FILESIZE

    sync
    echo 1 >/proc/sys/vm/drop_caches
}

# ============================================================================ #
#                                  OLD  STUFF                                  #
# ============================================================================ #

# function generate_fakedata() {
#     # Create directory if it does not exist
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
#             echo "----> Creating a ${FILESIZE}M file in ${FAKEDATA_DIR}/fakedata-${FILESIZE} "
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
