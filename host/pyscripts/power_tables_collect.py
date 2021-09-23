#!/usr/bin/env python3

import pandas as pd

from modules import cmdargs
from modules import cpuislands
from modules import maketools
from modules import tabletools
from modules import timetools

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

cmdargs_conf = {
    "options": [
        {
            'short': None,
            'long': 'in_files',
            'opts': {
                'metavar': 'in-files',
                'type': cmdargs.argparse.FileType('r'),
                'nargs': '+',
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
    ],
    'required_options': [
        {
            'short': '-i',
            'long': '--island',
            'opts': {
                'help': 'The name of an island',
                'type': str,
                # 'nargs': '+',
                'action': 'append',
            },
        },
        {
            'short': '-c',
            'long': '--cpus',
            'opts': {
                'help': 'The range or list of cpus of that island',
                'type': str,
                # 'nargs': '+',
                'action': 'append',
            },
        },
        {
            'short': '-p',
            'long': '--policy',
            'opts': {
                'help': 'The numeric policy assigned to each island',
                'type': str,
                # 'nargs': '+',
                'action': 'append',
            },
        },
    ]
}

#----------------------------------------------------------#
#                           Main                           #
#----------------------------------------------------------#


def power_table_to_row(df):
    sampling_time   = df['sampling_time'].dropna()[0]
    breakpoint      = df['breakpoint'].dropna()[0]

    columns         = df.columns
    cols_freq       = tabletools.select_table_cols_freq(columns)
    cols_temp       = tabletools.select_table_cols_temp(columns)
    cols_power      = tabletools.select_table_cols_power(columns)

    df_active       = df.loc[:int(breakpoint)]
    df_cooldown     = df.loc[int(breakpoint):]

    time_active     = df_active['time'].to_numpy()
    time_cooldown   = df_cooldown['time'].to_numpy()

    # Steps:
    #  - a. check that cpu_freq for all cpus is fixed
    #  - b. get steady state temperature in active phase
    #  - c. get steady state temperature in cooldown phase
    #  - d. get time constant temperature in active phase
    #  - e. get steady state power in active phase

    row = { 'sampling_time': sampling_time }

    # a.
    for c in cols_freq:
        freq_mean  = c.replace('freq_cpu', 'freq_cpu')
        freq_check = c.replace('freq_cpu', 'freq_cpu_check')
        row[freq_mean]  = df[c].mean()
        row[freq_check] = timetools.is_unique_value(df[c])

    # b., c., d.
    for c in cols_temp:
        temp_high       = c.replace('temp_tz', 'temp_tz_high')
        temp_low        = c.replace('temp_tz', 'temp_tz_low')
        temp_tau_rise   = c.replace('temp_tz', 'temp_tz_tau_rise')
        temp_tau_fall   = c.replace('temp_tz', 'temp_tz_tau_fall')

        time_series_active   = timetools.smooth(df_active[c].to_numpy())
        time_series_cooldown = timetools.smooth(df_cooldown[c].to_numpy())

        row[temp_high]      = timetools.steady_value(time_series_active)
        row[temp_low]       = timetools.steady_value(time_series_cooldown)

        row[temp_tau_rise]  = timetools.time_constant(
            time_active, time_series_active, row[temp_low], row[temp_high])

        row[temp_tau_fall]  = timetools.time_constant(
            time_cooldown, time_series_cooldown, row[temp_high], row[temp_low])

    # e.
    for c in cols_power:
        row[c] = timetools.steady_value(df_active[c])

    return row


def main():
    args = cmdargs.parse_args(cmdargs_conf)

    rows = {}

    island_cpus_map = cpuislands.island_cpus_map(args.island, args.cpus)
    policy_island_map = cpuislands.policy_island_map(args.island, args.policy)

    for in_file in args.in_files:
        df = tabletools.pd_read_csv(in_file)

        metadata = maketools.extract_metadata(in_file, policy_island_map, island_cpus_map)
        print(metadata)

        row = power_table_to_row(df)
        row = {**metadata, **row}

        for c in row:
            if c in rows:
                rows[c].append(row[c])
            else:
                rows[c] = [row[c]]

    outdf = pd.DataFrame.from_dict(rows)

    maketools.df_safe_to_csv(outdf, args.out_file)
    return 0
#-- main

if __name__ == "__main__":
    main()
