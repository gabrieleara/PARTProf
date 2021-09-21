#!/usr/bin/env python3

import re
import argparse
import sys
import os
import numpy as np
import pandas as pd

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

options = [
    {
        'short': None,
        'long': 'in_files',
        'opts': {
            'metavar': 'in-files',
            'type': argparse.FileType('r'),
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
# |                          Body                          |
# +--------------------------------------------------------+

def rel_time_calc(row, in_field, out_field, task_max_runtime):
    vmax = task_max_runtime[row['task']]
    row[out_field] = row[in_field] / vmax
    return row
#-- rel_time_calc

def rel_time_calc(row, inf, outf, task_max_runtime):
    tm = task_max_runtime[row['task']]
    row[outf] = row[inf] / tm
    return row

def add_col_time_rel(df):
    task_time = {}
    islands = df['island'].unique()
    small_island = islands[0] if len(islands) == 1 else 'little'

    # Calculate max time needed for single execution on the
    # little core, for each task
    in_field = 'time'
    out_field = 'time_rel'

    # Now let's select the minimum frequency on that island for howmany=1
    st = df[df['island'] == small_island]
    st['howmany'] = pd.to_numeric(st['howmany'])
    st = st[st['howmany'] == 1]
    st['frequency'] = pd.to_numeric(st['frequency'])
    min_freq = st['frequency'].min()
    st = st[st['frequency'] == min_freq]

    # Now we have only minimum frequency all samples for
    # howmany=1 on the smallest core
    for task in st['task'].unique():
        st_task = st[st['task'] == task]
        task_time[task] = st_task[in_field].mean()

    if len(task_time) < 1:
        return df

    df = df.apply(
        lambda row: rel_time_calc(row, in_field, out_field, task_time),
        axis=1,
    )
    return df

def last_match(regex, string):
    match = None
    *_, match = regex.finditer(string)
    return match
#-- last_match

def main():
    global args
    args = parse_cmdline_args()

    regexes = {
        'howmany':      r'howmany_(\d+)/',
        'policy':       r'policy_(\w+)/',
        'frequency':    r'freq_(\d+)/',
        'task':         r'task_([\w-]+)/',
    }

    for k in regexes:
        regexes[k] = re.compile(regexes[k])

    out_df = pd.DataFrame(columns=regexes.keys())

    for f in args.in_files:
        data = {}

        fpath = os.path.realpath(f.name)

        # Parse the file path looking for some additional data columns
        for k in regexes:
            data[k] = last_match(regexes[k], fpath).group(1)

        # TODO: fix this from args
        data['policy'] = 'little' if str(data['policy']) == '0' else 'big'

        df = pd.read_csv(f, index_col=0, float_precision='high')
        df.columns = df.columns.str.strip()
        df.loc[:, data.keys()] = data.values()
        print(f.name)
        out_df = out_df.append(df, ignore_index=True)

    # out_df = add_time_rel_col(out_df)

    if len(out_df['policy'].unique()) < 2:
        out_df['policy'] = 'cpu'

    out_df = out_df.rename(columns={'policy':'island'})
    out_df = add_col_time_rel(out_df)

    # Create a temporary file in the destination mount fs
    # (using tmp does not mean that moving = no copy)
    tmpfile_name = os.path.dirname(
        os.path.abspath(args.out_file)
    ) + '/raw_' + str(os.getpid()) + '.tmp'

    # tmpfile_name = '/tmp/raw_' + str(os.getpid()) + '.tmp'
    out_df.to_csv(tmpfile_name, index=None)

    # NOTE: It should be safe this way, but otherwise please
    # disable signal interrupts before this operation

    os.rename(tmpfile_name, args.out_file)

    # NOTE: If disabled, re-enable signal interrupts here
    # (or don't, the program will terminate anyway)

    return 0
#-- main


if __name__ == "__main__":
    main()
