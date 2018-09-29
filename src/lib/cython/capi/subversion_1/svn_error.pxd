include "_svn_api_ver.pxi"
from apr_1.apr cimport apr_size_t
from apr_1.apr_errno cimport apr_status_t
from subversion_1.svn_types cimport svn_error_t

cdef extern from "svn_error.h" nogil:
    char * svn_strerror(apr_status_t statcode, char * buf, apr_size_t bufsize)
    IF SVN_API_VER >= (1, 8):
        const char * svn_error_symbolic_name(apr_status_t statcode)
    IF SVN_API_VER >= (1, 4):
        const char * svn_err_best_message(
            const svn_error_t *err, char * buf, apr_size_t bufsize)
    svn_error_t * svn_error_create(apr_status_t apr_err, svn_error_t * child,
            const char * message)
    void svn_error_compose(svn_error_t * chain, svn_error_t * new_err)
    svn_error_t * svn_error_dup(const svn_error_t * error)
    void svn_error_clear(svn_error_t * error)
