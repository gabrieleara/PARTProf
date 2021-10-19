#!/usr/bin/env python3

import sympy
import numpy as np

from sympy.matrices.dense import symarray

CPUS_N = 4

kwargs = {
    'positive': True,
}

t   = sympy.Symbol('t',)
C   = sympy.Symbol('C',     **kwargs)
Re  = sympy.Symbol('Re',    **kwargs)
Te  = sympy.Symbol('Te',    **kwargs)

T0  = sympy.Matrix(symarray('T0', CPUS_N))
T   = sympy.Matrix(symarray('T', CPUS_N))
T_t = sympy.Matrix(symarray('T_t', CPUS_N))
P   = sympy.Matrix(symarray('P', CPUS_N,   **kwargs))
R   = sympy.Matrix(symarray('R', (CPUS_N,CPUS_N),**kwargs))

for i in range(CPUS_N):
    T[i] = sympy.Function('T_' + str(i))
    T_t[i] = T[i](t)
    R[i,i] = 0

for i,j in np.ndindex(R.shape):
    R[j,i] = R[i,j]

dT = sympy.Matrix(sympy.derive_by_array(T_t, t))
eye = sympy.eye(CPUS_N)

def sum_inverse_not(i, values):
    res = 0
    for j in range(CPUS_N):
        if i != j:
            res += 1 / values[i,j]
    return res

def fill_matrix_A(i, j):
    if i == j:
        return - (1 / Re + sum_inverse_not(i, R))
    else:
        return 1 / R[i,j]

def fill_matrix_B(i, j):
    if j < CPUS_N:
        return eye[i,j]
    return 1 / Re

matrix_A = sympy.Matrix(symarray('A', (CPUS_N,CPUS_N)))
matrix_B = sympy.Matrix(symarray('B', (CPUS_N,CPUS_N+1)))

for i,j in np.ndindex(matrix_A.shape):
    matrix_A[i,j] = fill_matrix_A(i,j)

matrix_B[0:CPUS_N,0:CPUS_N] = eye
for i in range(CPUS_N):
    matrix_B[i,CPUS_N] = 1 / Re

matrix_A = 1/C * matrix_A
matrix_B = 1/C * matrix_B

Q = sympy.Matrix(symarray('Q', CPUS_N+1))

for i in range(CPUS_N):
    Q[i] = P[i]
Q[CPUS_N] = Te

# matrix_C = sympy.eye(CPUS_N)
# matrix_D = 0

eq_for_print = sympy.Eq(dT,
    sympy.MatAdd(
        sympy.MatMul(matrix_A, T_t),
        sympy.MatMul(matrix_B, Q)
    )
)

sympy.pprint(eq_for_print)

rhs = matrix_A * T_t + matrix_B * Q

eqs     = []
funcs   = []
ics     = {}
for i in range(CPUS_N):
    eqs.append(sympy.Eq(dT[i], rhs[i]))
    funcs.append(T[i](t))
    ics[T[i](0)] = T0[i]

print("=========================")
print("")
sympy.pprint(matrix_A.diagonalize())
print("")
print("=========================")

sol = sympy.solvers.ode.systems.dsolve_system(eqs, funcs, t, ics=ics,
    doit=True, simplify=True)

with open("sympy_solution.txt", "w") as save_file:
    save_file.write(str(sol))

print('')
print('')
print('')

for s in sol:
    for ss in s:
        # print('sol=');
        sympy.pprint(ss)
