#!/usr/bin/env python3

import math
import operator

import numpy as np

"""
Contains a number of checks that can be performed on time series of values.

In each of these functions, time is considered discrete.
"""

def __check_start_end(values, start, end):
    """
    Checks whether the given indexes are valid within the array-like provided.

    Start must be greater than end, otherwise end will wrap around to the last
    valid index.

    The start must be included, the end is excluded.
    """
    if start < 0:
        start = 0
    if end < start or end > len(values):
        end = len(values)
    return start, end


def __first_match_index(iterable, condition = lambda x: True):
    """
    Returns the index of the first element in iterable that matches the given
    condition.
    """
    for i, v in enumerate(iterable):
        if condition(v):
            return i
    return {}

def is_unique_value(values):
    """
    Returns True if the given array-like has only one single value (or no
    values).
    """
    return len(np.unique(values)) < 2


# TODO: this is not a proper way to check for the steady state value, because it
# assumes that the settling time of the system of these values is less than the
# time needed to reach mid_fraction
def steady_value(values,    # must be contiguous non-NaN values
    start=0,                # first index to consider within values (included)
    end=-1,                 # last index within the values (excluded)
    edge_fraction = 0.1,    # fraction of values to skip at the beginning/end of the array
    mid_fraction=0.75,      # fraction of values to skip before calculating the steady state
    ):
    """
    Returns the steady value of the time series given as input.

    The beginning and ending indexes can be provided as input as well, or you
    can use slicing.
    """
    start, end  = __check_start_end(values, start, end)
    difference  = end - start
    new_start   = int(start + difference * edge_fraction)
    new_end     = int(end - difference * edge_fraction)
    mid         = int((new_start + new_end)  * mid_fraction)
    return np.mean(values[mid:new_end])

TIME_CONSTANT_RATIO = math.exp(-1)
"""
The time constant τ of a dynamic first-order system described by the function
`T(t) = exp(-t/τ)` is defined as the time it takes the output of the system to
reach the value `T(τ) = exp(-1) = 1/e`.

When a gain is also applied, the system usually transitions between two
steady-state values. If we consider T(0) = T0 and T(∞) = T1, the system can be
described by the function `T(t) = T0 + (T1 - T0) * exp(-t/τ)`.

Defining `∆T = T1 - T0`, we can calculate τ as the time it takes for the system
to reach the value `T(τ) = T0 + ∆T * 1/e`.

From this comes that TIME_CONSTANT_RATIO = 1/e.
""" # pylint: disable=W0105

def interpolate_time(t1, t2, v1, v2, v_exp):
    if t1 < 0:
        return t2
    slope = (v2-v1) / (t2-t1)
    return t1 + ((v_exp - v1) / slope)


def __interpolate_indexes(values, i, v_exp):
    return interpolate_time(i-1, i, values[i-1], values[i], v_exp)

def time_constant(values, start_steady_value, end_steady_value):
    """
    Returns the time constant of the step response provided as input, assuming
    that the response transitions between the two given steady-state values.
    """

    # TODO: find where the response actually begins

    delta = end_steady_value - start_steady_value

    value_begin = start_steady_value + (delta * 0.02)
    value_tau   = start_steady_value + (delta * TIME_CONSTANT_RATIO)

    comparator = operator.ge if delta > 0 else operator.le
    condition_begin = lambda v: comparator(v, value_begin)
    condition_tau   = lambda v: comparator(v, value_tau)

    index_begin = __first_match_index(values, condition_begin)
    index_tau   = __first_match_index(values, condition_tau)
    time_begin  = __interpolate_indexes(values, index_begin, value_begin)
    time_tau    = __interpolate_indexes(values, index_tau, value_tau)

    return time_tau - time_begin

def smooth(values, window_len=11, window='hanning'):
    """
    Smooths the given time series using the requested window function and
    length.

    This method is based on the convolution of a scaled window with the signal.
    The signal is prepared by introducing reflected copies of the signal (with
    the window size) in both ends so that transient parts are minimized in the
    begining and end part of the output signal.

    inputs:
     - values: the input signal.
     - window_len: the dimension of the smoothing window, should be an odd
       integer.
     - window: one in the following list of values: ['flat', 'hanning',
       'hamming', 'bartlett', 'blackman']; 'flat' window will produce a moving
       average smoothing.

    output: the smoothed signal

    see also: numpy.hanning, numpy.hamming, numpy.bartlett, numpy.blackman,
    numpy.convolve scipy.signal.lfilter

    TODO: the window parameter could be the window itself if an array instead of
    a string

    NOTE: length(output) != length(input), to correct this: return
    y[(window_len/2-1):-(window_len/2)] instead of just y.
    """

    if not isinstance(values, np.ndarray):
        values = np.array(values)

    if values.ndim != 1:
        raise ValueError("smooth only accepts 1 dimension arrays.")

    if values.size < window_len:
        raise ValueError("Input vector needs to be bigger than window size.")

    if window_len < 3:
        return values

    if not window in ['flat', 'hanning', 'hamming', 'bartlett', 'blackman']:
        raise ValueError("Window is one of 'flat', 'hanning', 'hamming', 'bartlett', 'blackman'")

    s = np.r_[values[window_len-1:0:-1],values,values[-2:-window_len-1:-1]]

    if window == 'flat': #moving average
        w = np.ones(window_len,'d')
    else:
        w = eval('np.'+window+'(window_len)')

    y = np.convolve(w/w.sum(),s,mode='valid')
    return y
