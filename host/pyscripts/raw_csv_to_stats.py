#!/usr/bin/python3

import argparse
import sys
import os
import numpy as np
import pandas as pd

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

options = [
    {
        'short': None,
        'long': 'in_files',
        'opts': {
            'metavar': 'in-files',
            'type': argparse.FileType('r'),
            'nargs': '+',
        },
    },
    {
        'short': '-o',
        'long': '--out-file',
        'opts': {
            'help': 'The output file',
            'type': str,
            'default': 'a.out',
        },
    },
]


def parse_cmdline_args():
    parser = argparse.ArgumentParser(
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )

    for o in options:
        if o['short']:
            parser.add_argument(o['short'], o['long'], **o['opts'])
        else:
            parser.add_argument(o['long'], **o['opts'])

    return parser.parse_args()
#-- parse_cmdline_args

# +--------------------------------------------------------+
# |                          Body                          |
# +--------------------------------------------------------+

def to_single_df(in_files):
    dfs = []
    for inf in in_files:
        print(inf)
        df = pd.from_csv(inf)
        dfs += df

    return pd.concat(dfs)
#-- concat_dfs

def main():
    global args
    args = parse_cmdline_args()

    dfs_dict = {
        'time': [],
        'power': [],
    }

    for f in args.in_files:
        for label in dfs_dict:
            if label in f.name:
                df = pd.read_csv(f)
                dfs_dict[label] += [df]
                break

    dfs = []

    for _, tables in dfs_dict.items():
        if len(tables):
            dfs += [pd.concat(tables).describe()]

    # Concat along columns, so that time and power columns
    # can be concatenated while keeping the indexing on the
    # rows for the different stats
    df = pd.concat(dfs, axis='columns')

    # Create a temporary file in the destination mount fs
    # (using tmp does not mean that moving = no copy)
    tmpfile_name = os.path.dirname(
        os.path.abspath(args.out_file)
        ) + '/raw_' + str(os.getpid()) + '.tmp'

    # tmpfile_name = '/tmp/raw_' + str(os.getpid()) + '.tmp'
    df.to_csv(tmpfile_name)

    # NOTE: It should be safe this way, but otherwise please
    # disable signal interrupts before this operation

    os.rename(tmpfile_name, args.out_file)

    # NOTE: If disabled, re-enable signal interrupts here
    # (or don't, the program will terminate anyway)

    return 0
#-- main


if __name__ == "__main__":
    main()
