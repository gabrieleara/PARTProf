#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
from pandas.core.indexes import base

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

def dir_path(string):
    Path(string).mkdir(parents=True, exist_ok=True)
    return string
#-- dir_path


option_defaults = {
    'plot_window' : False,
}

options = [
    {
        'short': None,
        'long': 'in_file',
        'opts': {
            'metavar': 'in-file',
            'type': argparse.FileType('r'),
        },
    },
    {
        'short': '-o',
        'long': '--out-dir',
        'opts': {
            'help': 'The output directory',
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
        'short': '-p',
        'long': '--plot-window',
        'opts': {
            'help': 'Enables plotting window on the display',
            'dest': 'plot_window',
            'action': 'store_true',
        },
    },
    {
        'short': None,
        'long': '--no-plot-window',
        'opts': {
            'help': 'Disables plotting window on the display',
            'dest': 'plot_window',
            'action': 'store_false',
        },
    },
    {
        'short': '-k',
        'long': '--key-column',
        'opts': {
            'help': 'The following column will be used as key (and therefore excluded from plots)',
            'action': 'append',
        }
    },
    {
        'short': '-i',
        'long': '--ignore-column',
        'opts': {
            'help': 'Ignore the given column from the plots',
            'action': 'append',
        }
    },
]

required_options = [
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

    parser.set_defaults(**option_defaults)

    return parser.parse_args()
#-- parse_cmdline_args

#----------------------------------------------------------#

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

def plot_col_pairs(basecommand, outpath, col_pair):
    x = str(col_pair[0])
    y = str(col_pair[1])
    xx = "'" + x + "'"
    yy = "'" + y + "'"
    cmd = basecommand + [
        '-o', "'" + outpath + '/' + x + '_' + y + "'",
        '-x', xx,
        '-y', yy,
        '-X', xx,
        '-Y', yy,
    ]
    the_command = " ".join(cmd)
    print('> ', the_command)
    os.system(the_command)
#--

def plot_all_combinations(df, args, outpath=''):
    import pathlib
    import tempfile

    scriptdir = pathlib.Path(__file__).parent.resolve()

    f = tempfile.NamedTemporaryFile(delete=False)
    fname = f.name
    f.close()

    # Write temporary filtered file here
    df.to_csv(fname, index=None)

    basecommand = [
        "'" + str(scriptdir) + '/plotstuff.py' + "'",
        "'" + fname + "'",
        '--plot-window' if args.plot_window else '--no-plot-window',
        # O,
        # o,
        # x,
        # y,
        # xlabel,
        # ylabel,
    ]

    # TODO: basepath

    for o in args.out_exts:
        basecommand += [
            '-O', "'" + str(o) + "'",
        ]

    cols = df.columns.to_numpy()
    col_combinations = np.transpose([
        np.tile(cols, len(cols)),
        np.repeat(cols, len(cols)),
    ])

    os.makedirs(outpath, exist_ok=True)

    from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor

    executor = ThreadPoolExecutor()
    for _ in executor.map(
            lambda cols: plot_col_pairs(basecommand, outpath, cols),
            col_combinations
            ):
        pass
    os.unlink(fname)
#-- plot_all_combinations

def traverse_combinations(df, keys, args, outpath=''):
    if len(keys) < 1:
        plot_all_combinations(df, args, outpath=outpath)
        return

    keys_copy = keys.copy()
    key = keys_copy.pop(0)

    for value in df[key].unique():
        indf = df[df[key] == value]
        indf = indf.drop(columns=[key])
        traverse_combinations(indf, keys_copy, args,
            outpath=outpath + str(value) + '/',
        )
#-- traverse_combinations

def main():
    args = parse_cmdline_args()

    df = pd.read_csv(args.in_file, index_col=False, float_precision='high')
    df = df.drop(columns=args.ignore_column)
    traverse_combinations(df, args.key_column, args, outpath=args.out_dir + '/')

    return 0
#-- main

if __name__ == "__main__":
    main()
