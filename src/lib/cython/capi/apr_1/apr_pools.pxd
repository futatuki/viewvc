from apr_1.apr cimport *
from apr_1.apr_errno cimport *

cdef extern from "apr_pools.h" nogil:
    ctypedef struct apr_pool_t:
        pass
    apr_status_t apr_pool_initialize()
    apr_status_t apr_pool_create(apr_pool_t **newpool, apr_pool_t *parent)
    void apr_pool_clear(apr_pool_t *p)
    void apr_pool_destroy(apr_pool_t *p)
    void * apr_palloc(apr_pool_t *p, apr_size_t size)
