#!/usr/bin/env python3

# Collects all relative errors calculated by the errors
# script and prints following percentiles for both time and
# power:
#
# [min, 1st, 25th, 50th, 75th, 90th, max]
#
# It does this first for each board, then sums up all values
# for all boards.
#
# In doing so, it also differentiates between negative and
# positive error values.

import argparse
import os
from pathlib import Path

import numpy as np
import pandas as pd


# +--------------------------------------------------------+
# |                       Constants                        |
# +--------------------------------------------------------+

ISLAND  = 'island'
FREQ    = 'frequency'
TASK    = 'task'
HOWMANY = 'howmany'
IDLE    = 'idle'

TIME_ERROR  = 'time_error'
POWER_ERROR = 'power_error'

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

options = [
    {
        'short': None,
        'long': 'in_files',
        'opts': {
            'metavar': 'list-of-error-files',
            'help': 'All files containing error values (produced by errors.py)',
            'nargs': '+',
            'type': str,
        },
    },
    {
        'short': '-t',
        'long': '--task-list',
        'opts': {
            'help': 'The list of tasks that should be considered',
            'type': str,
            'nargs': '*',
            'default': None,
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


# # +--------------------------------------------------------+
# # |                      Save to CSV                       |
# # +--------------------------------------------------------+


# def safe_save_to_csv(out_df, out_file):
#     # Create a temporary file in the destination mount fs
#     # (using tmp does not mean that moving = no copy)
#     out_dir = os.path.dirname(os.path.abspath(out_file))
#     Path(out_dir).mkdir(parents=True, exist_ok=True)
#     tmpfile_name = out_dir + '/raw_' + str(os.getpid()) + '.tmp'
#     out_df.to_csv(tmpfile_name, index=None)

#     # NOTE: It should be safe this way, but otherwise please
#     # disable signal interrupts before this operation

#     os.rename(tmpfile_name, out_file)

#     # NOTE: If disabled, re-enable signal interrupts here
#     # (or don't, the program will terminate anyway)
# #-- safe_save_to_csv


# +--------------------------------------------------------+
# |                  Describe Percentiles                  |
# +--------------------------------------------------------+

# PERCENTILES = [.01, .10, .25, .50, .75, .90, .99]
PERCENTILES = [.90]

def percentiles_to_perc(percentiles):
    return [str(int(n * 100)) + '%' for n in percentiles]

def describe(df):
    desc = df.describe(
        percentiles=PERCENTILES,
    )

    desc = desc.loc[percentiles_to_perc(PERCENTILES) + ['max'], :]
    print(desc)


def describe_positive(df):
    df = df.copy()
    df[df < 0] = 0
    describe(df)


def describe_negative(df):
    df = -df
    describe_positive(df)


def describe_abs(df):
    df = df.abs()
    describe(df)

def print_separator(numdashes, word):
    print(' ' + '=' * numdashes + ' ' + word + ' ' + '=' * numdashes)

def print_header(name):
    strlen = len(name)
    if strlen < 42:
        spacelen = int((42 - strlen) / 2)
        dashlen = spacelen * 2 + strlen
    else:
        spacelen = 1
        dashlen = strlen + 2
    print('+' + '-' * dashlen + '+')
    print('+' + ' ' * spacelen + name + ' ' * spacelen + '+')
    print('+' + '-' * dashlen + '+')

def describe_all(df, numdashes=15):
    print_separator(numdashes, 'POSITIVE')
    describe_positive(df)
    print_separator(numdashes, 'NEGATIVE')
    describe_negative(df)
    print_separator(numdashes, 'ABSOLUTE')
    describe_abs(df)


# +--------------------------------------------------------+
# |                          Main                          |
# +--------------------------------------------------------+

def main():
    args = parse_cmdline_args()

    out_df = pd.DataFrame()

    for inf in args.in_files:
        df = pd.read_csv(inf, float_precision='high')

        if args.task_list:
            df = df[df[TASK].isin(args.task_list)]

        df = df[[
            TIME_ERROR,
            POWER_ERROR,
        ]]

        name = str(os.path.basename(os.path.dirname(inf)))
        print_header(name)
        describe_all(df)

        out_df = pd.concat(
            [out_df, df],
            ignore_index=True,
            copy=False,
        )

    print_header('GRAND TOTAL')
    describe_all(out_df)

    return 0
#-- main


if __name__ == '__main__':
    main()
