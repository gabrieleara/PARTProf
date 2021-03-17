#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
import pandas as pd
import numpy as np

# TODO: power, voltage... but also temperature!

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

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
        'long': '--out-file',
        'opts': {
            'help': 'The output file',
            'type': str,
            'default': 'a.out',
        },
    },
    {
        'short': '-t',
        'long': '--time-coeff',
        'opts': {
            'help': 'The method to use to calculate the time coefficient.',
            'type': str,
            'choices': [
                'one',
                'avg',
            ],
            'default': 'one',
        }
    },
    {
        'short': '-p',
        'long': '--power-coeff',
        'opts': {
            'help': 'The method to use to calculate the power coefficients.',
            'type': str,
            'choices': [
                'one',
                'regression',
                'fixed_regression',
            ],
            'default': 'one',
        }
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

# ----------------------------------------------------------


def safe_save_to_csv(out_df, out_file):
    # Create a temporary file in the destination mount fs
    # (using tmp does not mean that moving = no copy)
    out_dir = os.path.dirname(os.path.abspath(out_file))
    Path(out_dir).mkdir(parents=True, exist_ok=True)
    tmpfile_name = out_dir + '/raw_' + str(os.getpid()) + '.tmp'
    out_df.to_csv(tmpfile_name, index=None)

    out_df.to_csv(tmpfile_name, index=None)

    # NOTE: It should be safe this way, but otherwise please
    # disable signal interrupts before this operation

    os.rename(tmpfile_name, out_file)

    # NOTE: If disabled, re-enable signal interrupts here
    # (or don't, the program will terminate anyway)
#-- safe_save_to_csv

#----------------------------------------------------------#

# NOTICE: this is fixed to using mean values, if you want to
# use the medians instead you should change _mean to _50% in
# these string constants


HOWMANY = 'howmany'
ISLAND = 'island'
FREQ = 'frequency'
POWER = 'power_mean'
TIME = 'time_rel'
VOLTAGE = 'voltage_mean'
POWER_M = 'power_m'
POWER_Q = 'power_q'
SLOWNESS = 'slowness'
IDLE = 'idle'
TASK = 'task'

OUTCOLS = [
    ISLAND,
    FREQ,
    TASK,
    SLOWNESS,
    POWER_M,
    POWER_Q,
]

#----------------------------------------------------------#


def coeff_time_one(df, island, frequency, task):
    """Calculate the expected runtime as the value measured
    for the single task execution experiment.
    """

    if task == IDLE:
        return 0
    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == frequency]
    df = df[df[TASK] == task]
    df = df[df[HOWMANY] == 1]
    return df[TIME].values[0]
#-- coeff_time_one


def coeff_time_avg(df, island, frequency, task):
    """Calculate the expected runtime as the AVERAGE value
    measured for an increasing number of parallel tasks
    during experimentation.
    """

    if task == IDLE:
        return 0
    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == frequency]
    df = df[df[TASK] == task]
    values = df[TIME].values
    return np.mean(values)
    # l = []
    # for h in df[HOWMANY].unique():
    #     l += [df[df[HOWMANY] == h][TIME].values[0]]
    # return sum(l) / (1.0 * len(l))
#-- coeff_time_avg


def coeff_power_one(df, island, frequency, task):
    """Calculate the expected power consumption m and q
    values as the difference between the value measured for
    the single task execution experiment and the measurement
    for the IDLE task.
    """

    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == frequency]
    idle = df
    idle = idle[idle[TASK] == IDLE]
    idle = idle[idle[HOWMANY] == 1]

    q = idle[POWER].values[0]

    df = df[df[TASK] == task]
    df = df[df[HOWMANY] == 1]
    m = df[POWER].values[0] - q

    return m, q
#-- coeff_power_one


def fill_x_y(df, island, frequency, task):
    """Fill x and y arrays with the power values collected
    during experiment. First value is always (0, P_idle),
    while the ones after that are the values measured for an
    increasing number of parallel tasks.

    Returns: x, y
    """

    df = df
    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == frequency]
    idle = df
    idle = idle[idle[TASK] == IDLE]
    idle = idle[idle[HOWMANY] == 1]

    df = df[df[TASK] == task]
    howmanies = df[HOWMANY].unique()

    x = np.empty(len(howmanies) + 1)
    y = np.empty_like(x)

    i = 0
    x[i] = 0
    y[i] = idle[POWER].values[0]
    for h in howmanies:
        i += 1
        x[i] = h
        y[i] = df[df[HOWMANY] == h][POWER].values[0]

    return x, y
#-- fill_x_y


def coeff_power_regression(df, island, frequency, task):
    """Calculate the expected power consumption m and q
    values using linear regression of the values collected
    for an increasing number of parallel tasks.
    """

    x, y = fill_x_y(df, island, frequency, task)
    m, q = np.polyfit(x, y, 1)
    return m, q
#-- coeff_power_regression


def coeff_power_fixed_regression(df, island, frequency, task):
    """Calculate the expected power consumption m and q
    values using a custom regression for a fixed q value
    equal to the value measured for the IDLE task, using
    then the values collected for an increasing number of
    parallel tasks to calculate the m.
    """

    x, y = fill_x_y(df, island, frequency, task)
    q = y[0]
    m = 1 / np.dot(x, x) * (np.dot(x, y) - q * sum(x))
    return m, q
#-- coeff_power_fixed_regression


#----------------------------------------------------------#

# TODO: how do I prepare more efficiently an array of rows?
def prepare_simtable(df, coeff_power, coeff_time):
    """Prepare a simulation table using the two given
    functions to calculate the power and the time
    coefficients to fill the table.
    """

    # outdf = pd.DataFrame(columns=OUTCOLS)
    rows = []
    for i in df[ISLAND].unique():
        for t in df[TASK].unique():
            for f in df[df[ISLAND] == i][FREQ].unique():
                pm, pq = coeff_power(df, i, f, t)
                time = coeff_time(df, i, f, t)
                rows += [[i, f, t, time, pm, pq]]
                # df2 = pd.DataFrame([row], columns=cols)
                # outdf = outdf.append(df2, ignore_index=True)
    outdf = pd.DataFrame(rows, columns=OUTCOLS)
    return outdf
# -- prepare_simtable


#----------------------------------------------------------#


def main():
    args = parse_cmdline_args()

    time_coefficients = {
        'one': coeff_time_one,
        'avg': coeff_time_avg,
    }

    power_coefficients = {
        'one': coeff_power_one,
        'regression': coeff_power_regression,
        'fixed_regression': coeff_power_fixed_regression,
    }

    coeff_time = time_coefficients[args.time_coeff]
    coeff_power = power_coefficients[args.power_coeff]

    df = pd.read_csv(args.in_file)
    out_df = prepare_simtable(df, coeff_power, coeff_time)
    safe_save_to_csv(out_df, args.out_file)

    return 0
#-- main


if __name__ == "__main__":
    main()
