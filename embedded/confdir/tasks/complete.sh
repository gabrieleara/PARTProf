# This file contains a list of tasks that will be used to
# profile the behavior of typical applications on the target
# system.

# These three variables are arrays to which each task is
# appended by setting its user-friendly name, the command
# line to use and the dimension of the file to use with
# respect to a base value set in the basic test
# configuration.

# This base value is the EXP_TASK_MIN_DURATION parameter, so
# basically each file size is determined so that the minimum
# task duration will more or less match the expected value.
# Notice that the resulting execution time may not be very
# precise (+- 1 or 2 seconds with respect to the expected
# value, the bigger it is the bigger the error).

# In the task command line, INFILE, and OUTFILE_EXT are
# special words that will be substituted during each rune to
# specify which input/output file to use.

# If a file has no need for an input or output files, simply
# do not put an INFILE in the command line and set its
# FILESIZE_RATIO to 0

TASKS_NAME=()
TASKS_CMD=()
TASKS_FILESIZE_RATIO=()

# -------------------------------------------------------- #
#                           IDLE                           #
# -------------------------------------------------------- #

TASKS_NAME+=("idle")
TASKS_CMD+=("sleep ${EXP_TASK_MIN_DURATION}s")
TASKS_FILESIZE_RATIO+=(0)

# -------------------------------------------------------- #
#                       SIMPLE TASKS                       #
# -------------------------------------------------------- #

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

# NOTE: encrypt and decrypt are not tested with deadline scheduler yet!
TASKS_NAME+=("encrypt")
TASKS_CMD+=("openssl des3 -e -in INFILE -out INFILE.OUTFILE_EXT -pbkdf2 -pass pass:abcdefghijk")
TASKS_FILESIZE_RATIO+=(14)

## FIXME: decrypt does not work as of now!
# TASKS_NAME+=("decrypt")
# TASKS_CMD+=("openssl des3 -d -in INFILE -out INFILE.OUTFILE_EXT -pbkdf2 -pass pass:abcdefghijk")
# TASKS_FILESIZE_RATIO+=(14)

# -------------------------------------------------------- #
#                     CACHE STRESSORS                      #
# -------------------------------------------------------- #

# NOTE: the behavior of all cache stressors with miss rate
# above 20% is more or less the same on most platforms with
# respect to each other, that's why we set more values
# between 0-20 than between 20-100.

# 0   = never miss
# 100 = always miss*

# *The actual miss rate depends on a number of factors,
# including the fact that the instruction cache never
# actually misses. What we are measuring here is the miss
# rate in data cache for a specific instruction that
# constitutes the body of the main loop.

# NOTE: The number of iterations is used here similarly to
# the FILESIZE_RATIO parameter and they should indicate how
# many iterations are needed at the highest frequency on the
# fastest core to run the application for 1 second.

MISS_PERCENTAGES=(0 5 10 20 60 100)
MISS_ITERATIONS=(220000000 200000000 180000000 155000000 60000000 20000000)

# DO NOT TOUCH FROM HERE

i=0
for i in $(seq 1 ${#MISS_PERCENTAGES[@]}); do
    Rm=${MISS_PERCENTAGES[$i - 1]}
    it=${MISS_ITERATIONS[$i - 1]}

    it=$((it * EXP_TASK_MIN_DURATION))

    TASKS_NAME+=("cachemissrate-$Rm")
    TASKS_CMD+=("$APPSDIR/cacheapp/cachestress $it $Rm")
    TASKS_FILESIZE_RATIO+=(0)
done
# DO NOT TOUCH UNTIL HERE

# -------------------------------------------------------- #
#                   STRESS-NG STRESSORS                    #
# -------------------------------------------------------- #

STRESS_NG_CPU_MET=(
    crc16
    dither
    fft
    matrixprod
)

# Number of iterations for a stress-ng stressor to run for one second
STRESS_NG_CPU_ITER=(
    67
    85
    350
    52
)

for i in $(seq 1 ${#STRESS_NG_CPU_MET[@]}); do
    Mt="${STRESS_NG_CPU_MET[i - 1]}"
    It="${STRESS_NG_CPU_ITER[i - 1]}"
    It=$((It * EXP_TASK_MIN_DURATION))

    TASKS_NAME+=("ng-$Mt")
    TASKS_CMD+=("stress-ng --cpu 1 --cpu-method $Mt --cpu-ops $It")
    TASKS_FILESIZE_RATIO+=(0)
done
