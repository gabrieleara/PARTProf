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

option_defaults = {
    'should_plot' : False,
}

options = [
    {
        'short': None,
        'long': 'in_samples',
        'opts': {
            'metavar': 'in-samples',
            'help': 'the csv containing all (filtered?) samples collected in all runs',
            'type': argparse.FileType('r'),
        },
    },
    {
        'short': None,
        'long': 'in_averages',
        'opts': {
            'metavar': 'in-averages',
            'help': 'the csv containing all average statistics collected over all runs',
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
        'short': '-p',
        'long': '--plot',
        'opts': {
            'help': 'Enables plotting of each fit function',
            'dest': 'should_plot',
            'action': 'store_true',
        },
    },
    {
        'short': None,
        'long': '--no-plot',
        'opts': {
            'help': 'Enables plotting of each fit function',
            'dest': 'should_plot',
            'action': 'store_false',
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

    parser.set_defaults(**option_defaults)

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

def power_balsini_compact_alt(f, delta, eta, gamma_V, kappa_V2):
    return delta + ((1 + gamma_V * f) * (1 + eta) * kappa_V2 * f**3)


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
# POWER='power_mean'
POWER='sensor_cpu_uW'

should_plot=False

# SUPPOSE ONLY TIME FOR NOW
def fit_values(df, xcol, ycol, fhandle,
    values_field='params', title=''):
    # Input range ~ [0-2] GHz expressed in KHz (because of cpufreq)
    x = df[xcol].to_numpy() / 1000000.0
    y = df[ycol].to_numpy()

    whichtodelete = np.argwhere(np.isnan(y))
    x = np.delete(x, whichtodelete)
    y = np.delete(y, whichtodelete)

    popt, pcov = curve_fit(fhandle, x, y, check_finite=True)

    if should_plot:
        y = y[x.argsort()]
        x = x[x.argsort()]
        plt.plot(x, y, 'o')
        plt.plot(x, np.vectorize(lambda f: fhandle(f, *popt))(x), '-')
        # plt.ylim((0, 1.4))
        plt.title(title)
        plt.show()

    return pd.DataFrame({ values_field: [popt]})
#-- fit_values


def fit_by_fields(df, xcol, ycol, fhandle, fields,
    values_field='params', title=''):
    if len(fields) < 1:
        return fit_values(df, xcol, ycol, fhandle, title=title)

    out = pd.DataFrame()
    fields = fields.copy()
    field = fields.pop(0)
    for value in df[field].unique():
        indf = df[df[field] == value]
        outdf = fit_by_fields(indf, xcol, ycol, fhandle, fields,
            values_field=values_field,
            title=title + ' ' + str(field) + ':' + str(value),
        )
        outdf[field] = value
        out = pd.concat([out, outdf], ignore_index=True)
    return out

def prepare_table(df, keyfields, in_field, prefix='', suffix=''):
    newcols = pd.DataFrame(df[in_field].values.tolist(), index=df.index)
    newcols.columns = [
        prefix + str(col) + suffix
        for col in newcols.columns
    ]
    newcols[keyfields] = df[keyfields]
    return newcols

def fit_and_prepare(df, xcol, ycol, keyfields, fhandle, prefix='', suffix=''):
    v_field = 'params'

    outdf = fit_by_fields(df, xcol, ycol, fhandle, keyfields,
        values_field=v_field,
    )

    return prepare_table(
        outdf, keyfields, v_field, prefix=prefix, suffix=suffix,
    )
#-- fit_and_prepare

def fit_table(df):
    keyfields = [ISLAND, HOWMANY, TASK]
    maps = [
        {
            'xcol': FREQ, 'ycol': TIME, 'fhandle': time_balsini,
            'prefix':'param_time',
        },
        {
            'xcol': FREQ, 'ycol': TIME, 'fhandle': time_simpler,
            'prefix':'param_time_simple',
        },
        {
            'xcol': FREQ, 'ycol': POWER, 'fhandle': power_balsini_compact_alt,
            'prefix':'param_power',
        }
    ]

    outdf = df[keyfields].drop_duplicates()
    for m in maps:
        outdf = outdf.merge(
            fit_and_prepare(df, m['xcol'], m['ycol'], keyfields, m['fhandle'],
                prefix=m['prefix'],
            ),
            how='inner',
        )

    return outdf

import re

def main():
    global should_plot
    args = parse_cmdline_args()

    should_plot = args.should_plot
    df_samples = pd.read_csv(args.in_samples, float_precision='high')
    df_averages = pd.read_csv(args.in_averages, float_precision='high')

    outdf = fit_table(df_samples)
    outdf = outdf.merge(df_averages, how='inner')
    outdf = outdf.rename(
        columns=lambda x: re.sub('_mean','',x)
    )

    safe_save_to_csv(outdf, args.out_file)

    import matplotlib.pyplot as plt
    import seaborn as sns

    corr = outdf.corr()
    # corr = corr.loc[['time', 'time_rel', 'power'], :]
    plt.rcParams.update({'font.size': 5})
    sns.heatmap(corr,
        vmin=-1, vmax=1, center=0,
        cmap=sns.diverging_palette(20, 220, n=256),
        square=True,
        annot=True, fmt=".3f",
        xticklabels=corr.columns.values,
        yticklabels=corr.index,
    )
    ax = plt.gca()
    ax.set_xticklabels(
        ax.get_xticklabels(),
        rotation=45, horizontalalignment='right', rotation_mode="anchor")
    ax.grid(False, 'major')
    ax.grid(True, 'minor')
    ax.set_xticks([t + 0.5 for t in ax.get_xticks()], minor=True)
    ax.set_yticks([t + 0.5 for t in ax.get_yticks()], minor=True)
    plt.show()

    return 0
#-- main

if __name__ == "__main__":
    main()
