#!/usr/bin/python3

import argparse
import sys
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


# +--------------------------------------------------------+
# |             Units Management in line names             |
# +--------------------------------------------------------+

def cartesian(x, y):
    return np.transpose([np.tile(x, len(y)), np.repeat(y, len(x))])


base_units = ['W', 'A', 'V', 'C']
unit_modifiers = ['', 'm', 'u']

# Examples: W, mW, uW
known_units = [
    ''.join(map(str, x)) for x in cartesian(unit_modifiers, base_units)
]

# +--------------------------------------------------------+
# |            Mapping labels to output columns            |
# +--------------------------------------------------------+

col_mapping = {}


def load_mapping_from_file(cinf):
    global col_mapping
    col_mapping = {}

    for line in cinf:
        if len(line.strip()) < 1:
            # Skip
            pass
        else:
            split = line.split('=', 2)  # sep, maxsplit
            # TODO: error management
            k = split[0]
            v = split[1]
            col_mapping[k] = v.strip()
#-- load_mapping_from_file


# +--------------------------------------------------------+
# |                          Body                          |
# +--------------------------------------------------------+

def rawfile_to_df(inf):
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
            k = split[0]
            vv = split[1:]

            # Remap columns based on the configured mapping
            if k in col_mapping:
                k = col_mapping[k]

            # Units will be embedded in column names
            if len(vv) > 1 and vv[0] in known_units:
                k += '_' + vv[0]
                vv = vv[1:]

            needs_suffix = len(vv) > 1

            # Keys with multiple values will be split
            # into multiple columns in the resulting CSV
            for idx, v in enumerate(vv):
                key = k + '_' + str(idx) if needs_suffix else k
                kvalues[key] = v.strip()

    # Append to dataframe
    if kvalues:
        df = df.append(kvalues, ignore_index=True)
    kvalues = {}

    return df
#-- rawfile_to_df


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
#-- def call_or_exit_on_file


def main():
    global args
    args = parse_cmdline_args()

    if args.col_map:
        call_or_exit_on_file(args.col_map, load_mapping_from_file)

    df = call_or_exit_on_file(args.in_file, rawfile_to_df)
    df.to_csv(args.out_file, index=None)

    return 0
#-- main


if __name__ == "__main__":
    main()
