#!/usr/bin/env python3

"""
This module contains a function that saves the output of a program in a "safe"
fashion. This makes python programs that want to write their output to a file
eligible for use with GNU Make.
"""

import os
import pathlib
import re
import sys

def safe_write(outfun, outfile, *args, **kwargs):
    """
    Calls the given function and saves its output into out_file in a "safe" way
    for GNU Make.

    Virtually, you can assume that this function is equivalent as calling
    `outfun(outfile)`.

    Other arguments are provided in case outfun needs more arguments than just
    the outfile, but beware that the outfile will always be put as first
    argument in the call. If you need to rearrange the arguments, consider
    binding the input function using either `partial` from `functools` or
    wrapping the desired call in another function call.
    """

    # First of all, let's create a temporary file name in the same directory as
    # the destination file. This is necessary because the destination file
    # (usually) resides in a different file system than the temporary file
    # system and moves between file systems are not "atomic" operations, while a
    # move withing the same file system can be considered virtually atomic.

    # Get the output directory. The directory might not exist yet, so we create
    # it on the spot if it doesn't.
    outdir = os.path.dirname(os.path.abspath(outfile))
    pathlib.Path(outdir).mkdir(parents=True, exist_ok=True)

    # Choose the temporary file name using process id
    tmpfile_name = outdir + '/tmp_' + str(os.getpid()) + '.tmp'

    # Write to temporary file
    outfun(tmpfile_name, *args, **kwargs)

    # NOTE: A simple rename like this should be enough "atomic". If you have
    # problems, try disabling signal handlers here.

    os.rename(tmpfile_name, outfile)

    # NOTE: If you do disable signal handlers, re-enable them here!
#-- safe_write


def df_safe_to_csv(df,
    path_or_buf,
    *args,
    **kwargs):
    safe_write(df.to_csv,
       path_or_buf,
       index=None,
       *args,
       **kwargs)
    pass


FILENAME_REGEXES = {
    'howmany':      r'howmany_(\d+)/',
    'island':       r'policy_(\w+)/',
    'frequency':    r'freq_(\d+)/',
    'task':         r'task_([\w-]+)/',
    'cpu':          r'(\d+)/',
}

for k in FILENAME_REGEXES:
    FILENAME_REGEXES[k] = re.compile(FILENAME_REGEXES[k])


def match_last(regex: re.Pattern, string: str):
    match = None
    *_, match = regex.finditer(string)
    return match
#-- match_last

def extract_metadata(file, policy_island_map, island_cpus_map):
    filepath = os.path.realpath(file.name)

    metadata = {}
    for k in FILENAME_REGEXES:
        metadata[k] = match_last(FILENAME_REGEXES[k], filepath).group(1)

    # Map policy to correct island name
    if not metadata['island'] in policy_island_map:
        sys.exit("Policy " + str(metadata['island']) + " not present in current mapping! Use --help for help.")

    metadata['island']  = policy_island_map[metadata['island']]

    if not metadata['island'] in island_cpus_map:
        sys.exit("Island " + str(metadata['island']) + " not present in current mapping! Use --help for help.")

    try:
        metadata['cpu'] = int(metadata['cpu'])-1
    except ValueError:
        sys.exit("CPU '" + str(metadata['cpu']) + "is not a valid CPU number!")

    cpus = island_cpus_map[metadata['island']]
    if metadata['cpu'] > len(cpus):
        sys.exit("CPU '" + str(metadata['cpu']) + "is not a valid CPU number for the island " + metadata['island'] + " !")

    # Maps the cpus in order from 0,1,2,3 to the correct numbers inside the
    # island
    metadata['cpu'] = cpus[metadata['cpu']]

    return metadata
#-- extract_metadata
