from apr_1.apr cimport apr_size_t
from apr_1.apr_pools cimport apr_pool_t

cdef extern from "svn_string.h" nogil:
    ctypedef struct svn_string_t:
        const char * data
        apr_size_t len
    ctypedef struct svn_stringbuf_t:
        apr_pool_t * pool
        char * data
        apr_size_t len
        apr_size_t blocksize
    svn_stringbuf_t * svn_stringbuf_create(
            const char * cstring, apr_pool_t * pool)
    svn_stringbuf_t * svn_stringbuf_ncreate(
            const char * bytes, apr_size_t size, apr_pool_t *pool)
