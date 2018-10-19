from apr_1.apr cimport *
from apr_1.apr_pools cimport *

cdef extern from "apr_tables.h" nogil:
    ctypedef struct apr_array_header_t:
        apr_pool_t * pool
        int elt_size
        int nelts
        int nalloc
        char * elts
    apr_array_header_t * apr_array_make(
            apr_pool_t * p, int nelts, int elt_size)
    void * apr_array_push(apr_array_header_t * arr)
    void apr_array_clear(apr_array_header_t * arr)
