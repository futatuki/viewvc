from apr_1.apr_errno cimport *

cdef extern from "apr_general.h" nogil:
    apr_status_t apr_initialize()
    void apr_terminate2()

