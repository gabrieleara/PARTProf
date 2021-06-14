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

# ------------------ OPTIONS MANAGEMENT ------------------ #

# Separates options from positional arguments, saving each
# of them into opt_args and pos_args respectively
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
        pos_args+=("$1")
        shift || true
    done
}

# -------------------------------------------------------- #

function usage() {
    cat <<EOF
usage: $0 [options] CMD DISKPATH

Perform CMD command on the path identified by DISKPATH.

Saves the whole content of DISKPATH as a compressed binary archive in the
desired output file.

List of options for all commands (optional):
  -h, --help        Prints this help message and returns.
  -n, --dry-run     Prints out all commands but does not execute them.

List of commands (only one at a time):
    help            Prints this help message and returns.
    backup          Backups the content of the provided DISKPATH to an image.
    burn            Burn an image on DISKPATH.

List of options for BACKUP command:
  -c, --compress    Performs a compression operation using XZ on DISKPATH
                    content and saves the compressed content only on disk.
  -o, --output  OUTFILE
                    The output image name. Default: out.img OR out.img.xz

List of options for BURN command:
  -i, --input  INFILE
                    The output archive name. Default: in.img

NOTICE: options that do not belong to the provided command will be ignored.

EOF
}

# Converts long options to corresponding short ones.
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
        --input)
            printf ' %s' "-i"
            ;;
        --compress)
            printf ' %s' "-c"
            ;;
        *)
            printf ' %s' "$1"
            ;;
        esac

        shift
    done
}

# Converts opt_args to corresponding flags and variables. The special variable
# usage_exitcode specifies the exit code to use if printing the usage message.
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
            cmd_to_run=help
            return
            ;;
        n)
            dry_run=1
            ;;
        c)
            compress=1
            ;;
        o)
            if [ -z "$OPTARG" ]; then
                cmd_to_run=help
                return 1
            fi
            outfile="$OPTARG"
            default_outfile=0
            ;;
        i)
            if [ -z "$OPTARG" ]; then
                cmd_to_run=help
                return 1
            fi
            infile="$OPTARG"
            default_infile=0
            ;;

        *)
            printf "ERR: unrecognized option '-%s'.\n\n" "$OPTION" >&2
            cmd_to_run=help
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

    if [ "$default_outfile" = 1 ] && [ "$compress" = 1 ]; then
        outfile="$outfile".xz
    fi
}

# Parses positional arguments and fills corresponding variables
function parse_pos_args() {
    cmd_to_run="${pos_args[0]}"
    disk_path="${pos_args[1]}"

    if [ "$cmd_to_run" = 'help' ]; then
        usage_exitcode=0
    elif [ -z "$cmd_to_run" ] || [ -z "$disk_path" ]; then
        printf "ERR: missing required argument.\n\n" >&2
        cmd_to_run=help
        usage_exitcode=1
    fi
}

# -------------------------------------------------------- #

function run_or_dry_run() {
    local the_command=()
    the_command=("$@")

    # Note: must use bash -c to avoid problems with quoting
    if [ "$dry_run" = 1 ]; then
        echo "(DRY RUN) Command: ${the_command[*]}"
    else
        bash -c "${the_command[@]}"
    fi
}

# -------------------------------------------------------- #

function check_disk() {
    if [ ! -b "$disk_path" ]; then
        echo "The provided path $disk_path is not a block device!" >&2
        return 1
    fi
}

function umount_disk() {
    printf '%s\n' 'About to unmount the device...'
    for d in "${disk_path}"*; do
        if [ "$dry_run" = 1 ]; then
            echo "(DRY RUN) Command:" sudo umount "$d" \|\| true
        else
            sync
            sudo umount "$d" || true

            # local tmpfile
            # tmpfile=$(mktemp)
            # sync
            # if ! sudo umount "$d" >/dev/null 2>"$tmpfile"; then
            #     # Mount could fail just because the device is not mounted, in that case it's fine
            #     if ! grep "$tmpfile" -i -e 'no such file or directory' &>/dev/null ; then
            #         cat "$tmpfile" >&2
            #         return 1
            #     fi
            # fi
            # rm -f "$tmpfile"
        fi
    done

    printf '%s\n' 'Unmounted!'

}

function burn_sd() {
    printf '%s\n' 'Beginning to write to disk.'
    printf '%s\n' 'Please wait, this takes some time, a progress will be shown...'

    if [ "$compress" = 1 ]; then
        printf '%s\n' 'NOTE: you enabled compression.'

        if [ "$dry_run" = 1 ]; then
            printf '(DRY RUN) Command: %s\n' \
                "xzcat '$infile' | sudo dd of='$disk_path' bs=4M status=progress"
        else
            time (
                sync
                xzcat "$infile" | sudo dd of="$disk_path" bs=4M status=progress
                sync
            )
        fi
    else
        if [ "$dry_run" = 1 ]; then
            printf '(DRY RUN) Command: %s\n' \
                "sudo dd if='$infile' of='$disk_path' bs=4M status=progress"
        else
            time (
                sync
                sudo dd if="$infile" of="$disk_path" bs=4M status=progress
                sync
            )
        fi
    fi

    sync

    printf 'Write completed successfully, burned on %s.\n' "$disk_path"
}

function backup_sd() {
    printf '%s\n' 'Beginning to read from disk.'
    printf '%s\n' 'Please wait, this takes some time, a progress will be shown...'

    if [ $compress = 1 ]; then
        printf '%s\n' 'NOTE: you enabled compression.'

        if [ "$dry_run" = 1 ]; then
            printf '(DRY RUN) Command: %s\n' \
                "sudo dd if='$disk_path' bs=4M status=progress | xz >'$outfile'"
        else
            time sudo dd if="$disk_path" bs=4M status=progress | xz >"$outfile"
        fi

    else
        if [ "$dry_run" = 1 ]; then
            printf '(DRY RUN) Command: %s\n' \
                "sudo dd if='$disk_path' bs=4M status=progress"
        else
            time sudo dd if="$disk_path" bs=4M status=progress
        fi
    fi

    sync

    printf 'Read completed successfully, saved to %s.\n' "$outfile"
}

# -------------------------------------------------------- #

(
    set -e

    # path_proj="$(get_project_path "..")"
    # path_embedded="$(realpath "${path_proj}/embedded")"
    # path_host="$(realpath "${path_proj}/host")"
    # path_pyscripts="${path_host}/pyscripts"

    optstring="hnco:i:"

    # Optional arguments
    usage_exitcode=0
    disk_path=
    dry_run=0
    usage_exitcode=
    outfile=out.img
    infile=in.img
    default_outfile=1
    default_infile=1

    OPTERR=0

    # Separate optional from positional arguments, then parse them
    separate_args "$optstring" $(toshortopts "$@")
    parse_opt_args "$optstring" "${opt_args[@]}"

    if [ "$cmd_to_run" != 'help' ]; then
        parse_pos_args
    fi

    exit_code=0
    case "$cmd_to_run" in
    help)
        usage
        exit_code="$usage_exitcode"
        ;;
    backup)
        check_disk
        umount_disk
        backup_sd
        ;;
    burn)
        check_disk
        umount_disk
        burn_sd
        ;;
    *)
        printf 'Unknown command "%s"!\n' "$cmd_to_run" >&2
        exit_code=1
        ;;
    esac

    if [ "$exit_code" = 1 ]; then
        false
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
# time sudo dd if=/dev/r$DSK bs=4M | gzip -9 >$OUTDIR/Piback.img.gz

# #rename to current date
# echo compressing completed - now renaming
# mv -n $OUTDIR/Piback.img.gz $OUTDIR/$BACKUPNAME$(date +%Y%m%d).img.gz
