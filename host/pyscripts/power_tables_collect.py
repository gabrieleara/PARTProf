#!/usr/bin/env python3

import re
import sys

import pandas as pd

import modules.cmdargs as cmdargs
import modules.cpuislands as cpuislands
import modules.maketools as maketools
import modules.tabletools as tabletools
import modules.timetools as timetools

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

def match_last(regex: re.Pattern, string: str):
    match = None
    *_, match = regex.finditer(string)
    return match
#-- match_last

def select_cols_startwith(cols, string: str):
    return [c for c in cols if c.startswith(string)]

def select_cols_endswith(cols, string: str):
    return [c for c in cols if c.endswith(string)]

def select_cols_freq(cols):
    cols = select_cols_startwith(cols, 'cpu_freq')
    return cols, tabletools.si_prefixes['k']

def select_cols_temp(cols):
    cols = select_cols_startwith(cols, 'thermal_zone')
    return cols, tabletools.si_prefixes['m']

def select_cols_power(cols):
    cols = select_cols_startwith(cols, 'sensor')
    cols = select_cols_endswith(cols, tabletools.si_units['watt'])

    # NOTE: assuming all columns have the same unit
    prefix = tabletools.si_extractprefix(cols[0], tabletools.si_units['watt'])
    magnitude = tabletools.si_prefixes[prefix]
    return cols, magnitude

def apply_magnitudes(df, cols, magnitude):
    df[cols] = df[cols] * magnitude
    return df

def power_table_to_row(df):
    df, update_period = tabletools.extract_update_period(df)
    df, breakpoint = tabletools.extract_breakpoint(df)

    columns = df.columns
    cols_freq, magnitude_freq = select_cols_freq(columns)
    cols_temp, magnitude_temp = select_cols_temp(columns)
    cols_power, magnitude_power = select_cols_power(columns)

    df = apply_magnitudes(df, cols_freq, magnitude_freq)
    df = apply_magnitudes(df, cols_temp, magnitude_temp)
    df = apply_magnitudes(df, cols_power, magnitude_power)

    df_active = df.loc[:breakpoint]
    df_cooldown = df.loc[breakpoint:]

    # Steps:
    #  - a. check that cpu_freq for all cpus is fixed
    #  - b. get steady state temperature in active phase
    #  - c. get steady state temperature in cooldown phase
    #  - d. get time constant temperature in active phase
    #  - e. get steady state power in active phase

    row = { 'sampling_time': update_period }

    # a.
    for c in cols_freq:
        freq_mean  = c.replace('cpu_freq', 'freq_cpu')
        freq_check = c.replace('cpu_freq', 'freq_cpu_check')
        row[freq_mean]  = df[c].mean()
        row[freq_check] = timetools.is_unique_value(df[c])

    # b., c., d.
    for c in cols_temp:
        time_series_active = timetools.smooth(
            df_active[c].to_numpy(), window_len=5, window='flat')
        time_series_cooldown = timetools.smooth(
            df_cooldown[c].to_numpy(), window_len=5, window='flat')

        temp_final  = c.replace('thermal_zone_temp', 'temp_tz_final')
        temp_begin  = c.replace('thermal_zone_temp', 'temp_tz_begin')
        temp_tau    = c.replace('thermal_zone_temp', 'temp_tz_tau')

        row[temp_final] = timetools.steady_value(time_series_active)
        row[temp_begin] = timetools.steady_value(time_series_cooldown)
        row[temp_tau]   = update_period * \
            timetools.time_constant(time_series_active,
                row[temp_begin],
                row[temp_final])

    # e.
    for c in cols_power:
        power_island = re.sub(r'sensor_([a-z]+)_.*', r'power_\1', c, flags=re.I)
        row[power_island] = timetools.steady_value(df_active[c])

    return row

import os

REGEXES = {
    'howmany':      r'howmany_(\d+)/',
    'island':       r'policy_(\w+)/',
    'frequency':    r'freq_(\d+)/',
    'task':         r'task_([\w-]+)/',
    'cpu':          r'(\d+)/',
}

for k in REGEXES:
    REGEXES[k] = re.compile(REGEXES[k])

def extract_metadata(file, policy_island_map, island_cpus_map):
    filepath = os.path.realpath(file.name)

    metadata = {}
    for k in REGEXES:
        metadata[k] = match_last(REGEXES[k], filepath).group(1)

    # Map policy to correct island name
    if not metadata['island'] in policy_island_map:
        sys.exit("Policy " + str(metadata['island']) + " not present in current mapping! Use --help for help.")

    metadata['island']  = policy_island_map[metadata['island']]

    if not metadata['island'] in island_cpus_map:
        sys.exit("Island " + str(metadata['island']) + " not present in current mapping! Use --help for help.")

    try:
        metadata['cpu'] = int(metadata['cpu'])-1
    except ValueError:
        sys.exit("CPU '" + str(metadata['cpu']) + "is not a valid CPU number!")

    cpus = island_cpus_map[metadata['island']]
    if metadata['cpu'] > len(cpus):
        sys.exit("CPU '" + str(metadata['cpu']) + "is not a valid CPU number for the island " + metadata['island'] + " !")

    # Maps the cpus in order from 0,1,2,3 to the correct numbers inside the island
    metadata['cpu'] = cpus[metadata['cpu']]

    return metadata

def main():
    args = cmdargs.parse_args(cmdargs_conf)

    rows = {}

    print(args.island)
    print(args.cpus)

    island_cpus_map = cpuislands.island_cpus_map(args.island, args.cpus)
    policy_island_map = cpuislands.policy_island_map(args.island, args.policy)
    print(policy_island_map)
    print(island_cpus_map)

    for in_file in args.in_files:
        df = tabletools.pd_read_csv(in_file)

        metadata = extract_metadata(in_file, policy_island_map, island_cpus_map)
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
