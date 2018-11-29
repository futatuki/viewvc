include "_svn_api_ver.pxi"
from apr_1.apr cimport apr_size_t, apr_int32_t
from apr_1.apr_file_io cimport apr_file_t
from apr_1.apr_file_info cimport apr_fileperms_t
from apr_1.apr_pools cimport apr_pool_t
from subversion_1.svn_types cimport svn_error_t, svn_boolean_t
from subversion_1.svn_string cimport svn_stringbuf_t

cdef extern from "svn_io.h" nogil:
    ctypedef struct svn_stream_t:
        pass
    ctypedef svn_error_t * (* svn_read_fn_t)(
            void * baton, char * buffer, apr_size_t * len)
    IF SVN_API_VER >= (1, 7):
        ctypedef svn_error_t * (* svn_stream_skip_fn_t)(
                void * baton, apr_size_t len)
    ctypedef svn_error_t * (* svn_write_fn_t)(
            void * baton, const char * data, apr_size_t * len)
    ctypedef svn_error_t * (* svn_close_fn_t)(void * baton)
    IF SVN_API_VER >= (1, 7):
        ctypedef struct svn_stream_mark_t:
            pass
        ctypedef svn_error_t * (* svn_stream_mark_fn_t)(
                void * baton, svn_stream_mark_t ** mark, apr_pool_t * pool)
        ctypedef svn_error_t *(*svn_stream_seek_fn_t)(
                void * baton, const svn_stream_mark_t * mark)
    IF SVN_API_VER >= (1, 9):
        ctypedef svn_error_t * (* svn_stream_data_available_fn_t)(
                void * baton, svn_boolean_t * data_available)
    IF SVN_API_VER >= (1, 10):
        ctypedef svn_error_t *(*svn_stream_readline_fn_t)(
                void * baton, svn_stringbuf_t ** stringbuf, const char * eol,
                svn_boolean_t * eof, apr_pool_t * pool)
    svn_stream_t * svn_stream_create(void * baton, apr_pool_t * pool)
    void svn_stream_set_baton(svn_stream_t * stream, void * baton)
    IF SVN_API_VER >= (1, 9):
        void svn_stream_set_read2(
                svn_stream_t * stream, svn_read_fn_t read_fn,
                svn_read_fn_t read_full_fn)
    void svn_stream_set_read(svn_stream_t * stream, svn_read_fn_t read_fn)
    IF SVN_API_VER >= (1, 7):
        void svn_stream_set_skip(
                svn_stream_t * stream, svn_stream_skip_fn_t skip_fn)
    void svn_stream_set_write(svn_stream_t * stream, svn_write_fn_t write_fn)
    void svn_stream_set_close(svn_stream_t * stream, svn_close_fn_t close_fn)
    IF SVN_API_VER >= (1, 7):
        void svn_stream_set_mark(
                svn_stream_t * stream, svn_stream_mark_fn_t mark_fn)
        void svn_stream_set_seek(
                svn_stream_t * stream, svn_stream_seek_fn_t seek_fn)
    IF SVN_API_VER >= (1, 9):
        void svn_stream_set_data_available(
                svn_stream_t * stream,
                svn_stream_data_available_fn_t data_available)
    IF SVN_API_VER >= (1, 10):
        void svn_stream_set_readline(
                svn_stream_t * stream, svn_stream_readline_fn_t readline_fn)

    IF SVN_API_VER >= (1, 9):
        svn_error_t * svn_stream_read_full(
                svn_stream_t * stream, char * buffer, apr_size_t *len)
        svn_error_t * svn_stream_read2(
                svn_stream_t * stream, char * buffer, apr_size_t *len)
    svn_error_t * svn_stream_read(
                svn_stream_t * stream, char * buffer, apr_size_t *len)
    IF SVN_API_VER >= (1, 7):
        svn_error_t * svn_stream_skip(
                    svn_stream_t * stream, apr_size_t len)
    svn_error_t * svn_stream_write(
                svn_stream_t * stream, const char * buffer, apr_size_t *len)
    svn_error_t * svn_stream_close(svn_stream_t * stream)
    IF SVN_API_VER >= (1, 7):
        svn_error_t * svn_stream_reset(svn_stream_t * stream)
        svn_error_t * svn_stream_mark(
                svn_stream_t * stream, svn_stream_mark_t ** mark,
                apr_pool_t * pool)
    svn_error_t * svn_stream_seek(
                svn_stream_t * stream, const svn_stream_mark_t * mark)
    IF SVN_API_VER >= (1, 9):
        svn_error_t * svn_stream_data_available(
                svn_stream_t * stream, svn_boolean_t * data_available)
    svn_error_t * svn_stream_readline(
            svn_stream_t * stream, svn_stringbuf_t ** stringbuf,
            const char * eol, svn_boolean_t * eof, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 6):
        svn_error_t * svn_stream_open_readonly(
                svn_stream_t ** stream, const char * path,
                apr_pool_t * result_pool, apr_pool_t * scratch_pool)

    # used only for implementing svn_stream_open_readonly()
    svn_error_t * svn_io_file_open(
            apr_file_t ** new_file, const char * fname, apr_int32_t flag,
            apr_fileperms_t perm, apr_pool_t * pool)
    svn_error_t * svn_io_file_close(apr_file_t *file, apr_pool_t *pool)
    IF SVN_API_VER >= (1, 4):
        svn_stream_t * svn_stream_from_aprfile2(
                apr_file_t * file, svn_boolean_t disown, apr_pool_t * pool)
    svn_stream_t * svn_stream_from_aprfile(
                apr_file_t * file, apr_pool_t * pool)
