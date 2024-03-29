# Following is the list of the tasks to be started.
# The numbers included here are not to be modified by hand freely.
# Use the EXP_TASK_MIN_DURATION parameter to modify the duration of each task,
# but notice that the resulting execution time may not be very precise (+- 1 or 2 seconds).

# The TASKS_CMD, TASKS_NAME and TASKS_FILESIZE_RATIO should be filled with data for each task

TASKS_NAME=()
TASKS_CMD=()
TASKS_FILESIZE_RATIO=()

# TODO: infile/outfile shenanigans

TASKS_NAME+=("hash")
TASKS_CMD+=("sha256sum INFILE")
TASKS_FILESIZE_RATIO+=(90)

TASKS_NAME+=("gzip-9")
TASKS_CMD+=("gzip -kqf -9 INFILE -S .OUTFILE_EXT")
TASKS_FILESIZE_RATIO+=(90)

TASKS_NAME+=("encrypt")
TASKS_CMD+=("openssl des3 -e -in INFILE -out INFILE.OUTFILE_EXT -pbkdf2 -pass pass:abcdefghijk") # Not tested with deadline
TASKS_FILESIZE_RATIO+=(90)

TASKS_NAME+=("decrypt")
TASKS_CMD+=("openssl des3 -d -in INFILE -out INFILE.OUTFILE_EXT -pbkdf2 -pass pass:abcdefghijk") # Not tested with deadline
TASKS_FILESIZE_RATIO+=(90)

### Brief Explanation
# The TASKS_FILESIZE_RATIO is used to calculate the size of the file to process.
# The value should be calculated using a few test runs using the fastest
# frequency on the most powerful core so that each task can run at least for
# the desired EXP_TASK_MIN_DURATION number of seconds.
#
# The file size will then  be used to "enforce" a certain task duration when
# running at maximum frequency on the most powerful core
