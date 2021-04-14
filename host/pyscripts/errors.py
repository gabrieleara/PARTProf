#!/usr/bin/env python3

# Compares files produced by `collect.py` and `simulate.py` and produces an
# output table with all relative errors

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
TIME    = 'time'
POWER   = 'power'
IDLE    = 'idle'

COLL_TIME   = 'time_mean'
COLL_POWER  = 'power_mean'

MEAS_TIME   = 'meas_time'
PRED_TIME   = 'pred_time'
MEAS_POWER  = 'meas_power'
PRED_POWER  = 'pred_power'

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

options = [
    {
        'short': None,
        'long': 'collapsed_measurements_file',
        'opts': {
            'metavar': 'collapsed-measurements-file',
            'help': 'The file containing original measurements (as collapsed by collapse.py)',
            'type': str,
        },
    },
    {
        'short': None,
        'long': 'simulated_data_file',
        'opts': {
            'metavar': 'simulated-data-file',
            'help': 'The file containing simulated values (produced by simulate.py)',
            'type': str,
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
# |                  Comparison Function                   |
# +--------------------------------------------------------+

def percent_error(m, p):
    """
    Returns the absolute percentage error (with sign).

    Parameters
    ----------
    m : numeric
        The original measured value.
    p : numeric
        The predicted value.
    """
    if m == 0:
        if p == 0:
            return 0
        else:
            raise BlatantlyWrongPredictionException(
                'Expected 0, predicted ' + str(p) + "! APE is ∞!"
            )
    return (p - m) / abs(m) * 100


# +--------------------------------------------------------+
# |                          Main                          |
# +--------------------------------------------------------+

def main():
    args = parse_cmdline_args()

    measurements = pd.read_csv(args.collapsed_measurements_file)
    simulations = pd.read_csv(args.simulated_data_file)

    measurements = measurements[[
        HOWMANY,
        ISLAND,
        FREQ,
        TASK,
        COLL_POWER,
        COLL_TIME,
    ]]

    measurements = measurements.rename(
        {
            COLL_TIME: MEAS_TIME,
            COLL_POWER: MEAS_POWER,
        },
        axis='columns',
    )

    simulations = simulations.rename(
        {
            TIME: PRED_TIME,
            POWER: PRED_POWER,
        },
        axis='columns',
    )

    # Fix time for idle task
    measurements.loc[measurements[TASK] == IDLE, MEAS_TIME] = 0

    # Assumes for simplicity that both tables have the same size, howeve the
    # "inner" join option should prevent cases in which the two tables differ
    # for some reason
    df = measurements.merge(simulations,
        how='inner',
        validate='1:1',
    )

    df['time_error'] = df.apply(lambda row:
        percent_error(row[MEAS_TIME], row[PRED_TIME]),
        axis = 'columns',
    )

    df['power_error'] = df.apply(lambda row:
        percent_error(row[MEAS_POWER], row[PRED_POWER]),
        axis = 'columns',
    )

    out_df = df
    safe_save_to_csv(out_df, args.out_file)

    return 0
#-- main


if __name__ == "__main__":
    main()
