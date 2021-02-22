#!/usr/bin/python3

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


def last_match(regex, string):
    match = None
    *_, match = regex.finditer(string)
    return match
#-- last_match


def df_to_single_row(df):
    df = df.stack().swaplevel()
    df.index = df.index.map('{0[0]}_{0[1]}'.format)
    return df.to_frame().T
#-- df_to_single_row


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

        df = pd.read_csv(f, index_col=0)
        df.columns = df.columns.str.strip()
        df = df_to_single_row(df)
        df.loc[0, data.keys()] = data.values()

        print(f.name)
        out_df = out_df.append(df, ignore_index=True)

    # Create a temporary file in the destination mount fs
    # (using tmp does not mean that moving = no copy)
    tmpfile_name = os.path.dirname(
        os.path.abspath(args.out_file)
    ) + '/raw_' + str(os.getpid()) + '.tmp'

    # tmpfile_name = '/tmp/raw_' + str(os.getpid()) + '.tmp'
    out_df.to_csv(tmpfile_name)

    # NOTE: It should be safe this way, but otherwise please
    # disable signal interrupts before this operation

    os.rename(tmpfile_name, args.out_file)

    # NOTE: If disabled, re-enable signal interrupts here
    # (or don't, the program will terminate anyway)

    return 0
#-- main


if __name__ == "__main__":
    main()
