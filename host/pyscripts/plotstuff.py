#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
import pandas as pd
import matplotlib.pyplot as plt

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

def dir_path(string):
    Path(string).mkdir(parents=True, exist_ok=True)
    return string
#-- dir_path

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
            'help': 'The output file basename (+path)',
            'type': dir_path,
            'default': 'out',
        },
    },
    {
        'short': '-O',
        'long': '--out-exts',
        'opts': {
            'help': 'The list of extensions to append to the file basename',
            'action': 'append',
            'default': [],
        },
    },
    {
        'short': '-X',
        'long': '--xlabel',
        'opts': {
            'help': 'The label to put on the x axis',
            'type': str,
            'default': None,
        },
    },
    {
        'short': '-Y',
        'long': '--ylabel',
        'opts': {
            'help': 'The label to put on the y axis',
            'type': str,
            'default': None,
        },
    },
]

required_options = [
    {
        'short': '-x',
        'long': '--xcolumn',
        'opts': {
            'help': 'The column to use on the x axis',
            'type': str,
            'default': '',
        },
    },
    {
        'short': '-y',
        'long': '--ycolumn',
        'opts': {
            'help': 'The column to use on the y axis',
            'type': str,
            'default': '',
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

    required_group = parser.add_argument_group('required named arguments')
    for o in required_options:
        if o['short']:
            required_group.add_argument(o['short'], o['long'], required=True, **o['opts'])
        else:
            required_group.add_argument(o['long'], required=True, **o['opts'])

    return parser.parse_args()
#-- parse_cmdline_args


def safe_save_to_csv(out_df, out_file):
    # Create a temporary file in the destination mount fs
    # (using tmp does not mean that moving = no copy)
    out_dir = os.path.dirname(os.path.abspath(out_file))
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    tmpfile_name = out_dir + '/raw_' + str(os.getpid()) + '.tmp'
    out_df.to_csv(tmpfile_name, index=None)

    # NOTE: It should be safe this way, but otherwise please
    # disable signal interrupts before this operation

    os.rename(tmpfile_name, out_file)

    # NOTE: If disabled, re-enable signal interrupts here
    # (or don't, the program will terminate anyway)
#-- safe_save_to_csv

def plot_series(df, x_filed, y_field, label):
    plt.plot(df[x_filed], df[y_field],
        marker='o',
        alpha=.8,
        label=label,
        linewidth=1,
    )
#-- plot_series

import re

def tryint(s):
    try:
        return int(s)
    except:
        return s

def alphanum_key(s):
    return [ tryint(c) for c in re.split('([0-9]+)', s) ]

def alphanum_key_tuple(kv):
    return alphanum_key(kv[0])

#----------------------------------------------------------#

def main():
    args = parse_cmdline_args()

    dfs = {}

    for f in args.in_files:
        df = pd.read_csv(f, index_col=False, float_precision='high')
        label = os.path.basename(os.path.realpath(f.name)).replace('.csv', '')
        dfs = {**dfs, **{label: df}}

    for label, df in sorted(dfs.items(), key=alphanum_key_tuple):
        plot_series(df, args.xcolumn, args.ycolumn, label)

    plt.xlabel(args.xlabel if args.xlabel != None else args.xcolumn)
    plt.ylabel(args.ylabel if args.ylabel != None else args.ycolumn)
    plt.grid()

    plt.legend(loc='upper center',
        bbox_to_anchor=(.5, 1.18),
        ncol=3,
        # fancybox=True,
        # shadow=True,
    )
    # plt.show()

    if len(args.out_exts) == 0:
        args.out_exts=['.png']
    for ext in args.out_exts:
        plt.savefig(args.out_file + ext)

    return 0
#-- main

if __name__ == "__main__":
    main()
