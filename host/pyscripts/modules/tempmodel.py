#!/usr/bin/env python3

import numpy as np
import lmfit
from numpy  import exp
from .      import timetools

def gains_list(cpu_num):
    return ['G' + str(i) for i in range(cpu_num)]

def decays_list(cpu_num):
    return ['τ' + str(i) for i in range(cpu_num)]

# Expression: T(t) = Tinf + ∑ ( G_i * exp(-t / τ_i) )
def temp_model_singlecore(params, t):
    def to_ordered_list(mdict, s):
        mdict = {int(k[len(s):]) : v for k, v in mdict.items() if k.startswith(s)}
        mdict = dict(sorted(mdict.items(), key=lambda item: item[1]))
        return mdict.values()

    parvals = params.valuesdict()
    gains   = to_ordered_list(parvals, 'G')
    decays  = to_ordered_list(parvals, 'τ')

    T = parvals['Tinf']
    # TODO: works only if t has a numpy shape, not on literals!
    for G, τ in zip(gains, decays):
        if G == -np.inf or G == np.inf:
            T = np.full(t.shape, G)
            continue
        T += G * exp(-t / τ)

    return T

def temp_model_multicore(params, t):
    pass

def error_model_singlecore(params, t, data):
    model = temp_model_singlecore(params, t)
    return np.abs(model - data)

def error_model_singlecore(params, t, data):
    model = temp_model_multicore(params, t)
    return np.abs(model - data).flatten()

def gain_sum_str(gains):
    return '(' + '+'.join(gains) + ')'

def temp_params(cpu_num, Tinf=1, T0=0, max_time=np.inf):
    if cpu_num < 1:
        pass # TODO: throw something

    params = lmfit.Parameters()

    # Fixed parameters
    params.add('Tinf',  value=Tinf, vary=False)
    params.add('T0',    value=T0,   vary=False)

    delta       = abs(Tinf - T0)
    bigrange    = 5 * delta

    G_list = gains_list(cpu_num)
    τ_list = decays_list(cpu_num)

    # Constraint:
    # Tinf - sum(gains) = T(0)
    for G in G_list:
        params.add(G, value=-delta / len(G_list), min=-bigrange, max=+bigrange)

    # params.add('Gsum', value=(T0 - Tinf), vary=False, expr=gain_sum_str(G_list))

    # No time decay can be longer than the maximum time considered (last samples
    # are supposed to be all in steady state condition)
    for τ in τ_list:
        params.add(τ, value=max_time / 3, min=1e-10, max=max_time)

    return params

# NOTE: x and y are numpy arrays
# NOTE: assumes x is already cut and y is already smoothened if necessary
def fit_temp(x, y, cpu_num):
    imax = np.argmax(x)
    xmax = x[imax]
    yinf = timetools.steady_value(y)
    y0   = y[0]

    # NOTE: DO NOT USE! fit becomes suddenly much worse!
    # y0   = timetools.steady_value(y,
    #     start=-1, end=0, edge_fraction=0, mid_fraction=0.005)

    fit_params  = temp_params(cpu_num, Tinf=yinf, T0=y0, max_time=xmax)
    minimizer   = lmfit.Minimizer(error_model_singlecore, fit_params, fcn_args=(x, y))
    fitresult   = minimizer.minimize()
    print(lmfit.fit_report(fitresult))

    return fitresult

# minimize function arguments:
# - fcn2min:    Function to minimize, shall return an array of residuals
# - params:     Parameters of the model
# - method:     See the list of methods [optional, least squares default]
# - args:       Positional  arguments to pass to fcn2min
# - kws:        Keyword     arguments to pass to fcn2min
# - reduce_fcn  How to reduce the array of residuals to a scalar [optional]
#
# Note: a common use for args is to pass the data that shall be used to fit the
# function and calculate residuals!
#
# minimize returns a MinimizerResult object, with the following attributes:
# - params      Best-fit parameters
# - success     True for success, False otherwise
# - message     Message about fit success
# - status      Termination status, depends on the solver
# - var_names   Ordered list of parameter names
# - covar       Covariance matrix, for order refer to var_names
