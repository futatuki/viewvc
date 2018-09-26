from apr_pools cimport apr_pool_t

cdef extern from "apr_strings.h" nogil:
    char* apr_pstrdup(apr_pool_t * p, const char * s)  
