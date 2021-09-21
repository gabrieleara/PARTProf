#!/usr/bin/env python3

"""
This module provides a simple function that reads files of key-value pairs, one
per line, with the key and the value separated by a = sign.
"""

def loadmap(infile_lines):
    """
    Read the lines passed by infile_lines and return the map containing all
    key-value pairs in it.
    """
    map = {}

    # TODO: comments
    # TODO: error management

    for line in infile_lines:
        if len(line.strip()) < 1:
            # Skip
            pass
        else:
            split = line.split('=', 2)
            k = split[0].strip()
            v = split[1].strip()
            map[k] = v
    return map
#-- loadmap
