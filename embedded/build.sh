#!/bin/bash

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

function install_deps_apt() {
    sudo apt update
    sudo apt install -y build-essential cmake
    sudo apt install -y libudev-dev || true
}

(
    set -e

    if ! type cmake >/dev/null; then
        if type apt >/dev/null; then
            install_deps_apt
        else
            echo "ERROR! Not a supported distro detected!"
            echo "Please contact support."
            false
        fi
    fi

    PROJ_PATH=$(get_project_path "..")
    ORIGINAL_PATH="$(realpath "${PROJ_PATH}/embedded")"
    BUILD_PATH="${PROJ_PATH}/build/embedded"

    mkdir -p "$BUILD_PATH"
    cmake -S "$ORIGINAL_PATH" -B "$BUILD_PATH"
    make -C "$BUILD_PATH"

    # NOTE: final executable locations
    # ${BUILD_PATH}/cacheapp/cachekiller
    # ${BUILD_PATH}/cacheapp/cachesaver
    # ${BUILD_PATH}/cacheapp/cachestress
    # ${BUILD_PATH}/sampler/sampler
)
