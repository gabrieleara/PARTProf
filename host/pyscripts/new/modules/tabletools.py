#!/usr/bin/env python3

import re

import pandas as pd

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

si_units = {
    # Base
    'second':       's',
    'metre':        'm',
    'gram':         'g',
    'ampere':       'A',
    'kelvin':       'K',
    'mole':         'mol',
    'candela':      'cd',

    # Derived
    'radian':       'rad',
    'steradian':    'sr',
    'hertz':        'Hz',
    'newton':       'N',
    'pascal':       'Pa',
    'joule':        'J',
    'watt':         'W',
    'coulomb':      'C',
    'volt':         'V',
    'farad':        'F',
    'ohm':          'Ω',
    'siemens':      'S',
    'weber':        'Wb',
    'tesla':        'T',
    'henry':        'H',
    'celsius':      'C',
    'lumen':        'lm',
    'lux':          'lx',
    'becquerel':    'Bq',
    'gray':         'Gy',
    'sievert':      'Sv',
    'katal':        'kat',
}

si_prefixes = {
    'Y':    10**24,
    'Z':    10**21,
    'E':    10**18,
    'P':    10**15,
    'T':    10**12,
    'G':    10**9,
    'M':    10**6,
    'k':    10**3,
    'h':    10**2,
    'da':   10**1,
    '':     10**0,
    'd':    10**-1,
    'c':    10**-2,
    'm':    10**-3,
    'μ':    10**-6,
    'u':    10**-6,
    'n':    10**-9,
    'p':    10**-12,
    'f':    10**-15,
    'a':    10**-18,
    'z':    10**-21,
    'y':    10**-24,
}

LETTERS_ROMAN_GREEK = 'A-Za-zΑ-Ωα-ω'

def regex_match_unit_group(s: str, unit: str):
    return re.match(
        '.*_([' + LETTERS_ROMAN_GREEK + ']+)' + unit + '$',
        s,
        re.I,
    )

def regex_strip_unit_suffix(s: str, unit: str, replace: str):
    return re.sub(
        '_[' + LETTERS_ROMAN_GREEK + ']+' + unit + '$',
        replace,
        s,
    )

def si_extractprefix(col: str, unit: str):
    col = col.strip()
    match = regex_match_unit_group(col, unit)
    return match.group(1) if match else ''

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
        prefix = si_extractprefix(c, si_units['second'])
        if len(prefix):
            if error_on_find:
                # TODO: raise an error and terminate
                pass
            the_col = c
            magnitude = si_prefixes[prefix]
            error_on_find = True

    df_update_period = df[ df[the_col] > 0 ]
    if (df[the_col].count() != 1):
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

def substitute_unit_suffix(cols, unit: str , replace: str, c: str):
    if c in cols:
        return regex_strip_unit_suffix(c, unit, replace)
    return c

def remove_unit_suffix(cols, unit: str , c: str):
    if c in cols:
        return regex_strip_unit_suffix(c, unit, '')
    return c
