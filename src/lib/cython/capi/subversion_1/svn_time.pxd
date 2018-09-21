from apr_1.apr_pools cimport apr_pool_t
from apr_1.apr_time cimport apr_time_t
from subversion_1.svn_types cimport svn_error_t

cdef extern from "svn_time.h" nogil:
    svn_error_t * svn_time_from_cstring(
            apr_time_t *when, const char * data, apr_pool_t *pool)
