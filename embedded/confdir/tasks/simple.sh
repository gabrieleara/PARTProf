# Following is the list of the tasks to be started.
# The numbers included here are not to be modified by hand freely.
# Use the EXP_TASK_MIN_DURATION parameter to modify the duration of each task,
# but notice that the resulting execution time may not be very precise (+- 1 or 2 seconds).

# The TASKS_CMD, TASKS_NAME and TASKS_FILESIZE_RATIO should be filled with data for each task

TASKS_NAME=()
TASKS_CMD=()
TASKS_FILESIZE_RATIO=()

TASKS_NAME+=("hash")
TASKS_CMD+=("sha256sum INFILE")
TASKS_FILESIZE_RATIO+=(90)

# for ((i = 1; i <= 9; i += 4)); do
#     TASKS_NAME+=("gzip-$i")
#     TASKS_CMD+=("gzip -kqf -$i INFILE -S .OUTFILE_EXT")
#     TASKS_FILESIZE_RATIO+=(13)
# done

TASKS_NAME+=("gzip")
TASKS_CMD+=("gzip -kqf INFILE -S .OUTFILE_EXT")
TASKS_FILESIZE_RATIO+=(13)

TASKS_NAME+=("encrypt")
TASKS_CMD+=("openssl des3 -e -in INFILE -out INFILE.OUTFILE_EXT -pbkdf2 -pass pass:abcdefghijk") # Not tested with deadline
TASKS_FILESIZE_RATIO+=(14)

TASKS_NAME+=("decrypt")
TASKS_CMD+=("openssl des3 -d -in INFILE -out INFILE.OUTFILE_EXT -pbkdf2 -pass pass:abcdefghijk") # Not tested with deadline
TASKS_FILESIZE_RATIO+=(14)

# CACHEKILLER_IT=$((22000000 * EXP_TASK_MIN_DURATION))

# TASKS_NAME+=("cachekiller")
# TASKS_CMD+=("$APPSDIR/cacheapp/cachekiller ${CACHEKILLER_IT}")
# TASKS_FILESIZE_RATIO+=(0)

# Generate a command for each of these data cache miss percentages
# These numbers are to be used for 1s experiments, they will be multiplied accordingly for longer durations
# MISS_PERCENTAGES=(0 20 40 60 80 100)
# MISS_ITERATIONS=(220000000 154000000 66000000 38000000 26200000 20000000)

MISS_PERCENTAGES=(0 50 100)
MISS_ITERATIONS=(220000000 45000000 20000000)

i=0
for i in $(seq 1 ${#MISS_PERCENTAGES[@]}); do
    Rm=${MISS_PERCENTAGES[$i - 1]}
    it=${MISS_ITERATIONS[$i - 1]}

    it=$((it * EXP_TASK_MIN_DURATION))

    TASKS_NAME+=("cacherate-$Rm")
    TASKS_CMD+=("$APPSDIR/cacheapp/cachestress $it $Rm")
    TASKS_FILESIZE_RATIO+=(0)
done

TASKS_NAME+=("idle")
TASKS_CMD+=("sleep ${EXP_TASK_MIN_DURATION}s")
TASKS_FILESIZE_RATIO+=(0)

### Brief Explanation
# The TASKS_FILESIZE_RATIO is used to calculate the size of the file to process.
# The value should be calculated using a few test runs using the fastest
# frequency on the most powerful core so that each task can run at least for
# the desired EXP_TASK_MIN_DURATION number of seconds.
#
# The file size will then  be used to "enforce" a certain task duration when
# running at maximum frequency on the most powerful core
