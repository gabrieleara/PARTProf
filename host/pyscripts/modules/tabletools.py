#!/usr/bin/env python3

import re
import pandas as pd

from . import si

def pd_read_csv(
        *args,
        index_col=False,
        float_precision='high',
        **kwargs,
        ):
    """
    Wrapper for pandas.read_csv function that sets some default argument values common throughout this project.
    """
    return pd.read_csv(
        index_col=index_col,
        float_precision=float_precision,
        *args,
        **kwargs,
    )

def extract_update_period(df):
    """
    Remove update period special column and row from the
    original df, returning the modified df and the value of
    the update period as a fraction of a second.
    """
    magnitude = 0
    update_period = 0
    the_col = ''
    error_on_find = False

    # Find update period column with unit
    for c in df.columns:
        prefix = si.extractprefix(c, si.units['second'])
        if len(prefix):
            if error_on_find:
                # TODO: raise an error and terminate
                pass
            the_col = c
            magnitude = si.prefixes[prefix]
            error_on_find = True

    df_update_period = df[ df[the_col] > 0 ]
    if df[the_col].count() != 1:
        # TODO: raise an error and terminate
        pass

    # Extract the value
    update_period = df_update_period[the_col][0]

    # Remove row and column from the original df
    df = df.drop(the_col, axis='columns')
    df = df.drop(df_update_period.index)
    df = df.reset_index(drop=True)

    return df, update_period * magnitude

def extract_breakpoint(df):
    """
    Remove breakpoint special column and row from the
    original df, returning the modified df and the value of
    the breakpoint as a fraction of a second.
    """
    the_col='breakpoint'
    df_breakpoint = df[ df[the_col] > 0 ]
    if (df[the_col].count() != 1):
        # TODO: raise an error and terminate
        pass

    # The value is actually the index, which will be in-between two values in
    # the new df: the index preceding the breakpoint and the index of the
    # element that was originally after the breakpoint, but that after the
    # removal will have the same index as the removed breakpoint itself.
    breakpoint = df_breakpoint[the_col].index[0]
    breakpoint = ((breakpoint-1) + (breakpoint)) / 2.0

    # Remove row and column from the original df
    df = df.drop(the_col, axis='columns')
    df = df.drop(df_breakpoint.index)
    df = df.reset_index(drop=True)

    return df, breakpoint

def select_cols_startwith(cols, string: str):
    return [c for c in cols if c.startswith(string)]

def select_cols_endswith(cols, string: str):
    return [c for c in cols if c.endswith(string)]

def select_sample_cols_freq(cols):
    cols = select_cols_startwith(cols, 'cpu_freq')
    return cols, si.prefixes['k']

def select_sample_cols_temp(cols):
    cols = select_cols_startwith(cols, 'thermal_zone')
    return cols, si.prefixes['m']

def select_sample_cols_power(cols):
    cols = select_cols_startwith(cols, 'sensor')
    cols = select_cols_endswith(cols, si.units['watt'])

    # NOTE: assuming all columns have the same unit
    prefix      = si.extractprefix(cols[0], si.units['watt'])
    magnitude   = si.prefixes[prefix]
    return cols, magnitude

def apply_magnitudes(df, cols, magnitude):
    df[cols] = df[cols] * magnitude
    return df

def select_table_cols_freq(cols):
    return select_cols_startwith(cols, 'freq_')

def select_table_cols_temp(cols):
    return select_cols_startwith(cols, 'temp_')

def select_table_cols_power(cols):
    return select_cols_startwith(cols, 'power_')
