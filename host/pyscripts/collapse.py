#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
import pandas as pd

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

ref_suffix = 'mean'

suffixes = [
    'mean',
    'min',
    '25%',
    '50%',
    '75%',
    'max',
]

unit_to_field = {
    'uV': 'voltage',
    'uW': 'power',
}

# Order matters (for display reasons only)
base_fields = [
    'howmany',
    'island',
    'task',
    'frequency',
]

interesting_fields = base_fields.copy()

for s in suffixes:
    interesting_fields += ['time' + '_' + s]

# ----------------------------------------------------------


def island_subtable(df, island, islands):
    # This function:
    # - filters only rows containing the specified island
    # - drops columns that refer to data collected for the other
    #   island(s)
    # - remove from column names the name of the island itself
    island_suffix = '_' + island
    df = df[df['island'] == island]

    for other_island in islands:
        if other_island != island:
            df = df.loc[:, ~df.columns.str.contains(other_island)]

    return df.rename(columns=lambda col: col.replace(island_suffix, ''))
#-- island_subtable


def rel_time_calc(row, in_field, out_field, task_max_runtime):
    vmax = task_max_runtime[row['task']]
    row[out_field] = row[in_field] / vmax
    return row
#-- rel_time_calc


def collapse_table(df, reference_field='time'):
    ref_suffix = globals()['ref_suffix']
    suffixes = globals()['suffixes']
    unit_to_field = globals()['unit_to_field']
    interesting_fields = globals()['interesting_fields']

    df = df.rename({'policy': 'island'}, axis='columns')
    islands = df['island'].unique()

    translation_fields = {}
    for island in islands:
        for unit, field in unit_to_field.items():
            original_field = 'sensor_' + island + '_' + unit
            novel_field = field + '_' + island
            translation_fields[original_field] = novel_field
            for s in suffixes:
                interesting_fields += [novel_field + '_' + s]

    # Rename a bunch of fields before starting actual operations
    for k, v in translation_fields.items():
        df = df.rename(columns=lambda col: col.replace(k, v))

    interesting_fields = set.intersection(
        set(df.columns),
        set(interesting_fields)
    )

    df = df[interesting_fields]

    # Get little and big subtables and then re-concat them
    subtables = {}
    for island in islands:
        subtables[island] = island_subtable(df, island, islands)

    df = pd.concat(subtables.values())
    # little = island_subtable(df, 'little', 'big')
    # big = island_subtable(df, 'big', 'little')
    # df = pd.concat([little, big])
    df = df.dropna()

    # Calculate max time needed for single execution on the
    # little core, for each task
    the_suffix = '_' + ref_suffix
    in_field = reference_field + the_suffix
    out_field = reference_field + '_' + 'rel'

    task_max_runtime = {}

    # If only one island, typically it is called 'cpu',
    # otherwise the smallest island is usually called
    # 'little'
    small_island = 'cpu' if 'cpu' in islands else 'little'
    st = subtables[small_island]
    st = st[st['howmany'] == 1]
    for task in st['task'].unique():
        task_max_runtime[task] = st[st['task'] == task][in_field].max()

    # Calculate the new column and drop the suffix
    df = df.apply(
        lambda row: rel_time_calc(row, in_field, out_field, task_max_runtime),
        axis=1,
    )
    # df = df.rename(columns=lambda col: col.replace(the_suffix, ''))
    sorted_fields = base_fields.copy()
    cols = list(df.columns)
    for f in sorted_fields:
        cols.remove(f)
    sorted_fields += list(sorted(cols))
    df = df[sorted_fields]
    df = df.sort_values(by=base_fields, axis='index')
    return df
#-- collapse_table


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


def main():
    args = parse_cmdline_args()
    df = pd.read_csv(args.in_file)
    out_df = collapse_table(df)
    safe_save_to_csv(out_df, args.out_file)

    return 0
#-- main


if __name__ == "__main__":
    main()
