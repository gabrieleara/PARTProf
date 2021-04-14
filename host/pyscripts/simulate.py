#!/usr/bin/env python3

## This file produces the exact opposite operation than simtable.py.
## Since simtable.py produces an approximate model from the collapsed table,
## the resulting table from this file will differ from the original table.

import argparse
import os
from pathlib import Path

import numpy as np
import pandas as pd


# TODO: change the way the simtable is generated to sum m and pidle together
#       this will reflect better how RTSim actually works...

# +--------------------------------------------------------+
# |                       Constants                        |
# +--------------------------------------------------------+

ISLAND  = 'island'
FREQ    = 'frequency'
TASK    = 'task'
HOWMANY = 'howmany'
TIME    = 'time'
POWER   = 'power'
IDLE    = 'idle'

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

options = [
    {
        'short': None,
        'long': 'in_file',
        'opts': {
            'metavar': 'in-file',
            'type': str,
        },
    },
    {
        'short': '-t',
        'long': '--task-list',
        'opts': {
            'help': 'The list of tasks to simulate on each island (for heterogeneous tasksets), each as a separate argument',
            'type': str,
            'nargs': '*',
            'default': None,
        },
    },
    {
        # TODO: change to a map-like definition instead of an integer, for
        # islands with different number of cores
        'short': '-n',
        'long': '--numcores',
        'opts': {
            'help': 'The number of cores present in each island (unused if -t is provided)',
            'type': int,
            'default': 4,
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
# |                      Save to CSV                       |
# +--------------------------------------------------------+


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

# +--------------------------------------------------------+
# |                        Simulate                        |
# +--------------------------------------------------------+


def simulate_time(df, island, frequency, task):
    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == frequency]
    df = df[df[TASK] == task]
    return df[TIME].values[0]
#-- simulate_time


def simulate_power(df, island, freq, task_list):
    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == freq]
    pidle = df[df[TASK] == IDLE][POWER].values[0]
    power = pidle
    for t in task_list:
        if (t != IDLE):
            # This factor corresponds to power_workload_i - pidle
            power += df[df[TASK] == t][POWER].values[0]
    return power
#-- simulate_power


def simulate_homogeneous(simtable, numcores):
    # Columns in output table:
    # HOWMANY, ISLAND, FREQ, TASK, POWER, TIME
    dictionary_list = []
    for h in range(1, numcores+1):
        for i in simtable[ISLAND].unique():
            for t in simtable[TASK].unique():
                # In any run, there are "h" active tasks and
                # "numcores-h" idle tasks
                task_list = [t    for _ in range(h)] + \
                            [IDLE for _ in range(numcores-h)]

                freqs = simtable[simtable[ISLAND] == i][FREQ].unique()
                for f in freqs:
                    time = simulate_time(simtable, i, f, t)
                    power = simulate_power(simtable, i, f, task_list)
                    dictionary_data = {
                        HOWMANY: h,
                        ISLAND: i,
                        FREQ: f,
                        TASK: t,
                        POWER: power,
                        TIME: time,
                    }
                    dictionary_list.append(dictionary_data)
    #---------------
    return pd.DataFrame.from_dict(dictionary_list)
#-- simulate_homogeneous


def simulate_heterogeneous_power(simtable, task_list):
    # Columns in output table:
    # ISLAND, FREQ, POWER
    dictionary_list = []
    for i in simtable[ISLAND].unique():
        freqs = simtable[simtable[ISLAND]][FREQ].unique()
        for f in freqs:
            power = simulate_power(simtable, i, f, task_list)
            dictionary_data = {
                ISLAND: i,
                FREQ: f,
                POWER: p,
            }
            dictionary_list.append(dictionary_data)
    #-------
    return pd.DataFram.from_dict(dictionary_list)
#-- simulate_heterogeneous_power


# +--------------------------------------------------------+
# |                          Main                          |
# +--------------------------------------------------------+

def main():
    args = parse_cmdline_args()
    df = pd.read_csv(args.in_file)

    if args.task_list:
        out_df = simulate_heterogeneous_power(df, args.task_list)
    else:
        out_df = simulate_homogeneous(df, args.numcores)

    safe_save_to_csv(out_df, args.out_file)

    return 0
#-- main


if __name__ == "__main__":
    main()
