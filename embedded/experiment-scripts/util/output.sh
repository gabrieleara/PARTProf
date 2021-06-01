#!/bin/bash

# -------------------------------------------------------- #
#         output formatting functions and utilities        #
# -------------------------------------------------------- #

# ---------------------- Constants ----------------------- #

# Format
FBold='\e[1m'
FDim='\e[2m'
FUnderlined='\e[4m'
FBlink='\e[5m'
FNormalInverted='\e[7m'
FHidden='\e[8m'

# Reset formatting
RNormal='\e[0m'
RBold='\e[21m'
RDim='\e[22m'
RUnder='\e[24m'
RBlink='\e[25m'
RInverted='\e[27m'
RHidden='\e[28m'

# Colors
CDefault='\e[39m'
CBlack='\e[30m'
CRed='\e[31m'
CGreen='\e[32m'
CYellow='\e[33m'
CBlue='\e[34m'
CMagenta='\e[35m'
CCyan='\e[36m'
CLGray='\e[37m'
CGray='\e[90m'
CLRed='\e[91m'
CLGreen='\e[92m'
CLYellow='\e[93m'
CLBlue='\e[94m'
CLMagenta='\e[95m'
CLCyan='\e[96m'
CWhite='\e[97m'

# Background colors not used

# --------------------- Check output --------------------- #

# DISABLE ALL FORMATTING IF OUTPUTING TO A NON-TERMINAL
if [ ! -t 1 ]; then

    # Format
    FBold=''
    FDim=''
    FUnderlined=''
    FBlink=''
    FNormalInverted=''
    FHidden=''

    # Reset formatting
    RNormal=''
    RBold=''
    RDim=''
    RUnder=''
    RBlink=''
    RInverted=''
    RHidden=''

    # Colors
    CDefault=''
    CBlack=''
    CRed=''
    CGreen=''
    CYellow=''
    CBlue=''
    CMagenta=''
    CCyan=''
    CLGray=''
    CGray=''
    CLRed=''
    CLGreen=''
    CLYellow=''
    CLBlue=''
    CLMagenta=''
    CLCyan=''
    CWhite=''
fi

# --------------- Configuration variables ---------------- #

CInfo="${CLBlue}"
CDebug="${CGreen}"
CError="${CRed}"
CWarn="${CYellow}"

LEVEL_1='==>'
LEVEL_2='---->'

# ---------------------- Functions ----------------------- #

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
    printf "${CInfo}"
    print_msg "$@"
    printf "${CDefault}"
}

function pinfosay() {
    pinfo "$@"
    say "$@" 2>/dev/null || true
}

function pinfo1() {
    pinfo "${LEVEL_1}" "$@"
}

function pinfo2() {
    pinfo "${LEVEL_2}" "$@"
}

function pinfosay1() {
    pinfosay "${LEVEL_1}" "$@"
}

function pinfosay2() {
    pinfosay "${LEVEL_2}" "$@"
}

function perr() {
    printf "    ${CError}${FBold}ERROR${RNormal}${CError}: " >&2
    print_msg "$@" >&2
    printf "${CDefault}" >&2
    say 'ERROR:' "$@" 2>/dev/null || true
}

function pwarn() {
    printf "    ${CWarn}${FBold}WARN${RNormal}${CWarn}: " >&2
    print_msg "$@" >&2
    printf "${CDefault}" >&2
    say 'ERROR:' "$@" 2>/dev/null || true
}

function pdebug() {
    printf "    ${CDebug}${FBold}DEBUG${RNormal}${CDebug}: " >&2
    print_msg "$@" >&2
    printf "${CDefault}" >&2
}

function pinfo_newline() {
    print_msg ''
}

function perr_newline() {
    print_msg '' >&2
}

function pwarn_newline() {
    print_msg '' >&2
}

function pdebug_newline() {
    print_msg '' >&2
}

function format_frequency() {
    while [ $# -gt 0 ]; do
        echo -n "$(bc <<<"$1 / 1000")MHz"
        shift
        if [ $# -gt 0 ]; then
            echo -n ' '
        fi
    done

}
