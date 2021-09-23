#!/usr/bin/env python3

import re

units = {
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

prefixes = {
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

def re_match_unit_group(s: str, unit: str):
    return re.match(
        '.*_([' + LETTERS_ROMAN_GREEK + ']+)' + unit + '$',
        s,
        re.I,
    )

def re_strip_unit_suffix(s: str, unit: str, replace: str):
    return re.sub(
        '_[' + LETTERS_ROMAN_GREEK + ']+' + unit + '$',
        replace,
        s,
    )

def extractprefix(string: str, unit: str):
    string = string.strip()
    match = re_match_unit_group(string, unit)
    return match.group(1) if match else ''


def substitute_unit_suffix(strings, unit: str, replace: str, string: str):
    if string in strings:
        return re_strip_unit_suffix(string, unit, replace)
    return string

def remove_unit_suffix(strings, unit: str, string: str):
    if string in strings:
        return re_strip_unit_suffix(string, unit, '')
    return string
