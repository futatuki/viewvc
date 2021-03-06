from apr_1.apr cimport *

cdef extern from "apr_errno.h" nogil:
    ctypedef int apr_status_t
    char * apr_strerror(apr_status_t statcode, char *buf, apr_size_t bufsize)
    enum: APR_ENOPOOL
    enum: APR_EGENERAL
    enum: APR_EOF
    enum: APR_ENOMEM
    enum: APR_EAGAIN
    enum: APR_EINTR
    enum: APR_EINPROGRESS
