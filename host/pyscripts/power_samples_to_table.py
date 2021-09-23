#!/usr/bin/env python3

import re

import numpy    as np
import pandas   as pd

from modules import cmap
from modules import cmdargs
from modules import maketools
from modules import tabletools

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

cmdargs_conf = {
    "options": [
        {
            'short': None,
            'long': 'in_file',
            'opts': {
                'metavar': 'in-file',
                'type': cmdargs.argparse.FileType('r'),
            },
        },
        {
            'short': '-c',
            'long': '--col-map',
            'opts': {
                'help': 'The file that defines mappings between input labels '
                    'and output column names',
                'default': '',
                'type': cmdargs.argparse.FileType('r'),
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
}

# +--------------------------------------------------------+
# |             Units Management in line names             |
# +--------------------------------------------------------+

# TODO: use the new si.py module
def cartesian_prod(x, y):
    return np.transpose([np.tile(x, len(y)), np.repeat(y, len(x))])

base_units = ['W', 'A', 'V', 'C', 's']
unit_modifiers = ['', 'm', 'u']

# Examples: W, mW, uW
known_units = [
    ''.join(map(str, x)) for x in cartesian_prod(unit_modifiers, base_units)
]

known_units_underscore = tuple(["_" + x for x in known_units])


# +--------------------------------------------------------+
# |                          Body                          |
# +--------------------------------------------------------+

# Ignored columns
# TODO: check again this list
ignore_list = ['FOREVER:', 'gzip:', 'Command', 'Run']

def powerfile_to_table(inf, column_map):
    df = pd.DataFrame()
    kvalues = {}

    for line in inf:
        if len(line.strip()) < 1:
            # Append to dataframe
            if kvalues:
                df = df.append(kvalues, ignore_index=True)
            kvalues = {}
        else:
            # Parse line and add it to the dictionary
            split = line.split()
            k = split[0].strip()
            vv = split[1:]

            if (k.startswith('----------')):
                k = 'breakpoint'
                vv = '1'

            # Some columns are already in the _ format, but I don't like it,
            # I prefer to do it manually in python so that I can change the
            # mapping
            # TODO:

            if k.endswith(known_units_underscore):
                ssplit = k.split('_')
                k = '_'.join(ssplit[0:-1])
                vv = [ssplit[-1]] + vv

            # Remap columns based on the configured mapping
            if k in column_map:
                k = column_map[k]

            # Units will be embedded in column names
            if len(vv) > 1 and vv[0].strip() in known_units:
                k += '_' + vv[0].strip()
                vv = vv[1:]

            needs_suffix = len(vv) > 1

            if k in ignore_list:
                continue

            # Keys with multiple values will be split
            # into multiple columns in the resulting CSV
            for idx, v in enumerate(vv):
                key = k + '_' + str(idx) if needs_suffix else k

                if ('time' in key and float(v.strip()) < 0.05):
                    continue

                kvalues[key] = v.strip()

    # Append to dataframe
    if kvalues:
        df = df.append(kvalues, ignore_index=True)
    kvalues = {}

    return df
#-- powerfile_to_table

#----------------------------------------------------------#
#                           Main                           #
#----------------------------------------------------------#


def table_convert_form(df):
    df, update_period = tabletools.extract_update_period(df)
    df, breakpoint    = tabletools.extract_breakpoint(df)

    columns = df.columns
    cols_in_freq,  magnitude_freq  = tabletools.select_sample_cols_freq(columns)
    cols_in_temp,  magnitude_temp  = tabletools.select_sample_cols_temp(columns)
    cols_in_power, magnitude_power = tabletools.select_sample_cols_power(columns)

    df = tabletools.apply_magnitudes(df, cols_in_freq, magnitude_freq)
    df = tabletools.apply_magnitudes(df, cols_in_temp, magnitude_temp)
    df = tabletools.apply_magnitudes(df, cols_in_power, magnitude_power)

    numrows = len(df.index)

    outdf = pd.DataFrame()
    outdf['time'] = np.arange(numrows) * update_period

    empty = np.full(numrows, np.nan)
    up = empty.copy()
    up[0] = update_period
    bp = empty.copy()
    bp[0] = breakpoint

    outdf['sampling_time']  = up
    outdf['breakpoint']     = bp

    cols_out_freq = [
        c.replace('cpu_freq', 'freq_cpu')
        for c in cols_in_freq
    ]

    cols_out_temp = [
        c.replace('thermal_zone_temp', 'temp_tz')
        for c in cols_in_temp
    ]

    cols_out_power = [
        re.sub(r'sensor_([a-z]+)_.*', r'power_\1', c, flags=re.I)
        for c in cols_in_power
    ]

    outdf[cols_out_freq]    = df[cols_in_freq]
    outdf[cols_out_temp]    = df[cols_in_temp]
    outdf[cols_out_power]   = df[cols_in_power]

    return outdf


def main():
    args = cmdargs.parse_args(cmdargs_conf)

    column_map = {}
    if args.col_map:
        column_map = cmap.loadmap(args.col_map.readlines())

    df = powerfile_to_table(args.in_file, column_map)

    for c in df.columns:
        outc = pd.to_numeric(df[c])
        df[c] = outc

    outdf = table_convert_form(df)
    maketools.df_safe_to_csv(outdf, args.out_file)
    return 0
#-- main

if __name__ == "__main__":
    main()
