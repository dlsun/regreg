import numpy as np, sys
cimport numpy as np

"""
Implements (expected) linear time projections onto \ell_1 ball as described in
title = {Efficient projections onto the l1-ball for learning in high dimensions}
author = {Duchi, John and Shalev-Shwartz, Shai and Singer, Yoram and Chandra, Tushar}
"""

DTYPE_float = np.float
ctypedef np.float_t DTYPE_float_t
DTYPE_int = np.int
ctypedef np.int_t DTYPE_int_t

#TODO: Add some documentation to this!


def projl1(np.ndarray[DTYPE_float_t, ndim=1]  x, 
           DTYPE_float_t bound=1.):

    cdef np.ndarray[DTYPE_float_t, ndim=1] sorted_x = np.sort(np.fabs(x))
    cdef int p = x.shape[0]
    
    cdef double csum = 0.
    cdef double next, cut
    cdef int i, stop
    for i in range(p):
        next = sorted_x[p-i-1]
        csum += next
        stop = (csum - (i+1)*next) > bound
        if stop:
            break
    if stop:
        cut = next + (csum - (i+1)*next - bound)/(i)
        return soft_threshold(x,cut)
    else:
        return x

                                                            

def projl1_2(np.ndarray[DTYPE_float_t, ndim=1]  x, 
             DTYPE_float_t bound=1.):



    cdef int p = x.shape[0]
    cdef np.ndarray[DTYPE_int_t, ndim=2] U = np.empty((3,p),dtype=int)
    cdef int lenU = p
    cdef int Urow = 0
    cdef DTYPE_float_t s = 0
    cdef DTYPE_float_t rho = 0


    cdef int u, k, i, kind, Grow, Lrow, Gcol, Lcol, first
    cdef DTYPE_float_t xu, xk, ds, drho, eta

    first = 1
    while lenU:

        if Urow == 0:
            Lrow = 1
            Grow = 2
        elif Urow == 1:
            Lrow = 0
            Grow = 2
        else:
            Lrow = 0
            Grow = 1
            
        Lcol = 0
        Gcol = 0
        
        kind = np.random.randint(0,lenU)
        if first:
            k = kind
        else:
            k = U[Urow,kind]
        xk = x[k]
        if xk < 0:
            xk = -xk
        ds = 0
        drho = 0

        for i in range(lenU):
            if first:
                u = i
            else:
                u = U[Urow,i]
            xu = x[u]
            if xu < 0:
                xu = -xu
            if xu >= xk:
                if u == k:
                    ds += xu
                    drho += 1
                else:
                    U[Grow, Gcol] = u
                    Gcol += 1
                    ds += xu
                    drho += 1
            else:
                U[Lrow, Lcol] = u
                Lcol += 1

        if (s + ds) - (rho + drho)*xk < bound:
            s += ds
            rho += drho
            Urow = Lrow
            lenU = Lcol
        else:
            Urow = Grow
            lenU = Gcol
        first = 0
    eta = (s - bound)/rho
    if eta < 0:
        eta = 0.
    return soft_threshold(x, eta)
        

cdef soft_threshold(np.ndarray[DTYPE_float_t, ndim=1] x,
                    DTYPE_float_t lagrange):

    cdef int p = x.shape[0]
    cdef np.ndarray[DTYPE_float_t, ndim=1] y = np.empty(p)
    cdef DTYPE_float_t xi
    cdef int i
    for i in range(p):
        xi = x[i]
        if xi > 0:
            if xi < lagrange:
                y[i] = 0.
            else:
                y[i] = xi - lagrange
        else:
            if xi > -lagrange:
                y[i] = 0.
            else:
                y[i] = xi + lagrange
    return y

def projl1_epigraph(np.ndarray[DTYPE_float_t, ndim=1] center):
    """
    Project center onto the l1 epigraph. The norm term is center[0],
    the coef term is center[1:]

    The l1 epigraph is the collection of points (u,v): \|v\|_1 \leq u
    np.fabs(coef).sum() <= bound.

    """

    cdef np.ndarray[DTYPE_float_t, ndim=1] coef = center[1:]
    cdef DTYPE_float_t norm = center[0]
    cdef np.ndarray[DTYPE_float_t, ndim=1] sorted_coefs = np.sort(np.fabs(coef))

    cdef int n = sorted_coefs.shape[0]
    cdef np.ndarray[DTYPE_float_t, ndim=1] result = np.zeros(n+1, np.float)
    cdef int i, stop, idx
    cdef DTYPE_float_t csum = 0
    cdef DTYPE_float_t thold = sorted_coefs[n-1]
    cdef DTYPE_float_t x1, x2, y1, y2, slope
    
    # check to see if it's already in the epigraph

    if sorted_coefs.sum() <= norm:
        result[0] = norm
        result[1:] = coef
        return result
    x1 = sorted_coefs[n-1]
    y1 = - norm - x1
    for i in range(1, n-1):
        x2 = sorted_coefs[n-1-i]
        csum += x1
        y2 = (csum - i*x2) - (norm + x2)
        print x1, y1, x2, y2, np.fabs(soft_threshold(coef, x2)).sum() - norm - x2
        if y2 > 0:
            slope = (y1-y2) / (x1-x2)
            thold = (slope * x2 - y2) / slope
            print 'thold', thold
            break
        
        x1, y1 = x2, y2
    if thold != sorted_coefs[n-1]:
        result[0] = norm + thold
        result[1:] = soft_threshold(coef, thold)
    return result

def projlinf_epigraph(np.ndarray[DTYPE_float_t, ndim=1] center):
    """
    Project center onto the l-infinty epigraph. The norm term is center[0],
    the coef term is center[1:]

    The l-infinity epigraph is the collection of points (u,v): \|v\|_{\infty} \leq u
    np.fabs(coef).max() <= bound.

    """
    # we just use the fact that the polar of the linf epigraph is
    # is the negative of the l1 epigraph, so we project
    # -center onto the l1-epigraph and add the result to center...
    cdef np.ndarray[DTYPE_float_t, ndim=1] coef = -center[1:]
    cdef DTYPE_float_t norm = -center[0]
    cdef np.ndarray[DTYPE_float_t, ndim=1] sorted_coefs = np.sort(np.fabs(coef))

    cdef int n = sorted_coefs.shape[0]
    cdef np.ndarray[DTYPE_float_t, ndim=1] result = np.zeros(n+1, np.float)
    cdef int i, stop, idx
    cdef DTYPE_float_t csum = 0
    cdef DTYPE_float_t thold = sorted_coefs[n-1]
    cdef DTYPE_float_t x1, x2, y1, y2, slope
    
    # check to see if it's already in the epigraph

    if sorted_coefs.sum() <= norm:
        result[0] = norm
        result[1:] = coef
        return result
    x1 = sorted_coefs[n-1]
    y1 = - norm - x1
    for i in range(1, n-1):
        x2 = sorted_coefs[n-1-i]
        csum += x1
        y2 = (csum - i*x2) - (norm + x2)
        print x1, y1, x2, y2, np.fabs(soft_threshold(coef, x2)).sum() - norm - x2
        if y2 > 0:
            slope = (y1-y2) / (x1-x2)
            thold = (slope * x2 - y2) / slope
            print 'thold', thold
            break
        
        x1, y1 = x2, y2
    if thold != sorted_coefs[n-1]:
        result[0] = norm + thold
        result[1:] = soft_threshold(coef, thold)
    return center + result

    
