#!/usr/bin/env python3

import argparse
import os
import sys
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy.optimize import curve_fit

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
    # {
    #     'short': '-p',
    #     'long': '--plot',
    #     'opts': {
    #         'help': 'Enables plotting of each fit function',
    #         'action': argparse.BooleanOptionalAction,
    #         # 'type': str,
    #         'default': False,
    #     },
    # },
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

# ----------------------------------------------------------

# NOTE: gamma is temperature dependant!
# NOTE: this model requires V as a separate parameter to supply alongside f
# but V is a function of f in the form V ~= alpha * f**2
def power_balsini(f, V, delta, eta, gamma, kappa):
    return delta + ((1 + gamma * V) * (1 + eta) * kappa * V**2 * f)

def power_balsini_compact(f, delta, eta, gamma_V, kappa_V2):
    return delta + ((1 + gamma_V) * (1 + eta) * kappa_V2 * f)

def time_simpler(f, a, b):
    return a + b / f

def time_balsini(f, a, b, c, d):
    return a + b / f + c * np.exp( - f / d )

def f_to_range(adjustment, f):
    return adjustment * f

# ----------------------------------------------------------

ISLAND='island'
HOWMANY='howmany'
FREQ='frequency'
TASK='task'
TIME='time_rel'
POWER='power_mean'

# SUPPOSE ONLY TIME FOR NOW
def fit_values(df, xcol, ycol, fhandle, plot=False, title=''):
    # Input range ~ [0-2] GHz
    x = np.vectorize(lambda f: f_to_range(1/1000000., f))(df[xcol].to_numpy())
    y = df[ycol].to_numpy()

    popt, pcov = curve_fit(fhandle, x, y, check_finite=True)

    # plt.plot(x, y, 'o')
    # plt.plot(x, np.vectorize(lambda f: fhandle(f, *popt))(x), '-')
    # plt.ylim((0, 1.4))
    # plt.title(title)
    # plt.show()

    return pd.DataFrame({ 'params': [popt]})
#-- fit_values


def fit_by_fields(df, xcol, ycol, fhandle, fields, plot=False, title=''):
    if len(fields) < 1:
        return fit_values(df, xcol, ycol, fhandle,
            plot=plot,
            title=title,
        )

    out = pd.DataFrame()
    fields = fields.copy()
    field = fields.pop(0)
    for value in df[field].unique():
        indf = df[df[field] == value]
        outdf = fit_by_fields(indf, xcol, ycol, fhandle, fields,
            plot=plot,
            title=title + ' ' + str(field) + ':' + str(value),
        )
        outdf[field] = value
        out = pd.concat([out, outdf], ignore_index=True)
    return out

def fit_table(df, plot=False):
    fields = [ISLAND, HOWMANY, TASK]
    out = fit_by_fields(df, FREQ, TIME, time_balsini, fields, plot=plot)
    out = out.rename(columns={'params': 'time_params'})

    out2 = fit_by_fields(df, FREQ, TIME, time_simpler, fields, plot=plot)
    out2 = out2.rename(columns={'params': 'time_simpler_params'})

    out = out.merge(out2)

    out2 = fit_by_fields(df, FREQ, POWER, power_balsini_compact, fields, plot=plot)
    out2 = out2.rename(columns={'params': 'power_params'})

    return out.merge(out2)

def main():
    args = parse_cmdline_args()
    df = pd.read_csv(args.in_file, float_precision='high')
    out_df = fit_table(df)
    safe_save_to_csv(out_df, args.out_file)
    pass
#-- main

if __name__ == "__main__":
    main()
