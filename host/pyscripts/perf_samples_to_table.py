#!/usr/bin/env python3

"""
Convert input file produced by `forever+perf` into a well-formed CSV table.

This file comes embedded with some regexes used to filter out lines before
reading the original table. If you encounter problems, check that the
troublesome lines are removed accordingly or provide approproiate regexes if
needed.
"""

import io
import re

from modules import cmdargs
from modules import maketools

import numpy as np
import pandas as pd

# +--------------------------------------------------------+
# |          Command-line Arguments Configuration          |
# +--------------------------------------------------------+

cmdargs_conf = {
    'options': [
        {
            'short': None,
            'long': 'in_file',
            'opts': {
                'metavar': 'in-file',
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
    ],
}

# Magic: do not touch
def getcolmap(df, colname, colval):
    colmap = {}
    for cname in df[colname].dropna().unique():
        colmap[cname] = df[df[colname] == cname][colval].to_numpy()
    return colmap
#-- getcolmap

def perf_file_to_csv(inf):
    # Preprocess file to eliminate unwanted lines
    def read_processed_csv(inf, *args, **kwargs):
        lines = ''.join(
            [re.sub('^stress-ng:', '# ', line, flags=re.M)
                for line in open(inf)])
        return pd.read_csv(io.StringIO(lines), *args, comment='#', **kwargs)
    #--

    df = read_processed_csv(inf,
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
            'runcount',
        ],
    )

    # What to do:
    # 1. drop all values after the last completed execution, dropping values
    #    from interrupted runs
    # 2. substitute '<not counted>' values with zeroes (mainly for the idle
    #    task)
    # 3. rotate the table so that all samples have the same format
    #
    # NOTE: the value of 'runcount' can be inferred by the number of values in
    # the 'time' column, so it can be safely dropped

    # 1.
    range_to_drop = range(
        df['time'].last_valid_index() + 1,
        len(df.index)
    )
    df = df.drop(range_to_drop)

    # 2.
    df = df.replace(to_replace="<not counted>", value=0)

    # 3.

    # First, let's extract perf values
    cmap = {}
    cmap = {**cmap, **getcolmap(df, 'cname', 'cvalue')}
    cmap = {**cmap, **getcolmap(df, 'derived', 'derivedvalue')}
    perf_df = pd.DataFrame(cmap)

    # Now we select the time values
    time_values = df['time'].dropna().to_numpy()
    number_of_iterations = len(time_values)

    # We separate perf values of different iterations with empty lines, so that
    # we can put the time duration of each iteration in-between on a new column
    perf_columns = perf_df.columns
    nans = np.full(len(perf_columns), np.nan)
    empty_line = pd.DataFrame([nans], columns=perf_columns)

    outdf = pd.DataFrame([], columns=perf_columns)
    ratio = len(perf_df.index) // number_of_iterations

    # We alternate between 'ratio' rows of perf values and
    # one empty separation line
    for i in range(number_of_iterations):
        df_split = perf_df.iloc[(i * ratio):((i+1) * ratio),:]
        if outdf.empty:
            outdf = pd.concat([df_split, empty_line], ignore_index=True)
        else:
            outdf = pd.concat([outdf, df_split, empty_line], ignore_index=True)

    # The new time column is all empty, apart for those
    # values that go in-between iterations
    time_column = np.full(len(outdf.index), np.nan)
    for i, v in enumerate(np.ndarray.tolist(time_values)):
        time_column[(i+1) * (ratio) + i] = v

    outdf['time'] = time_column

    return outdf
#-- perf_file_to_csv

def main():
    args = cmdargs.parse_args(cmdargs_conf)
    df = perf_file_to_csv(args.in_file)
    maketools.df_safe_to_csv(df, args.out_file)
    return 0
#-- main


if __name__ == "__main__":
    main()
