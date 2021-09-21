#!/usr/bin/env python3

"""
Plot values of CSV files over time

You can pass multiple CSV files and each will be used to
plot the values.

Among the assumptions that this script makes:
 - values are ordered over time
 - each column represents a single instant in time
 - there may be two special rows with special values:
    1. a special row at the beginning of the file, containig
       the only value for the column "UPDATE_PERIOD_[unit]",
       where unit is an ascii representation of a
       time-measurement unit (e.g. us for microseconds).
    2. a special row in the middle of the file separates
       values collected while the application is running
       from the ones collected during cooldown times,
       containing the only value for the column
       "breakpoint".
"""

import argparse
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

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
            'action': 'append',
            'default': [],
        },
    },
]

required_options = [
    {
        'short': '-y1',
        'long': '--y1columns',
        'opts': {
            'help': 'The columns to use on the y1 axis',
            'action': 'append',
            'default': [],
        },
    },
]

def parse_cmdline_args():
    class CustomFormatter(
        argparse.ArgumentDefaultsHelpFormatter,
        argparse.RawDescriptionHelpFormatter):
        pass

    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=CustomFormatter,
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

# +--------------------------------------------------------+
# |              Data Manipulation Functions               |
# +--------------------------------------------------------+


def smooth(numpy, x, window_len=11,window='hanning'):
    """smooth the data using a window with requested size.

    This method is based on the convolution of a scaled window with the signal.
    The signal is prepared by introducing reflected copies of the signal
    (with the window size) in both ends so that transient parts are minimized
    in the begining and end part of the output signal.

    input:
        x: the input signal
        window_len: the dimension of the smoothing window; should be an odd integer
        window: the type of window from 'flat', 'hanning', 'hamming', 'bartlett', 'blackman'
            flat window will produce a moving average smoothing.

    output:
        the smoothed signal

    example:

    t=linspace(-2,2,0.1)
    x=sin(t)+randn(len(t))*0.1
    y=smooth(x)

    see also:

    numpy.hanning, numpy.hamming, numpy.bartlett, numpy.blackman, numpy.convolve
    scipy.signal.lfilter

    TODO: the window parameter could be the window itself if an array instead of a string
    NOTE: length(output) != length(input), to correct this: return y[(window_len/2-1):-(window_len/2)] instead of just y.
    """

    if x.ndim != 1:
        raise ValueError("smooth only accepts 1 dimension arrays.")

    if x.size < window_len:
        raise ValueError("Input vector needs to be bigger than window size.")


    if window_len<3:
        return x


    if not window in ['flat', 'hanning', 'hamming', 'bartlett', 'blackman']:
        raise ValueError("Window is one of 'flat', 'hanning', 'hamming', 'bartlett', 'blackman'")


    s=numpy.r_[x[window_len-1:0:-1],x,x[-2:-window_len-1:-1]]
    #print(len(s))
    if window == 'flat': #moving average
        w=numpy.ones(window_len,'d')
    else:
        w=eval('numpy.'+window+'(window_len)')

    y=numpy.convolve(w/w.sum(),s,mode='valid')
    return y



# +--------------------------------------------------------+
# |                   Plotting Functions                   |
# +--------------------------------------------------------+

# TODO: scale down xvals based on update period!

def plot_timey(ax, update_period, yvals, label, color=''):
    args = {} if len(color) < 1 else { 'color': color, }
    yvals = smooth(np, yvals, window_len=5, window='flat')
    yvals = yvals - np.min(yvals)
    xvals = np.arange(yvals.shape[0]) * update_period
    ax.plot(xvals, yvals,
        # marker='.',
        alpha=.8,
        label=label,
        linewidth=1,
        **args,
    )


# def plot_xy(ax, xvals, yvals, label, color=''):
#     # Assuming yvals
#     # yvals = yvals[xvals.argsort()]
#     # xvals = xvals[xvals.argsort()]

#     yvals = np.reshape(yvals, (-1))
#     # xvals = np.reshape(xvals, (-1))
#     print(yvals)

#     yvals = smooth(np, yvals)

#     if len(color) > 0:
#         ax.plot(xvals, yvals,
#             # marker='.',
#             alpha=.8,
#             label=label,
#             linewidth=1,
#             color=color,
#         )
#     else:
#         ax.plot(xvals, yvals,
#             marker='.',
#             alpha=.8,
#             label=label,
#             linewidth=1,
#         )

#-- plot_xy

def plot_indexed_values(ax, df, update_period, y_field, label, color=''):
    plot_timey(ax, update_period, df[y_field].to_numpy(), label, color)
#-- plot_indexed_values

# def plot_series(ax, df, x_field, y_field, label):
#     plot_xy(ax, df[x_field].to_numpy(), df[y_field].to_numpy(), label)
# #-- plot_series

# +--------------------------------------------------------+
# |                  Selecting Functions                   |
# +--------------------------------------------------------+

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

# +--------------------------------------------------------+
# |                          Main                          |
# +--------------------------------------------------------+

units = {
    'Y':    10**24,
    'Z':    10**21,
    'E':    10**18,
    'P':    10**15,
    'T':    10**12,
    'G':    10**9,
    'M':    10**6,
    'k':    10**3,
    'h':    10**2,
    'da':   10**1,
    '':     10**0,
    'd':    10**-1,
    'c':    10**-2,
    'm':    10**-3,
    'μ':    10**-6,
    'u':    10**-6,
    'n':    10**-9,
    'p':    10**-12,
    'f':    10**-15,
    'a':    10**-18,
    'z':    10**-21,
    'y':    10**-24,
}

def extract_timeunit(s: str):
    if s in units:
        return units[s]
    return 1

def extract_update_period(df):
    """
    Remove update period special column and row from the
    original df, returning the modified df and the value of
    the update period as a fraction of a second.
    """
    unit = 0
    update_period = 0
    the_col = ''
    error_on_find = False

    # Find update period column with unit
    for c in df.columns:
        match = re.match('update_period_([a-z]+)s', c, re.I)
        if match:
            if error_on_find:
                # TODO: raise an error and terminate
                pass
            the_col = c
            unit = extract_timeunit(match.group(1))
            error_on_find = True

    df_update_period = df[ df[the_col] > 0 ]
    if (df[the_col].count() != 1):
        # TODO: raise an error and terminate
        pass

    # Extract the value
    update_period = df_update_period[the_col][0]

    # Remove row and column from the original df
    df = df.drop(the_col, axis='columns')
    df = df.drop(df_update_period.index)
    df = df.reset_index(drop=True)

    return df, update_period * unit

def extract_breakpoint(df, update_period):
    """
    Remove breakpoint special column and row from the
    original df, returning the modified df and the value of
    the breakpoint as a fraction of a second.
    """
    the_col='breakpoint'
    df_breakpoint = df[ df[the_col] > 0 ]
    if (df[the_col].count() != 1):
        # TODO: raise an error and terminate
        pass

    # The value is actually the index, which will be in-between two values in
    # the new df: the index preceding the breakpoint and the index of the
    # element that was originally after the breakpoint, but that after the
    # removal will have the same index as the removed breakpoint itself.
    breakpoint = df_breakpoint[the_col].index[0]
    breakpoint = ((breakpoint-1) + (breakpoint)) / 2.0

    # Remove row and column from the original df
    df = df.drop(the_col, axis='columns')
    df = df.drop(df_breakpoint.index)
    df = df.reset_index(drop=True)

    return df, breakpoint * update_period

# import os

def read_df_data(f):
    """
    Reads a CSV input file and returns the following constructs:
     - df (excluding special columns)
     - update_period [in seconds, fractional]
     - breakpoint [in seconds, fractional]
    """
    # label = os.path.dirname(f.name) + '/' + os.path.basename(os.path.realpath(f.name)).replace('.csv', '')
    df = pd.read_csv(f, index_col=False, float_precision='high')
    df, update_period = extract_update_period(df)
    df, breakpoint = extract_breakpoint(df, update_period)
    return df, update_period, breakpoint
#-- read_df_pairs

def main():
    args = parse_cmdline_args()
    df, update_period, breakpoint = read_df_data(args.in_file)

    fig, ax1 = plt.subplots()
    fig.set_figheight(8)
    fig.set_figwidth(12)

    for y1col in args.y1columns:
        plot_indexed_values(ax1, df, update_period, y1col, y1col, 'red')

    ax1.axvline(breakpoint)
    ax1.set_xlabel(args.xlabel if args.xlabel != None else 'Time [s]')
    ax1.set_ylabel(args.y1label if args.y1label != None else args.y1columns[0])
    ax1.grid()

    ax1.legend(loc='upper left',
        bbox_to_anchor=(0, 1.1),
        ncol=3,
        # fancybox=True,
        # shadow=True,
    )

    if len(args.y2columns):
        ax2 = ax1.twinx()
        ax2.set_ylabel(args.y2label if args.y2label != None else args.y2columns[0])
        for y2col in args.y2columns:
            plot_indexed_values(ax2, df, update_period, y2col, y2col)
        ax2.legend(loc='upper right',
            bbox_to_anchor=(1, 1.1),
            ncol=3,
            # fancybox=True,
            # shadow=True,
        )

    fig.tight_layout()

    if args.plot_window:
        plt.show()

    if len(args.out_exts) == 0:
        args.out_exts=['.png']
    for ext in args.out_exts:
        fig.savefig(args.out_file + ext)
#-- main

if __name__ == "__main__":
    main()
