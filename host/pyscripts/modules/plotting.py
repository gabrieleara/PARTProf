#!/usr/bin/env python3

import numpy as np

# from . import timetools

DEFAULT_PLOT_OPTIONS = {
    # marker='.',
    'alpha': 0.8,
    'linewidth': 1,
}

def plot_y(axis, yvals,
    sampling_time=1,
    **kwargs):
    xvals = np.arange(yvals.shape[0]) * sampling_time
    return axis.plot_xy(xvals, yvals, **DEFAULT_PLOT_OPTIONS, **kwargs)
