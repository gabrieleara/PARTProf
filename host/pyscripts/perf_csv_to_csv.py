#!/usr/bin/env python3

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
        'long': 'in_file',
        'opts': {
            'metavar': 'in-file',
            'type': str,
        },
    },
    {
        'short': '-c',
        'long': '--col-map',
        'opts': {
            'help': 'The file that defines mappings between input labels '
                'and output column names',
            'type': str,
            'default': '',
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

def getcolmap(df, colname, colval):
    cmap = {}
    for cname in df[colname].dropna().unique():
        cmap[cname] = df[df[colname] == cname][colval].to_numpy()
    return cmap
#-- getcol


def perf_file_to_csv(inf):
    pd.set_option('display.max_rows', 500)

    df = pd.read_csv(inf,
        skip_blank_lines=True,
        names=[
            'tstamp',
            'cvalue',
            'cunit',
            'cname',
            'cruntime',
            'cpercentage',
            'derivedvalue',
            'derived',
            'time',
            'runcount'],
        )
    # After the last complete execution, drop values (saving only the runcount,
    # which is always the last row)
    maxrow = df['time'].last_valid_index()
    df = df.drop(range((maxrow+1), (len(df.index)-1)))
    # print(df)
    # exit(0)

    # derived = df['derived'].dropna().unique()

    cmap1 = getcolmap(df, 'cname', 'cvalue')
    cmap2 = getcolmap(df, 'derived', 'derivedvalue')
    cmap3 = {
        'time': df['time'].dropna().to_numpy(),
        'runcount': df['runcount'].dropna().to_numpy(),
    }
    # cmap = cmap1 | cmap2 | cmap3

    len1 = len(cmap1[list(cmap1.keys())[0]])
    lentime = len(cmap3['time'])
    lenruncount = len(cmap3['runcount'])

    print("len1:", len1)
    print("lentime:", lentime)
    print("lenruncount:", lenruncount)

    if len1 < lentime:
        # FIXME: fill cmap1 and cmap2 with nan
        pass
    else:
        v = np.empty(len1)
        v[:] = np.nan
        v[np.arange(lentime)] = cmap3['time']
        cmap3['time'] = v

        v = np.empty(len1)
        v[:] = np.nan
        v[np.arange(lenruncount)] = cmap3['runcount']
        cmap3['runcount'] = v

    len1 = len(cmap1[list(cmap1.keys())[0]])
    lentime = len(cmap3['time'])
    lenruncount = len(cmap3['runcount'])
    print("len1:", len1)
    print("lentime:", lentime)
    print("lenruncount:", lenruncount)

    # cmap['time'] = np.pad(cmap['time'], (len1 - lentime) / 2, constant_values=np.nan)
    # cmap['runcount'] = np.pad(cmap['runcount'], (len1 - lenruncount) / 2, constant_values=np.nan)

    cmap = {**cmap1, **cmap2, **cmap3}
    outdf = pd.DataFrame(cmap)
    return outdf
#-- perf_file_to_csv


def call_or_exit_on_file(fname, fun):
    try:
        with open(fname, 'r') as f:
            return fun(f)

    # In case file is not found or another error arises
    except OSError as err:
        print('OS error: {0}'.format(err))
        sys.exit(True)
    except:
        print("Unexpected error:", sys.exc_info()[0])
        raise
#-- call_or_exit_on_file


def main():
    global args
    args = parse_cmdline_args()

    # if args.col_map:
    #     call_or_exit_on_file(args.col_map, load_mapping_from_file)

    df = call_or_exit_on_file(args.in_file, perf_file_to_csv)

    # Create a temporary file in the destination mount fs
    # (using tmp does not mean that moving = no copy)
    tmpfile_name = os.path.dirname(
        os.path.abspath(args.out_file)
    ) + '/raw_' + str(os.getpid()) + '.tmp'

    # tmpfile_name = '/tmp/raw_' + str(os.getpid()) + '.tmp'
    df.to_csv(tmpfile_name, index=None)

    # NOTE: It should be safe this way, but otherwise please
    # disable signal interrupts before this operation

    os.rename(tmpfile_name, args.out_file)

    # NOTE: If disabled, re-enable signal interrupts here
    # (or don't, the program will terminate anyway)

    return 0
#-- main


if __name__ == "__main__":
    main()
