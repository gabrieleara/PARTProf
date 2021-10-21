#!/usr/bin/env python3

import lmfit
import numpy as np
import scipy
import matplotlib.pyplot as plt

from . import timetools


FREQ        = 0
TEMP_TZ0_0  = 1
TEMP_TZ1_0  = 2
TEMP_TZ2_0  = 3
TEMP_TZ3_0  = 4
POWER_CPU0  = 5
POWER_CPU1  = 6
POWER_CPU2  = 7
POWER_CPU3  = 8
TIME        = 9
TEMP_TZ0    = 10
TEMP_TZ1    = 11
TEMP_TZ2    = 12
TEMP_TZ3    = 13
Te = 25.0

# This file implements a whole temp model that is more suitable to be used with
# a pandas df for input parameter values, i.e. T0_i, P_i and Te

# CONSTANTS USED TO LIMIT THE PARAMETERS
EPS = 1e-4
INF = 120
VAL = 1

def find_binomial(N):
    n = 0
    while True:
        if N <= (n * (n+1) / 2):
            return n
        n = n+1

def pars2cpunum(pars):
    return find_binomial(len(
        [k for k in pars.valuesdict().keys() if k.startswith('R_')]
    ))

def pars2vect(pars, cpu_num, vname):
    v = np.empty(cpu_num)
    for i in range(cpu_num):
        v[i] = pars[(vname + '_%d') % i].value
    return v

def pars2matrix(pars, cpu_num, mname):
    m = np.empty((cpu_num, cpu_num))
    for i in range(cpu_num):
        for j in range(cpu_num):
            if j < i:
                jj = i
                ii = j
            else:
                ii = i
                jj = j
            m[i,j] = pars[(mname + '_%d_%d') % (ii,jj)].value
    return m

def pars2R(pars, cpu_num):
    return pars2matrix(pars, cpu_num, 'R')

def pars2Re(pars):
    return pars['Re'].value

def pars2C(pars):
    return pars['C'].value

def matrix_A(C, Re, R):
    cpu_num = R.shape[0]
    A = np.zeros_like(R)
    for i in range(cpu_num):
        for j in range(cpu_num):
            if i == j:
                A[i,i] = - 1.0 / Re \
                    -np.sum([1 / R[i,k] for k in range(cpu_num) if i != k])
            else:
                A[i,j] = 1 / R[i,j]
    A = 1/C * A
    return A

def matrix_B(C, Re, cpu_num):
    I = np.eye(cpu_num)
    e = np.ones((cpu_num, 1))
    B = 1/C * np.append(I, 1/Re * e, axis=1)
    return B

def pars2AB(pars, cpu_num):
    R   = pars2R(pars, cpu_num)
    Re  = pars2Re(pars)
    C   = pars2C(pars)
    A   = matrix_A(C, Re, R)
    B   = matrix_B(C, Re, cpu_num)
    return A, B

# DEFAULTS = {
#     'C':      0.1,
#     'Re':     20,
#     'R_0_0':  0,
#     'R_0_1':  20,
#     'R_0_2':  20,
#     'R_0_3':  20,
#     'R_1_1':  0,
#     'R_1_2':  20,
#     'R_1_3':  20,
#     'R_2_2':  0,
#     'R_2_3':  20,
#     'R_3_3':  0,

#     'C':      0.15072321,
#     'Re':     18.7970294,
#     'R_0_0':  0,
#     'R_0_1':  71.7236020,
#     'R_0_2':  90.2944267,
#     'R_0_3':  34.8680575,
#     'R_1_1':  0,
#     'R_1_2':  39.9950468,
#     'R_1_3':  2.1525e-04,
#     'R_2_2':  0,
#     'R_2_3':  0.15978435,
#     'R_3_3':  0,
# }

# DEFAULTS = {
#     'C':      0.19926787,
#     'Re':     18.1768464,
#     'R_0_0':  0,
#     'R_0_1':  6.66464623,
#     'R_0_2':  5.66809870,
#     'R_0_3':  34.9746892,
#     'R_1_1':  0,
#     'R_1_2':  6.00390090,
#     'R_1_3':  0.00352619,
#     'R_2_2':  0,
#     'R_2_3':  5.05156858,
#     'R_3_3':  0,
# }

DEFAULTS = {
    'C':      0.15,
    'Re':     20.00,
    'R_0_0':  0,
    'R_0_1':  5.00,
    'R_0_2':  5.00,
    'R_0_3':  10.00,
    'R_1_1':  0,
    'R_1_2':  5.00,
    'R_1_3':  5.00,
    'R_2_2':  0,
    'R_2_3':  5.00,
    'R_3_3':  0,
}

# def build_params_A(cpu_num):
#     pars = lmfit.Parameters()
#     pa

def build_params(cpu_num):
    pars = lmfit.Parameters()
    pars.add('C',   value=DEFAULTS['C'], min=EPS, max=INF)
    pars.add('Re',  value=DEFAULTS['Re'], min=EPS, max=INF)
    for i in range(cpu_num):
        for j in range(i, cpu_num):
            Rij = 'R_%d_%d' % (i, j)
            if i == j:
                pars.add(Rij, value=0, vary=False)
            else:
                pars.add(Rij, value=DEFAULTS[Rij], min=EPS, max=INF)
    # print(pars.pretty_print())
    return pars

def build_inputs(cpu_num, P, T0, Te=25.0):
    return {
        'P' : np.array(P).reshape(cpu_num),
        'T0': np.array(T0).reshape(cpu_num),
        'U' : np.append(P, Te).reshape(cpu_num + 1),
        'Te': Te,
    }

def build_integrator(rhs, jacobian, y0, t0=0):
    i = scipy.integrate.ode(rhs, jacobian).set_integrator('vode', method='bdf')
    i.set_initial_value(y0, t0)
    return i

def model_AB_Uconst(A, B, Y0, U, t):
    # Consider the following differential for U constant in the time frame
    # [0,t]: dy(t)/dt = A * y(0) + B * U

    # We can solve the differential by integrating the free and forced response
    # separately: y(t) = y_free(t) + y_forced(t)

    # Free response: y_free(t) = exp(A*t) * y(0)
    expAt = scipy.linalg.expm(A * t)
    y_free = np.matmul(expAt, Y0)

    # Forced response:
    #  - y_forced(t) = exp(A*t) * i(t) * B * U
    #  - where i(t) = integral from 0 to t of exp(-A * tau) dtau
    #
    # assuming that A is nonsingular (i.e. invertible)

    # NOTE: do not change this expression! numerically, this expression can
    # become quite unstable if written in a different form! Written like this is
    # fine, because expm(A*t) tends to 0 for increasing t.
    I = np.eye(A.shape[0])
    y_forced = - \
        np.matmul(
            np.matmul(
                np.linalg.inv(A),
                I - scipy.linalg.expm(A * t)
            ),
            np.matmul(B, U)
        )

    return np.add(y_free, y_forced)

def model_AB_Uconst_tarray(A, B, Y0, U, tarray):
    y_array_shape = (Y0.shape[0], tarray.size)
    y = np.empty(y_array_shape)
    for i in range(tarray.size):
        y[:, i] = model_AB_Uconst(A, B, Y0, U, tarray[i])
    return y

def tempmodel_direct(pars, t, inputs):
    # Parse parameters into the correct differential model
    cpu_num = pars2cpunum(pars)

    A, B = pars2AB(pars, cpu_num)
    T0  = inputs['T0']
    U   = inputs['U']

    # Adjust the input times to a format that is easily manageable.
    if not isinstance(t, np.ndarray):
        t = np.array(t)
    if t.size < 2:
        t = t.reshape(1)
    else:
        t = t.reshape(t.size)

    y = model_AB_Uconst_tarray(A, B, T0, U, t)

    # Re-adjust output shape
    if y.shape[1] == 1:
        return y[:, 0]

    return y

def tempmodel_ode(pars, t, inputs):
    # Parse parameters into the correct differential model
    cpu_num = pars2cpunum(pars)

    A, B = pars2AB(pars, cpu_num)
    T0  = inputs['T0']
    U   = inputs['U']

    # The differential does not depend on time, and the Jacobian is the A
    # matrix, a 1st order ODE
    rhs         = lambda _,  y: (np.dot(A, y) + np.dot(B, U))
    jacobian    = lambda _, __: A
    integrator  = build_integrator(rhs, jacobian, T0)

    # Adjust the input times to a format that is easily manageable.
    if not isinstance(t, np.ndarray):
        t = np.array(t)
    if t.size < 2:
        t = t.reshape(1)
    else:
        t = t.reshape(t.size)

    # Output values
    y = np.empty((cpu_num, t.size))

    # Sorting time values for greater integration efficiency and less code
    # complexity. The integrator I'm using can only be used to advance the time,
    # if you want to go back you need to re-initialize it. That's why I'm
    # ordering the input times ahead.
    i_sorted = np.argsort(t)

    # NOTE: Assuming integration is always successful
    for i in i_sorted:
        # NOTE: First element could be t=t0. In that case, there's an issue with
        # scipy.integrate.ode.integrate that invalidates the whole integration:
        # https://github.com/scipy/scipy/issues/10909
        #
        # To avoid this, I will treat t=t0 differently and simply use the T0
        # value instead.
        t_cur = t[i]
        if t_cur == 0:
            y[:, i] = T0
        else:
            y[:, i] = integrator.integrate(t_cur)

    if y.shape[1] == 1:
        return y[:, 0]

    return y

def get_asymptote(data):
    return timetools.steady_value(data)

def get_asymptote_2d(data):
    as_data = np.zeros(data.shape[0])
    for i in range(data.shape[0]):
        as_data[i] = get_asymptote(data[i, :])
    return as_data

def tempmodel_asymptote(model, pars, t, inputs):
    y = model(pars, t, inputs)
    y = y[:, np.argsort(t)]
    return get_asymptote_2d(y)

count_invocations = 0

def print_max_abs_error(errors, should_print):
    global count_invocations
    if should_print:
        min = np.min(errors)
        max = np.max(errors)
        maxabs = -min if -min > max else max
        print('& Step %d \t' % count_invocations, '& max error %f' % maxabs)
        count_invocations += 1

def residual_single_run(pars, t, inputs, data, model, should_print=True):
    """
    Calculate the residual of the model applied to the given time interval when
    the provided inputs are supplied.
    """
    # start = time.time()
    out = model(pars, t, inputs)
    # end = time.time()
    out = (out - data).flatten()
    print_max_abs_error(out, should_print)
    # print('TIME:', end - start)
    return out

def db_get_index_values(db, index):
    return db.index.get_level_values(index).to_numpy()

def db_get_runids(db):
    return np.unique(db_get_index_values(db, 'runid'))

def db_get_runtypes(db):
    return np.unique(db_get_index_values(db, 'type'))

def db_select_run(db, runid, runtype):
    return db.loc[(runid, runtype)]

def db_get_t(db):
    return db_get_index_values(db, 'time')

def db_get_input_variable(db, cpunum, format):
    return [
        db[format % i].to_numpy()[0]
        for i in range(cpunum)
    ]

def db_get_T0(db, cpunum):
    return db_get_input_variable(db, cpunum, 'temp_tz%d_0')

def db_get_P(db, cpunum):
    return db_get_input_variable(db, cpunum, 'power_cpu%d')

def db_get_Te(db):
    return Te

def db_get_data(db, cpunum):
    return db[['temp_tz%d' % i for i in range(cpunum)]].to_numpy().T

def db_get_inputs(db, cpunum):
    T0  = db_get_T0(db, cpunum)
    P   = db_get_P(db, cpunum)
    Te  = db_get_Te(db)
    return build_inputs(cpunum, P, T0, Te)

def residual_multirun(pars, sampledb, model, should_print=True, plot=False):
    runids   = db_get_runids(sampledb)
    runtypes = db_get_runtypes(sampledb)

    out = np.empty(shape=0)

    CPU_NUM = 4

    for runid in runids:
        for runtype in runtypes:
            # FIXME: for now the cooldown does not work well!
            if runtype == 'cooldown':
                continue

            selection   = db_select_run(sampledb, runid, runtype)
            t           = db_get_t(selection)
            inputs      = db_get_inputs(selection, CPU_NUM)
            data        = db_get_data(selection, CPU_NUM)

            if plot:
                for d in range(CPU_NUM):
                    plt.plot(t, data[d, :])
                plt.show()

            res = residual_single_run(pars, t, inputs, data, model, should_print=False)
            out = np.append(out, res)

    print_max_abs_error(out, should_print)
    return out

def residual_asymptote(pars, sampledb, model,
    should_print=True,
    ):
    runids   = db_get_runids(sampledb)
    runtypes = db_get_runtypes(sampledb)

    out = np.empty(shape=0)

    CPU_NUM = 4

    for runid in runids:
        for runtype in runtypes:
            # FIXME: for now the cooldown does not work well!
            if runtype == 'cooldown':
                continue

            selection   = db_select_run(sampledb, runid, runtype)
            t           = db_get_t(selection)
            inputs      = db_get_inputs(selection, CPU_NUM)
            data        = db_get_data(selection, CPU_NUM)

            as_data     = get_asymptote_2d(data)
            as_model    = tempmodel_asymptote(model, pars, t, inputs)

            res = (as_model - as_data).flatten()
            out = np.append(out, res)

    print_max_abs_error(out, should_print)
    return out

# def residualdb_iterative(pars, db, model):
#     global count_invocations
#     print('RESIDUAL INVOCATION %d' % count_invocations)
#     residuals = np.empty(shape=0)
#     for row in db.iterrows():
#         rowv = row[1]
#         t = rowv[TIME]
#         inputs = build_inputs(4,
#             rowv[POWER_CPU0:POWER_CPU3+1].to_numpy(),
#             rowv[TEMP_TZ0_0:TEMP_TZ3_0+1].to_numpy(),
#             Te)
#         data = rowv[TEMP_TZ0:TEMP_TZ3+1].to_numpy()
#         out = model(pars, t, inputs)
#         residual = out - data
#         residuals = np.append(residuals, residual)
#     residuals = residuals.flatten()
#     min, max = residuals.min(), residuals.max()
#     max_abs = abs(min) if abs(min) > abs(max) else abs(max)
#     print('MAX ABS ERROR: ', max_abs)
#     count_invocations += 1
#     return residuals.flatten()

# def residualdb(pars, db, model):
#     global count_invocations
#     print('RESIDUAL INVOCATION %d' % count_invocations)
#     t = db['time'].to_numpy()

#     residuals = np.empty(shape=0)
#     for row in db.iterrows():
#         rowv = row[1]
#         t = rowv[TIME]
#         inputs = build_inputs(4,
#             rowv[POWER_CPU0:POWER_CPU3+1].to_numpy(),
#             rowv[TEMP_TZ0_0:TEMP_TZ3_0+1].to_numpy(),
#             Te)
#         data = rowv[TEMP_TZ0:TEMP_TZ3+1].to_numpy()
#         out = model(pars, t, inputs)
#         residual = out - data
#         residuals = np.append(residuals, residual)
#     residuals = residuals.flatten()
#     min, max = residuals.min(), residuals.max()
#     max_abs = abs(min) if abs(min) > abs(max) else abs(max)
#     print('MAX ABS ERROR: ', max_abs)
#     count_invocations += 1
#     return residuals.flatten()

def fit_temp_single_run(t, data, inputs, model, pars=None):
    CPU_NUM = 4
    if pars == None:
        pars = build_params(CPU_NUM)
    minimizer = lmfit.Minimizer(
        residual_single_run, pars,
        fcn_args=(t, inputs, data, model))
    fitresult = minimizer.minimize(
        method='leastsq',
        # epsfcn=0.2,
    )
    print(lmfit.fit_report(fitresult))
    return fitresult

def fit_temp_multirun_by_multiple_fits(sampledb, model):
    CPU_NUM = 4
    pars = build_params(CPU_NUM)
    runids   = db_get_runids(sampledb)
    runtypes = db_get_runtypes(sampledb)
    for runid in runids:
        for runtype in runtypes:
            # FIXME: for now the cooldown does not work well!
            if runtype == 'cooldown':
                continue
            selection   = db_select_run(sampledb, runid, runtype)
            t           = db_get_t(selection)
            inputs      = db_get_inputs(selection, CPU_NUM)
            data        = db_get_data(selection, CPU_NUM)
            result      = fit_temp_single_run(t, data, inputs, model, pars)
            pars        = result.params
    return pars

def fit_temp_multirun(sampledb, model,
    fit_asymptote=False,
    skip_fit = False,
    ):
    pars = build_params(cpu_num=4)

    if skip_fit:
        return pars

    residual_fun = residual_multirun

    if fit_asymptote:
        residual_fun = residual_asymptote

    minimizer = lmfit.Minimizer(
        residual_fun, pars,
        fcn_args=(sampledb, model))
    fitresult = minimizer.minimize(
        # method='leastsq',
        # epsfcn=0.2,
        method='differential_evolution',
        fit_kws = {
            'workers': -1,
        }
    )
    # fitresult = minimizer.leastsq(
    #     epsfcn=0.2
    # )
    print(lmfit.fit_report(fitresult))
    return fitresult.params

# # NOTE: x and y are numpy arrays
# # NOTE: assumes x is already cut and y is already smoothened if necessary
# def fit_temp_single_run(x, y, cpu_num, P, T0, model, Te=25.0):
#     pars = build_params(cpu_num)
#     inputs = build_inputs(cpu_num, P, T0, Te)
#     minimizer = lmfit.Minimizer(
#         residual_single_run, pars,
#         fcn_args=(x, inputs, y, model))
#     # fitresult = minimizer.minimize(
#     #     method='leastsq',
#     #     # method='differential_evolution',
#     #     fit_kws = {
#     #         'epsfcn': 0.2,
#     #     #     'workers': -1,
#     #     # #     'maxiter': 2,
#     #     # #     'popsize': 1,
#     #     }
#     # )
#     fitresult = minimizer.leastsq(
#         # epsfcn=0.000002
#     )
#     print(lmfit.fit_report(fitresult))
#     return fitresult, inputs

# def fit_temp(db, model):
#     pars = build_params(4)
#     minimizer = lmfit.Minimizer(
#         residualdb, pars,
#         fcn_args=(db, model))
#     # fitresult = minimizer.minimize(
#     #     method='leastsq',
#     #     # method='differential_evolution',
#     #     fit_kws = {
#     #         'epsfcn': 0.2,
#     #     #     'workers': -1,
#     #     # #     'maxiter': 2,
#     #     # #     'popsize': 1,
#     #     }
#     # )
#     fitresult = minimizer.leastsq(
#         epsfcn=0.0002
#     )
#     print(lmfit.fit_report(fitresult))
#     return fitresult

def main():
    cpu_num = 4
    T0  = np.array([37.72727273, 20, 41, 60])
    P   = np.array([2.52716732, 0.70245079, 0.70245079, 0.70245079]) * 100
    Te  = 25

    t = np.array(np.linspace(0, 15, 100))
    pars = build_params(cpu_num)
    inputs = build_inputs(cpu_num, P, T0, Te)

    import matplotlib.pyplot as plt

    y = tempmodel_direct(pars, t, inputs)
    for i in range(y.shape[0]):
        plt.plot(t, y[i, :], label='forward %d'%i)

    y = tempmodel_ode(pars, t, inputs)
    for i in range(y.shape[0]):
        plt.plot(t, y[i, :], label='integrator %d'%i)

    plt.legend()
    plt.show()

if __name__ == "__main__":
    main()
