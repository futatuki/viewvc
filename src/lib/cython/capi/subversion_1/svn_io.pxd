include "_svn_api_ver.pxi"
from apr_1.apr cimport apr_size_t, apr_int32_t 
IF SVN_API_VER < (1, 6):
    from apr_1.apr_file_io cimport apr_file_t
    from apr_1.apr_file_info cimport apr_fileperms_t
from apr_1.apr_pools cimport apr_pool_t
from subversion_1.svn_types cimport svn_error_t, svn_boolean_t
from subversion_1.svn_string cimport svn_stringbuf_t

cdef extern from "svn_io.h" nogil:
    ctypedef struct svn_stream_t:
        pass
    IF SVN_API_VER >= (1, 9):
        svn_error_t * svn_stream_read_full(
                svn_stream_t * stream, char * buffer, apr_size_t *len)
        svn_error_t * svn_stream_read2(
                svn_stream_t * stream, char * buffer, apr_size_t *len)
    svn_error_t * svn_stream_read(
                svn_stream_t * stream, char * buffer, apr_size_t *len)
    svn_error_t * svn_stream_close(svn_stream_t * stream)
    svn_error_t * svn_stream_readline(
            svn_stream_t * stream, svn_stringbuf_t ** stringbuf,
            const char * eol, svn_boolean_t * eof, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 6):
        svn_error_t * svn_stream_open_readonly(
                svn_stream_t ** stream, const char * path,
                apr_pool_t * result_pool, apr_pool_t * scratch_pool)
    ELSE:
        # used only for implementing svn_stream_open_readonly()
        svn_error_t * svn_io_file_open(
                apr_file_t ** new_file, const char * fname, apr_int32_t flag,
                apr_fileperms_t perm, apr_pool_t * pool)
        svn_error_t * svn_io_file_close(apr_file_t *file, apr_pool_t *pool)
        ctypedef svn_error_t * (* svn_close_fn_t)(void * baton)
        void svn_stream_set_close(
                svn_stream_t *stream, svn_close_fn_t close_fn)
        IF SVN_API_VER >= (1, 4):
            svn_stream_t * svn_stream_from_aprfile2(
                    apr_file_t * file, svn_boolean_t disown, apr_pool_t * pool)
        svn_stream_t * svn_stream_from_aprfile(
                    apr_file_t * file, apr_pool_t * pool)
