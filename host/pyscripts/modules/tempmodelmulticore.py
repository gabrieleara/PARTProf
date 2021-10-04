#!/usr/bin/env python3

import lmfit
import numpy as np
import scipy

# This file implements a whole temp model that is more suitable to be used with
# a pandas df for input parameter values, i.e. T0_i, P_i and Te

# CONSTANTS USED TO LIMIT THE PARAMETERS
EPS = 1e-16
INF = 1e16
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

def build_params(cpu_num):
    pars = lmfit.Parameters()
    pars.add('C',   value=VAL, min=EPS, max=INF)
    pars.add('Re',  value=VAL, min=EPS, max=INF)
    for i in range(cpu_num):
        for j in range(i, cpu_num):
            if i == j:
                pars.add('R_%d_%d' % (i, j), value=0, vary=False)
            else:
                pars.add('R_%d_%d' % (i, j), value=VAL, min=EPS, max=10)
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

def model_multi_cpu(pars, t, inputs):
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

count_invocations = 0
def model_multi_cpu_residual(pars, t, inputs, data):
    """
    Calculate the residual of the model applied to the given time interval when
    the provided inputs are supplied.
    """
    # print('MODEL INVOCATION %d' % count_invocations)
    model = model_multi_cpu(pars, t, inputs)
    out = np.abs((model - data).flatten())
    # print('MODEL INVOCATION %d DONE' % count_invocations)
    return out

# NOTE: x and y are numpy arrays
# NOTE: assumes x is already cut and y is already smoothened if necessary
def fit_temp(x, y, cpu_num, P, T0, Te=25.0):
    pars = build_params(cpu_num)
    inputs = build_inputs(cpu_num, P, T0, Te)
    minimizer = lmfit.Minimizer(model_multi_cpu_residual, pars,
        fcn_args=(x, inputs, y))
    fitresult = minimizer.minimize()
    print(lmfit.fit_report(fitresult))
    return fitresult, inputs

def main():
    cpu_num = 4
    T0  = np.array([37.72727273, 36, 41, 37])
    P   = np.array([2.52716732, 0.70245079, 0.70245079, 0.70245079]) * 10
    Te  = 25

    t = np.array(np.linspace(0, 100, 1000))
    pars = build_params(cpu_num)
    inputs = build_inputs(cpu_num, P, T0, Te)
    y = model_multi_cpu(pars, t, inputs)

    import matplotlib.pyplot as plt
    for i in range(y.shape[0]):
        plt.plot(t, y[i, :])
    plt.show()

if __name__ == "__main__":
    main()
