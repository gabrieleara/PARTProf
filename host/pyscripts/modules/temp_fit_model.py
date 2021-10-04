#!/usr/bin/env python3

import numpy as np
import lmfit
from numpy.lib.arraysetops import isin
import scipy
from numpy  import exp, ndarray
# from .      import timetools

eps = 1e-16
inf = 1e16
val = 1

# Fixed input arguments:
# Te
# T0_i
# P_i
#
# Parameters to be determined:
# C     -> [eps, inf]
# Re    -> [eps, inf]
# R_i_j -> {
#   [eps, inf]  if i != j
#   0           otherwise
# }

def to_ordered_integer_list(mdict, s):
    mdict = {int(k[len(s):]) : v for k, v in mdict.items() if k.startswith(s)}
    mdict = dict(sorted(mdict.items(), key=lambda item: item[0]))
    return list(mdict.keys())

def pars2cpunum(pars):
    return np.max(to_ordered_integer_list(pars.valuesdict(), 'P_')) + 1

# cpu_num = pars2cpunum(pars)

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

def pars2T0(pars, cpu_num):
    return pars2vect(pars, cpu_num, 'T0')

def pars2P(pars, cpu_num):
    return pars2vect(pars, cpu_num, 'P')

def pars2Te(pars):
    return pars['Te'].value

def pars2Re(pars):
    return pars['Re'].value

def pars2C(pars):
    return pars['C'].value

def build_params(cpu_num, T0, P, Te=25.0):
    pars = lmfit.Parameters()

    # Fixed input argumnts:
    pars.add('Te',  value=Te, vary=False)
    for i in range(cpu_num):
        pars.add('T0_%d' % i, value=T0[i], vary=False)
        pars.add('P_%d' % i, value=P[i], vary=False)

    # Parameters to be determined:
    pars.add('C',   value=val, min=eps, max=inf)
    pars.add('Re',  value=val, min=eps, max=inf)
    for i in range(cpu_num):
        for j in range(i, cpu_num):
            if i == j:
                pars.add('R_%d_%d' % (i, j), value=0, vary=False)
            else:
                pars.add('R_%d_%d' % (i, j), value=val + (i * 10 + j), min=eps, max=inf)
    print(pars.pretty_print())
    return pars

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
    I   = np.eye(cpu_num)
    e   = np.ones((cpu_num, 1))
    B   = 1/C * np.append(I, 1/Re * e, axis=1)
    return B

def pars2_A_B_T0_U(pars, cpu_num):
    # Inputs
    P   = pars2P(pars, cpu_num)
    Te  = pars2Te(pars)

    # Params
    R   = pars2R(pars, cpu_num)
    Re  = pars2Re(pars)
    C   = pars2C(pars)

    A   = matrix_A(C, Re, R)
    B   = matrix_B(C, Re, cpu_num)
    T0  = pars2T0(pars, cpu_num)
    U   = np.append(P, Te).reshape(cpu_num + 1)

    # print('=========== SHAPES ===========')
    # print('T0 : ', T0.shape)
    # print('P : ', P.shape)
    # print('R : ', R.shape)
    # print('Re : (1,)')
    # print('Te : (1,)')
    # print('C : (1,)')
    # print('A : ', A.shape)
    # print('B : ', B.shape)
    # print('U : ', U.shape)

    # print('===========  VARS  ===========')
    # print('A=', A)
    # print('B=', B)
    # print('T0=', T0)
    # print('U=', U)

    return A, B, T0, U

def model_multi_cpu(pars, t):
    # Parse parameters into the correct differential model
    cpu_num = pars2cpunum(pars)
    A, B, T0, U = pars2_A_B_T0_U(pars, cpu_num)

    # The differential does not depend on time, and the Jacobian is the A
    # matrix, a 1st order ODE
    diff_rhs = lambda t, y: (np.dot(A, y) + np.dot(B, U))
    jacobian = lambda t, y: A

    # Adjust the input times to a format that is easily manageable

    # TODO: deal with this!
    wasndarray = True
    # Even if t is a single scalar, convert it to 1x1 array for convenience
    if not isinstance(t, np.ndarray):
        wasndarray = False
        t = np.array(t)
    if t.size < 2:
        t = t.reshape(1)

    # Array of values
    y = np.empty((cpu_num, t.size))

    def build_integrator(f, jac, y0, t0=0):
        r = scipy.integrate.ode(f, jac).set_integrator('vode', method='bdf')
        r.set_initial_value(y0, t0)
        return r

    r = build_integrator(diff_rhs, jacobian, T0)

    # Sorting time values for greater integration efficiency and less code
    # complexity
    i_sorted = np.argsort(t)

    # NOTE: Assuming integration is always successful
    for i in i_sorted:
        # NOTE: First element could be t=0. In that case, there's an issue with
        # scipy.integrate.ode.integrate that invalidates the whole integration:
        # https://github.com/scipy/scipy/issues/10909
        #
        # To avoid this, I will treat t=0 differently and simply use the T0
        # value instead.
        t_cur = t[i]
        if t_cur == 0:
            y[:, i] = T0
        else:
            y[:, i] = r.integrate(t_cur)

    if y.shape[1] == 1:
        return y[:, 0]

    return y

#     free_response   = lambda t: np.dot(expA, T0) * np.exp(t)
#     convol_fun      = lambda τ: expA * ()

#     scipy.integrate()

#     result = integrate.quad(lambda x: special.jv(2.5,x), 0, 4.5)


#     y = np.dot(expA, T0) + scipy.integrate

#     y = scipy.linalg.expm(A) * T0

    # print(A)
    # print(scipy.linalg.expm(A))

    # ONE = np.ones((cpu_num, cpu_num))
    # I   = np.eye(cpu_num)
    # e   = np.ones((cpu_num, 1))
    # G   = np.zeros_like(R)

    # np.reciprocal(R, out=G, where=(ONE - I).astype(bool))
    # sympy.pprint(G)

    # a = - 1 / Re * I
    # print(a)

    # b = np.matmul(I, G)

    # c = - np.matmul(e, e.T)

    # d = np.matmul(c, G)
    # dd = sympy.Matrix(symarray('A', (cpu_num,cpu_num)))
    # for i in range(cpu_num):
    #     for j in range(cpu_num):
    #         dd[i,j] = d[i,j]
    # sympy.pprint(dd)
    # print(d)

    # A = a + b + d
    # AA = sympy.Matrix(symarray('A', (cpu_num,cpu_num)))
    # for i in range(cpu_num):
    #     for j in range(cpu_num):
    #         AA[i,j] = A[i,j]
    # sympy.pprint(AA)

    # A1 = sympy.Matrix(symarray('A', (cpu_num,cpu_num)))

    # def sum_inverse_not(i, values):
    #     res = 0
    #     for j in range(cpu_num):
    #         if i != j:
    #             res += 1 / values[i,j]
    #     return res

    # for i in range(cpu_num):
    #     for j in range(cpu_num):
    #         if i == j:
    #             A1[i,i] = - (1 / Re + sum_inverse_not(i, R))
    #         else:
    #             A1[i,j] = 1 / R[i,j]

    # sympy.pprint(A1)

    # np.exp(A1)

    # sympy.pprint(A1 - AA)

    # A = - 1/Re * I + (I - e * e.T) * G
    # A = 1/C * A
    # print(sympy.latex(A))

    # B = TODO

    # Output variable
    # T = np.empty((1, cpu_num))
    # for i in range(cpu_num):

import random

pars    = build_params(4, T0=[25,26,27,28], P=[100, 1, 2, 3], Te=25)
t       = np.array(np.linspace(0, 10, 200))
# To test when t is not ordered
# random.shuffle(t)
import timeit
result  = model_multi_cpu(pars, t)
callable = lambda: model_multi_cpu(pars, t)
# print(timeit.timeit(callable, number=10000))

print(result)
import matplotlib.pyplot as plt

for i in range(result.shape[0]):
    plt.plot(t, result[i, :])

plt.show()
# cpu_num = pars2cpunum(pars)
