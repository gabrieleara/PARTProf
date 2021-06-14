#!/bin/bash

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

# -------------------------------------------------------- #

function usage() {
    cat <<EOF
usage: $0 [options] DISKPATH

Saves the whole content of DISKPATH as a compressed binary archive in the
desired output file.

List of options (all optional):
  -h, --help        Prints this help message and returns with an error.
  -n, --dry-run     Prints out all commands but does not execute them.
  -o, --output  OUTFILE
                    The output archive name. Default: out.gzip
EOF
}

opt_args=()
pos_args=()

function toshortopts() {
    while [ $# -gt 0 ]; do
        case "$1" in
        --help)
            printf ' %s' "-h"
            ;;
        --dry-run)
            printf ' %s' "-n"
            ;;
        --output)
            printf ' %s' "-o"
            ;;
        *)
            printf ' %s' "$1"
            ;;
        esac

        shift
    done
}

function separate_args() {
    local optstring="$1"
    local OPTION
    shift

    opt_args=()
    pos_args=()

    while [ $# -gt 0 ]; do
        unset OPTIND
        unset OPTARG
        unset OPTION
        while getopts ":$optstring" OPTION; do
            if [ "$OPTION" != : ]; then
                opt_args+=("-$OPTION")
            else
                OPTARG="-$OPTARG"
            fi

            if [ ! -z "$OPTARG" ]; then
                opt_args+=("$OPTARG")
            fi

            unset OPTARG
        done

        shift $((OPTIND - 1)) || true
        pos_args+=($1)
        shift || true
    done
}

function parse_opt_args() {
    local optstring="$1"
    local OPTION
    shift

    unset OPTIND
    unset OPTARG
    unset OPTION
    while getopts "$optstring" OPTION; do
        case $OPTION in
        h)
            usage
            help_exit=1
            return
            ;;
        n)
            dry_run=1
            ;;
        o)
            if [ -z "$OPTARG" ]; then
                usage
                return 1
            fi
            outfile="$OPTARG"
            ;;
        *)
            printf "ERR: unrecognized option '-%s'.\n\n" "$OPTION" >&2
            usage
            return 1
            ;;
        esac
        unset OPTARG
    done

    # Too many options/unrecognized options
    shift $((OPTIND - 1)) || true
    if [ "$#" -gt 0 ]; then
        printf "ERR: unrecognized options.\n\n" >&2
        usage
        return 1
    fi
}

function parse_pos_args() {
    disk_path="${pos_args[0]}"
    if [ -z "$disk_path" ]; then
        printf "ERR: missing required argument.\n\n" >&2
        usage
        return 1
    fi
}

function run_or_dry_run() {
    local the_command
    the_command="$@"

    # Note: must use bash -c to avoid problems with quoting
    if [ "$dry_run" = 1 ]; then
        echo "(DRY RUN) Command: $the_command"
    else
        bash -c "$the_command"
    fi
}

(
    set -e

    path_proj="$(get_project_path "..")"
    path_embedded="$(realpath "${path_proj}/embedded")"
    path_host="$(realpath "${path_proj}/host")"
    path_pyscripts="${path_host}/pyscripts"

    optstring="hno:"

    # Optional arguments
    help_exit=0
    disk_path=
    dry_run=0
    help_exit=
    outfile=out.gzip

    OPTERR=0

    # Separate optional from positional arguments, then parse them
    separate_args "$optstring" $(toshortopts "$@")
    parse_opt_args "$optstring" "${opt_args[@]}"

    if [ "$help_exit" != 1 ]; then
        parse_pos_args

        if [ ! -b "$disk_path" ]; then
            echo "The provided path $disk_path is not a block device!" >&2
            false
        fi

        echo "About to unmount the device!"
        sync
        for d in "${disk_path}"*; do
            if [ "$dry_run" = 1 ]; then
                echo "(DRY RUN) Command:" sudo umount "$d" \|\| true
            else
                sudo umount "$d" || true
            fi

        done

        echo 'Unmounted!'
        echo 'Beginning to read and compress.'
        echo 'Please wait, this takes some time...'
        # echo 'Use Ctl+T to show progress!'

        if [ "$dry_run" = 1 ]; then
            echo "(DRY RUN) Command:" sudo dd if="$disk_path" bs=4m \| gzip -9 \>"$outfile"
        else
            time sudo dd if="$disk_path" bs=4M status=progress >"$outfile" # |
                # gzip -9 >"$outfile"
        fi

        echo 'Compressing completed successfully!'
    fi

)

# #!/bin/bash
# # script to backup Pi SD card
# # 2017-06-05
# # 2018-11-29    optional name
# # DSK='disk4'   # manual set disk
# OUTDIR=~/temp/Pi

# # Find disk with Linux partition (works for Raspbian)
# # Modified for PINN/NOOBS
# export DSK=$(diskutil list | grep "Linux" | sed 's/.*\(disk[0-9]\).*/\1/' | uniq)
# if [ $DSK ]; then
#     echo $DSK
#     echo $OUTDIR
# else
#     echo "Disk not found"
#     exit
# fi

# if [ $# -eq 0 ]; then
#     BACKUPNAME='Pi'
# else
#     BACKUPNAME=$1
# fi
# BACKUPNAME+="back"
# echo $BACKUPNAME

# diskutil unmountDisk /dev/$DSK
# echo please wait - This takes some time
# echo Ctl+T to show progress!
# time sudo dd if=/dev/r$DSK bs=4m | gzip -9 >$OUTDIR/Piback.img.gz

# #rename to current date
# echo compressing completed - now renaming
# mv -n $OUTDIR/Piback.img.gz $OUTDIR/$BACKUPNAME$(date +%Y%m%d).img.gz
