#!/usr/bin/env python3

"""
This module provides a simple function that reads files of key-value pairs, one
per line, with the key and the value separated by a = sign.
"""

def loadmap(infile):
    """
    Read the given infile and return the map containing all key-value pairs in
    it.
    """
    map = {}

    # TODO: comments
    # TODO: error management

    for line in infile:
        if len(line.strip()) < 1:
            # Skip
            pass
        else:
            split = line.split('=', 2)
            k = split[0]
            v = split[1]
            map[k] = v.strip()
    return map
#-- loadmap
