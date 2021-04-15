#!/usr/bin/env python3

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
TIME    = 'time_rel'
POWER   = 'power_mean'
IDLE    = 'idle'

SINGLE      = 'single'
AVERAGE     = 'average'
MAXIMUM     = 'maximum'
TRUE_REG    = 'true_regression'
FIXED_REG   = 'fixed_regression'

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
        'long': '--time-fun',
        'opts': {
            'help': 'The method used to generate the time column',
            'type': str,
            'choices': [
                SINGLE,
                AVERAGE,
                MAXIMUM,
            ],
            'default': SINGLE,
        },
    },
    {
        'short': '-p',
        'long': '--power-fun',
        'opts': {
            'help': 'The method used to generate the power column',
            'type': str,
            'choices': [
                SINGLE,
                TRUE_REG,
                FIXED_REG,
            ],
            'default': SINGLE,
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
# |                     Time Functions                     |
# +--------------------------------------------------------+


def time_max(df, island, frequency, task):
    """
    Maximum (average) runtime profiled.

    Returns the maximum execution time registered for the workload task in the
    given island+frequency configuration when varying number of concurrent
    tasks.
    """

    if (task == IDLE):
        return 0
    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == frequency]
    df = df[df[TASK] == task]
    return df[TIME].max()
    # howmanies = df[HOWMANY].unique()
    # l = []
    # for h in howmanies:
    #     l += [df[df[HOWMANY] == h]['time_avg'].values[0]]
    # return max(l)
#-- time_max


def time_single(df, island, frequency, task):
    """
    Runtime profiled using only one task in isolation.
    """
    if (task == IDLE):
        return 0
    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == frequency]
    df = df[df[TASK] == task]
    return df[df[HOWMANY] == 1][TIME].values[0]
#-- time_one


def time_mean(df, island, frequency, task):
    """
    Average runtime profiled using an increasing number of parallel tasks.
    """
    if (task == IDLE):
        return 0
    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == frequency]
    df = df[df[TASK] == task]
    return df[TIME].mean()
    # howmanies = df[HOWMANY].unique()
    # l = []
    # for h in howmanies:
    #     l += [df[df[HOWMANY] == h]['time_avg'].values[0]]
    # return sum(l) / (1.0 * len(l))
#-- time_mean


# +--------------------------------------------------------+
# |                    Power Functions                     |
# +--------------------------------------------------------+

# def power_rtsim_wrong(df, island, frequency, task):
#     df = df[df[ISLAND] == island]
#     df = df[df[FREQ] == frequency]
#     m = df[df[HOWMANY] == 1][POWER].values[0]
#     return m, 0

# NOTICE: the q values are only for debug purposes, EXCEPT FOR THE IDLE POWER!


def power_idle(df):
    """
    Returns power of idle task (assumes core type and frequency to be fixed)
    """
    df = df[df[TASK] == IDLE]
    return df[df[HOWMANY] == 1][POWER].values[0]
#-- power_idle


def power_single(df, island, frequency, task):
    """
    Returns the m and q coefficients obtained running a single task in
    isolation.

    NOTICE: the simulator will ignore this q value and use the IDLE power
    anyway.
    """
    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == frequency]

    pidle = power_idle(df)
    if (task == IDLE):
        return 0, pidle

    df = df[df[TASK] == task]

    q = pidle
    m = df[df[HOWMANY] == 1][POWER].values[0] - pidle
    return m, q
#-- power_single


def power_getxy(df, pidle):
    # x.append(0)
    # y.append(pidle)
    # for i in range(1, 5):
    #     x.append(i)
    #     y.append(df[df[HOWMANY] == i][POWER].values[0])
    # x = np.array(x)
    # y = np.array(y)

    numcores = df[HOWMANY].size
    x = np.arange(numcores+1)
    y = np.empty_like(x)
    y[0] = pidle
    for i in x[1:]:
        y[i] = df[df[HOWMANY] == i][POWER].values[0]

    return (x, y)
#-- power_getxy


def true_regression_fun(x, y):
    m, q = np.polyfit(x, y, 1)
    return m, q


def fixed_regression_fun(x, y):
    q = x[0]
    m = 1 / np.dot(x, x) * (np.dot(x, y) - q * x.sum())
    return m, q


def power_regression(df, island, frequency, task, regfun):
    """
    Returns m and q values obtained using the regression function in input.
    """
    df = df[df[ISLAND] == island]
    df = df[df[FREQ] == frequency]

    pidle = power_idle(df)
    if (task == IDLE):
        return 0, pidle

    df = df[df[TASK] == task]
    (x, y) = power_getxy(df, pidle)
    return regfun(x, y)
#-- power_regression


def power_true_regression(df, island, frequency, task):
    """
    Returns the m and q coefficients obtained using true regression on the
    measured values (including idle).

    NOTICE: the simulator will ignore this q value and use the IDLE power
    instead.
    """
    return power_regression(df, island, frequency, task, true_regression_fun)
#-- power_true_regression


def power_fixed_regression(df, island, frequency, task):
    """
    Returns the m and q coefficients obtained using a fixed regression, in which q is forced to be equal to the IDLE power.

    NOTICE: the simulator will ignore this q value and use the IDLE power
    anyway.
    """
    return power_regression(df, island, frequency, task, fixed_regression_fun)
#-- power_fixed_regression


# +--------------------------------------------------------+
# |                    Prepare Simtable                    |
# +--------------------------------------------------------+


def simulation_table(df, time_fun, power_fun):
    islands = df[ISLAND].unique()
    tasks = df[TASK].unique()

    # TODO: add voltage info
    # cols = [ISLAND, FREQ, TASK, 'power', 'time']

    dictionary_list = []
    for i in islands:
        for t in tasks:
            freqs = df[df[ISLAND] == i][FREQ].unique()
            for f in freqs:
                time = time_fun(df, i, f, t)
                power, pidle = power_fun(df, i, f, t)
                if (t == IDLE):
                    power = pidle

                dictionary_data = {
                    ISLAND: i,
                    FREQ: f,
                    TASK: t,
                    'power': power,
                    'time': time,
                }
                dictionary_list.append(dictionary_data)

    return pd.DataFrame.from_dict(dictionary_list)
#-- simulation_table

# +--------------------------------------------------------+
# |                          Main                          |
# +--------------------------------------------------------+

def main():
    args = parse_cmdline_args()
    df = pd.read_csv(args.in_file, float_precision='high')

    time_funs = {
        SINGLE: time_single,
        AVERAGE: time_mean,
        MAXIMUM: time_max,
    }

    power_funs = {
        SINGLE: power_single,
        TRUE_REG: power_true_regression,
        FIXED_REG: power_fixed_regression,
    }

    time_fun = time_funs[args.time_fun]
    power_fun = power_funs[args.power_fun]

    out_df = simulation_table(df, time_fun, power_fun)
    safe_save_to_csv(out_df, args.out_file)

    return 0
#-- main


if __name__ == "__main__":
    main()
