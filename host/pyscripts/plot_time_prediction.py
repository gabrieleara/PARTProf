#!/usr/bin/env python3

"""
Compare actual time series with predictions obtained from custom functions.

This script accepts two input files and a bunch of configuration options:
 1. the original CSV file from which the time series is taken;
 2. the CSV file containing the parameters to use to predict the evolution over
    time of a similar task.

Among the assumptions that this script makes:
 1. the first CSV file is produced using power_samples_to_table.py
 2. the second CSV file is produced using power_tables_collect.py
"""

import sys

import matplotlib.pyplot as plt
# import numpy as np
import pandas as pd

# from modules import cmap
from modules import cmdargs
# from modules import cpuislands
from modules import maketools
from modules import plotting
from modules import tabletools
from modules import timetools

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+


cmdargs_conf = {
    "options": [
        {
            'short': None,
            'long': 'table_file',
            'opts': {
                'metavar': 'table-file',
                'type': cmdargs.argparse.FileType('r'),
            },
        },
        {
            'short': None,
            'long': 'params_file',
            'opts': {
                'metavar': 'params-file',
                'type': cmdargs.argparse.FileType('r'),
            },
        },
        {
            'short': '-o',
            'long': '--out-file',
            'opts': {
                'help': 'The output file basename (+path), hence without extension',
                'type': str,
                'default': 'out',
            },
        },
        {
            'short': '-O',
            'long': '--out-exts',
            'opts': {
                'help': 'The list of extensions to append to the file basename',
                'type': str,
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
            'short': '-Y1',
            'long': '--y1label',
            'opts': {
                'help': 'The label to put on the y1 axis',
                'type': str,
                'default': None,
            },
        },
        {
            'short': '-Y2',
            'long': '--y2label',
            'opts': {
                'help': 'The label to put on the y2 axis',
                'type': str,
                'default': None,
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
            'short': '-y2',
            'long': '--y2columns',
            'opts': {
                'help': 'The columns to use on the y2 axis',
                'type': str,
                'action': 'append',
                'default': [],
            },
        },
    ],
    'required_options': [
        {
            'short': '-y1',
            'long': '--y1columns',
            'opts': {
                'help': 'The columns to use on the y1 axis',
                'type': str,
                'action': 'append',
                'default': [],
            },
        },
    ],
    'defaults': {
        'plot_window' : False,
    }
}

# +--------------------------------------------------------+
# |                   Plotting Functions                   |
# +--------------------------------------------------------+

def plot_cols(axis, x, df, cols, **kwargs):
    if type(cols) == str:
        cols = [cols]

    for c in cols:
        y = df[c].to_numpy()
        y = timetools.smooth(y)
        axis.plot(x, y, label=c, **kwargs)

def get_or_default(v, default):
    return v if v != None else default

def args_fix_default(args):
    args.xlabel  = get_or_default(args.xlabel, 'Time [s]')
    args.y1label = get_or_default(args.y1label, 'Power [W]')
    args.y2label = get_or_default(args.y2label, 'Temperature [°C]')
    return args

def params_select(params, metadata):
    for k, v in metadata.items():
        try:
            v = pd.to_numeric(v)
        except ValueError:
            pass
        params = params[ params[k] == v ]
    return params

import numpy as np

def plot_from_params(axis, x, params, sampling_time):
    Th = params['temp_tz_high0'].to_numpy()[0]
    Tl = params['temp_tz_low0'].to_numpy()[0]
    tau_rise = params['temp_tz_tau_rise0'].to_numpy()[0]

    import math

    offset = 35

    axis.axhline(Th)
    axis.axhline(Tl)
    axis.axhline(Th - (Th - Tl) * math.exp(-1))
    axis.axvline(tau_rise + offset * sampling_time)

    print('Th', Th)
    print('Tl', Tl)
    print('tau_rise', tau_rise)

    axis.plot(x[offset:], Th - (Th - Tl) * np.exp( -x[:-offset] / (tau_rise)),
        color='black', **plotting.DEFAULT_PLOT_OPTIONS)
    pass


def main():
    args = cmdargs.parse_args(cmdargs_conf)
    args = args_fix_default(args)

    metadata = maketools.extract_metadata(args.table_file,
        {'4': 'big'}, {'big': [4,5,6,7]})

    table = tabletools.pd_read_csv(args.table_file)
    params = tabletools.pd_read_csv(args.params_file)
    params = params_select(params, metadata)
    if len(params.index) != 1:
        sys.exit("Error parsing the params associated with the given file!")

    breakpoint      = table['breakpoint'].dropna()[0]
    sampling_time   = table['sampling_time'].dropna()[0]

    # print(table)
    # print(params)

    fig, ax1 = plt.subplots()
    fig.set_figheight(8)
    fig.set_figwidth(12)

    x = table['time'].to_numpy()
    plot_cols(ax1, x, table, args.y1columns,
        color='red', **plotting.DEFAULT_PLOT_OPTIONS)

    ax1.grid()
    ax1.axvline(breakpoint * sampling_time)
    ax1.set_xlabel(args.xlabel)
    ax1.set_ylabel(args.y1label)
    ax1.legend(loc='upper left',
        bbox_to_anchor=(0, 1.1),
        ncol=3,
        # fancybox=True,
        # shadow=True,
    )

    if len(args.y2columns):
        ax2 = ax1.twinx()

        plot_cols(ax2, x, table, args.y2columns,
            **plotting.DEFAULT_PLOT_OPTIONS)

        ax2.set_ylabel(args.y2label)
        ax2.legend(loc='upper right',
            bbox_to_anchor=(1, 1.1),
            ncol=3,
            # fancybox=True,
            # shadow=True,
        )

    plot_from_params(ax2, x, params, sampling_time)

    if args.plot_window:
        plt.show()

    if len(args.out_exts) == 0:
        args.out_exts=['.png']
    for ext in args.out_exts:
        fig.savefig(args.out_file + ext)

    return 0
#-- main

if __name__ == "__main__":
    main()
