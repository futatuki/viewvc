from apr_1.apr_errno cimport apr_status_t
from subversion_1.svn_types cimport svn_error_t

cdef extern from "svn_error.h" nogil:
    svn_error_t * svn_error_create(apr_status_t apr_err, svn_error_t * child,
            const char * message)
    void svn_error_compose(svn_error_t * chain, svn_error_t * new_err)
    svn_error_t * svn_error_dup(const svn_error_t * error)
    void svn_error_clear(svn_error_t * error)
