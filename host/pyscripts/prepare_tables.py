#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
import pandas as pd

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

def dir_path(string):
    Path(string).mkdir(parents=True, exist_ok=True)
    return string
#-- dir_path

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
        'long': '--out-dir',
        'opts': {
            'help': 'The output directory where to create all the tables',
            'type': dir_path,
            'default': 'out.d',
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


def produce_tables(df, out_path):
    howmanies = df['howmany'].unique()
    islands = df['island'].unique()
    tasks = df['task'].unique()

    # TODO: safe save to CSV

    # # Alternative implementation of the following first for loop:
    # for (h, i, t) in itertools.product(howmanies, islands, tasks):
    #     cur_dir = out_path + \
    #         '/howmany_' + str(h) + \
    #         '/island' + i
    #     Path(cur_dir).mkdir(parents=True, exist_ok=True)
    #     tout = df
    #     tout = tout[tout['howmany'] == h]
    #     tout = tout[tout['island'] == i]
    #     tout = tout[tout['task'] == t]
    #     tout = tout.sort_values(by=['frequency'])
    #     safe_save_to_csv(tout, cur_dir + '/task_' + t + '.csv')

    for h in howmanies:
        h_df = df[df['howmany'] == h]
        for i in islands:
            i_df = h_df[h_df['island'] == i]
            cur_dir = out_path + \
                '/howmany_' + str(h) + \
                '/island_' + i
            Path(cur_dir).mkdir(parents=True, exist_ok=True)
            for t in tasks:
                tout = i_df[i_df['task'] == t]
                tout = tout.sort_values(by=['frequency'])
                safe_save_to_csv(tout, cur_dir + '/task_' + t + '.csv')

    nan = float('nan')

    for i in islands:
        i_df = df[df['island'] == i]
        for freq in i_df['frequency'].unique():
            f_df = i_df[i_df['frequency'] == freq]

            idle = f_df
            idle = idle[idle['task'] == 'idle']
            idle = idle[idle['howmany'] == 1]

            # Needed because I'm about to change the content
            # of the table (multiple times). This should
            # contain one row anyway.
            idle = idle.copy(deep=True)

            # All actual fields that are not power/temperature will be nan
            idle['howmany']  = 0
            idle['time']     = nan
            idle['time_rel'] = nan

            cur_dir = out_path + '/MULTI' + \
                '/island_' + i + \
                '/freq_' + str(freq)
            Path(cur_dir).mkdir(parents=True, exist_ok=True)

            for t in f_df['task'].unique():
                idle['task'] = t
                tout = f_df[f_df['task'] == t]
                tout = pd.concat([idle, tout])
                tout = tout.sort_values(by=['howmany'])
                #TODO: safe save
                safe_save_to_csv(tout, cur_dir + '/task_' + t + '.csv')
#-- produce_tables

#----------------------------------------------------------#

def main():
    args = parse_cmdline_args()
    df = pd.read_csv(args.in_file)
    produce_tables(df, args.out_dir)

    return 0
#-- main

if __name__ == "__main__":
    main()
