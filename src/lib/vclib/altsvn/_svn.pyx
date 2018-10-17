include "_svn_api_ver.pxi"
include "_py_ver.pxi"
from libc.stdlib cimport atexit
from libc.stddef cimport size_t
from cpython cimport Py_buffer
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
cimport _svn_capi as _c_
IF SVN_API_VER >= (1, 6):
    from subversion_1 cimport svn_dirent_uri

import os
import os.path
import io
import errno
IF SVN_API_VER < (1, 7):
    import urllib

try:
    PathLike = os.PathLike
except AttributeError:
    class PathLike(object):
        pass

class General(Exception): pass
class InitError(General): pass
class MemoryError(General): pass
class PoolError(General): pass
# for internal use
class NotImplemented(General): pass

# from "apr_pools.h" representation of apr_pool_t
cdef class Apr_Pool(object):
#    cdef _c_.apr_pool_t* _c_pool
    def __cinit__(self, Apr_Pool pool=None):
        self._c_pool = NULL
        self.is_own = _c_.FALSE
        self._parent_pool = None
    def __init__(self, Apr_Pool pool=None):
        cdef _c_.apr_status_t ast
        global _root_pool
        if pool is None:
            self._parent_pool = _root_pool
            ast = _c_.apr_pool_create(&(self._c_pool), _root_pool._c_pool)
        else:
            self._parent_pool = pool
            ast = _c_.apr_pool_create(&(self._c_pool), pool._c_pool)
        if ast:
            raise PoolError()
        self.is_own = _c_.TRUE
    def clear(self):
        if self._c_pool is not NULL:
            _c_.apr_pool_clear(self._c_pool)
    def destroy(self):
        # do not try to destroy the pool. this will cause segmentation fault.
        if self.is_own != _c_.FALSE and self._c_pool is not NULL:
            self.is_own = _c_.FALSE
            _c_.apr_pool_destroy(self._c_pool)
        self._c_pool = NULL
    cdef Apr_Pool set_pool(Apr_Pool self, _c_.apr_pool_t * _c_pool):
        assert self._c_pool is NULL
        self.is_own = _c_.FALSE
        self._c_pool = _c_pool
        return self
    cdef inline void * palloc(self, _c_.apr_size_t size):
        return _c_.apr_palloc(self._c_pool, size)
    def __dealloc__(self):
        if self.is_own != _c_.FALSE and self._c_pool is not NULL:
            self.is_own = _c_.FALSE
            _c_.apr_pool_destroy(self._c_pool)
            self._c_pool = NULL
        self._parent_pool = None

cpdef Apr_Pool _root_pool
cpdef Apr_Pool _scratch_pool

def _initialize():
    cdef void* errstrbuf
    cdef _c_.apr_status_t ast
    cdef int nelm = 1024
    cdef size_t bufsize
    cdef crv
    global _root_pool, _scratch_pool
    ast = _c_.apr_initialize()
    if ast:
        bufsize = nelm * sizeof(char)
        errstrbuf = PyMem_Malloc(nelm)
        if not errstrbuf:
            raise MemoryError()
        estr = _c_.apr_strerror(ast, <char *>errstrbuf, bufsize)
        PyMem_Free(errstrbuf)
        raise InitError(estr)
    else:
        if 0 != atexit(_c_.apr_terminate2):
            _c_.apr_terminate2()
            raise MemoryError()
    # setup _root_pool and _scratch_pool
    _root_pool = Apr_Pool.__new__(Apr_Pool, None)
    _root_pool._parent_pool = None
    _c_.apr_pool_create(&(_root_pool._c_pool), NULL)
    assert _root_pool._c_pool is not NULL
    _root_pool.is_own = _c_.TRUE
    _scratch_pool = Apr_Pool(_root_pool)
    return

_initialize()
del _initialize

# from "svn_error_codes.h"
SVN_NO_ERROR                   = _c_.SVN_NO_ERROR
SVN_ERR_FS_NOT_FOUND           = _c_.SVN_ERR_FS_NOT_FOUND
SVN_ERR_CLIENT_IS_BINARY_FILE  = _c_.SVN_ERR_CLIENT_IS_BINARY_FILE
IF SVN_API_VER >= (1, 5):
    SVN_ERR_CEASE_INVOCATION       = _c_.SVN_ERR_CEASE_INVOCATION
ELSE:
    SVN_ERR_CEASE_INVOCATION       = _c_.SVN_ERR_CANCELLED

# from "svn_types.h" representation of svn_error_t
cdef class Svn_error(object):
#    cdef _c_.svn_error_t * _c_error
#    cdef object bytes_msg
    def __cinit__(self, msg=None, stat=None):
        self._c_error = NULL
    def __init__(self, msg=None, stat=None):
        cdef _c_.apr_status_t ast
        cdef const char * _c_msg
        if stat:
            ast = stat
            if msg:
                IF PY_VERSION < (3, 0, 0):
                    self.bytes_msg = str(msg)
                ELSE:
                    self.bytes_msg = str(msg).decode('utf-8')
                _c_msg = self.bytes_msg
            else:
                _c_msg = NULL
            self._c_error = _c_.svn_error_create(stat, NULL, _c_msg)
    cdef seterror(self, _c_.svn_error_t * err):
        if self._c_error is NULL:
            self._c_error = err
        elif err is not NULL:
            _c_.svn_error_compose(self._c_error, err)
        return self
    cdef _c_.svn_error_t * geterror(self):
        return self._c_error
    def __str__(self):
        cdef object estr
        cdef _c_.svn_error_t * eptr
        cdef char * msgbuf
        IF SVN_API_VER >= (1, 4):
            msgbuf = <char *>PyMem_Malloc(512)
            estr = <bytes>_c_.svn_err_best_message(
                                self._c_error, msgbuf, <_c_.apr_size_t>512)
            PyMem_Free(<void*>msgbuf)
        ELSE:
            if self._c_error is NULL:
                estr = ''
            else:
                eptr = self._c_error
                if eptr.message is not NULL:
                    estr = eptr.message
                else:
                    estr = b''
                eptr = eptr.child
                while eptr is not NULL:
                    if eptr.message is not NULL:
                        estr = estr + b'\n' + eptr.message
                    eptr = eptr.child
            IF PY_VERSION >= (3, 0, 0):
                estr = eptr.decode('utf-8')
        return estr
    def __dealloc__(self):
        if self._c_error is not NULL:
            _c_.svn_error_clear(self._c_error)

# Svn_error as exception
class SVNerr(General):
    def __init__(self, msg=None, stat=None):
        if isinstance(msg, Svn_error):
            self.svnerr = msg
        else:
            self.svnerr = Svn_error(msg, stat)
    def __str__(self):
        return str(self.svnerr)
    def __repr__(self):
        return str(self.svnerr)
    def get_code(self):
        if (<Svn_error>self.svnerr)._c_error is NULL:
            return 0
        else:
            return (<Svn_error>self.svnerr)._c_error.apr_err
    def get_code_list(self):
        cdef _c_.svn_error_t * eptr
        eptr = (<Svn_error>self.svnerr)._c_error
        r = []
        while eptr is not NULL:
            r.append(eptr.apr_err)
            eptr = eptr.child
        return r

# from "svn_types.h"
SVN_INVALID_REVNUM = _c_.SVN_INVALID_REVNUM
SVN_IGNORED_REVNUM = _c_.SVN_IGNORED_REVNUM
SVN_STREAM_CHUNK_SIZE = _c_.SVN_STREAM_CHUNK_SIZE

# from "svn_types.h" svn_node_kind_t
svn_node_none    = _c_.svn_node_none
svn_node_file    = _c_.svn_node_file
svn_node_dir     = _c_.svn_node_dir
svn_node_unknown = _c_.svn_node_unknown
IF SVN_API_VER >= (1, 8):
    svn_node_symlink = _c_.svn_node_symlink
IF SVN_API_VER >= (1, 6):
    def svn_node_kind_to_word(_c_.svn_node_kind_t kind):
        return <bytes>_c_.svn_node_kind_to_word(kind)
    def svn_node_kind_from_word(const char * word):
        return _c_.svn_node_kind_from_word(word)

# from "svn_props.h"
IF PY_VERSION < (3, 0, 0):
    SVN_PROP_REVISION_LOG    = _c_.SVN_PROP_REVISION_LOG
    SVN_PROP_REVISION_AUTHOR = _c_.SVN_PROP_REVISION_AUTHOR
    SVN_PROP_REVISION_DATE   = _c_.SVN_PROP_REVISION_DATE
    SVN_PROP_EXECUTABLE      = _c_.SVN_PROP_EXECUTABLE
    SVN_PROP_SPECIAL         = _c_.SVN_PROP_SPECIAL
ELSE:
    SVN_PROP_REVISION_LOG    = (
            <bytes>(_c_.SVN_PROP_REVISION_LOG)).decode('utf-8')
    SVN_PROP_REVISION_AUTHOR = (
            <bytes>(_c_.SVN_PROP_REVISION_AUTHOR)).decode('utf-8')
    SVN_PROP_REVISION_DATE   = (
            <bytes>(_c_.SVN_PROP_REVISION_DATE)).decode('utf-8')
    SVN_PROP_EXECUTABLE      = (
            <bytes>(_c_.SVN_PROP_EXECUTABLE)).decode('utf-8')
    SVN_PROP_SPECIAL         = (
            <bytes>(_c_.SVN_PROP_SPECIAL)).decode('utf-8')

# from "svn_version.h"
SVN_VER_MAJOR = _c_.SVN_VER_MAJOR
SVN_VER_MINOR = _c_.SVN_VER_MINOR
SVN_VER_PATCH = _c_.SVN_VER_PATCH

# from "svn_opt.h"
svn_opt_revision_unspecified = _c_.svn_opt_revision_unspecified
svn_opt_revision_number      = _c_.svn_opt_revision_number
svn_opt_revision_date        = _c_.svn_opt_revision_date
svn_opt_revision_committed   = _c_.svn_opt_revision_committed
svn_opt_revision_previous    = _c_.svn_opt_revision_previous
svn_opt_revision_base        = _c_.svn_opt_revision_base
svn_opt_revision_working     = _c_.svn_opt_revision_working
svn_opt_revision_head        = _c_.svn_opt_revision_head

cdef class svn_opt_revision_t(object):
# cdef _c_.svn_opt_revision_t _c_opt_revision
    def __cinit__(self, kind=_c_.svn_opt_revision_unspecified, value=0):
        self.set(kind, value)
    def set(self, kind, value=0):
        cdef svn_opt_revision_t ref
        if kind is None:
            self._c_opt_revision.kind = _c_.svn_opt_revision_unspecified
            self._c_opt_revision.value.number = 0
        elif isinstance(kind, svn_opt_revision_t):
            ref = kind
            self._c_opt_revision.kind  = ref._c_opt_revision.kind
            self._c_opt_revision.value.number = \
                    ref._c_opt_revision.value.number
        elif kind == _c_.svn_opt_revision_number:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.number = value
        elif kind == _c_.svn_opt_revision_date:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.date = value
        elif kind in [
                _c_.svn_opt_revision_unspecified,
                _c_.svn_opt_revision_committed,
                _c_.svn_opt_revision_previous,
                _c_.svn_opt_revision_base,
                _c_.svn_opt_revision_working,
                _c_.svn_opt_revision_head]:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.number = 0
        else:
            raise ValueError('unknown svn_opt_revision_kind: ' + str(kind))
        return self
    cdef svn_opt_revision_t _c_set(self, _c_.svn_opt_revision_t _c_rev):
        if _c_rev.kind == _c_.svn_opt_revision_number:
            self._c_opt_revision.kind = _c_rev.kind
            self._c_opt_revision.value.number = _c_rev.value.number
        elif _c_rev.kind == _c_.svn_opt_revision_date:
            self._c_opt_revision.kind = _c_rev.kind
            self._c_opt_revision.value.date = _c_rev.value.date
        elif _c_rev.kind in [
                _c_.svn_opt_revision_unspecified,
                _c_.svn_opt_revision_committed,
                _c_.svn_opt_revision_previous,
                _c_.svn_opt_revision_base,
                _c_.svn_opt_revision_working,
                _c_.svn_opt_revision_head]:
            self._c_opt_revision.kind = _c_rev.kind
            self._c_opt_revision.value.number = 0
        else:
            raise ValueError('unknown svn_opt_revision_kind: '
                             + str(_c_rev.kind))
        return self
    @property
    def kind(self):
        return self._c_opt_revision.kind
    @kind.setter
    def kind(self, kind):
        if kind == _c_.svn_opt_revision_number:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.number = _c_.SVN_INVALID_REVNUM
        elif kind == _c_.svn_opt_revision_date:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.date = 0
        elif kind in [
                _c_.svn_opt_revision_unspecified,
                _c_.svn_opt_revision_committed,
                _c_.svn_opt_revision_previous,
                _c_.svn_opt_revision_base,
                _c_.svn_opt_revision_working,
                _c_.svn_opt_revision_head]:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.number = 0
        else:
            raise ValueError('unknown svn_opt_revision_kind: ' + str(kind))
    @property
    def value(self):
        if self._c_opt_revision.kind == _c_.svn_opt_revision_number:
            return self._c_opt_revision.value.number
        elif self._c_opt_revision.kind == _c_.svn_opt_revision_date:
            return self._c_opt_revision.value.date
        elif self._c_opt_revision.kind in [
                _c_.svn_opt_revision_unspecified,
                _c_.svn_opt_revision_committed,
                _c_.svn_opt_revision_previous,
                _c_.svn_opt_revision_base,
                _c_.svn_opt_revision_working,
                _c_.svn_opt_revision_head]:
            # Though value has no mean, return it
            return self._c_opt_revision.value.number
        else:
            # foolproof
            raise ValueError('unknown svn_opt_revision_kind "'
                             + str(self._c_opt_revision.kind)
                             + '" has set')
    @value.setter
    def value(self, value):
        if self._c_opt_revision.kind == _c_.svn_opt_revision_number:
            self._c_opt_revision.value.number = value
        elif self._c_opt_revision.kind == _c_.svn_opt_revision_date:
            self._c_opt_revision.value.date = value
        elif self._c_opt_revision.kind in [
                _c_.svn_opt_revision_unspecified,
                _c_.svn_opt_revision_committed,
                _c_.svn_opt_revision_previous,
                _c_.svn_opt_revision_base,
                _c_.svn_opt_revision_working,
                _c_.svn_opt_revision_head]:
            # Though value has no mean, set it
            self._c_opt_revision.value.number = value
        else:
            # foolproof
            raise ValueError('unknown svn_opt_revision_kind "'
                             + str(self._c_opt_revision.kind)
                             + '" has set')

def canonicalize_path(path, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef const char * _c_rpath
    cdef object rpath
    cdef _c_.svn_error_t * serr
    cdef Svn_error pyerr

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    assert isinstance(path, bytes)
    if scratch_pool is not None:
        assert (<Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<Apr_Pool>scratch_pool)._c_pool)
    else:
        _scratch_pool.clear()
        ast = _c_.apr_pool_create(&_c_tmp_pool, _scratch_pool._c_pool)
    if ast:
        raise PoolError()
    try:
        IF SVN_API_VER >= (1, 7):
            if _c_.svn_path_is_url(path):
                _c_rpath = _c_.svn_uri_canonicalize(
                                                path, _c_tmp_pool)
                rpath = _c_rpath
            else:
                _c_rpath = _c_.svn_dirent_canonicalize(
                                                path, _c_tmp_pool)
                rpath = _c_rpath
                assert os.path.isabs(rpath)
        ELSE:
            _c_rpath = _c_.svn_path_canonicalize(path, _c_tmp_pool)
            rpath = _c_rpath
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return rpath

def canonicalize_rootpath(path, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef const char * _c_rootpath
    cdef object rootpath
    cdef _c_.svn_error_t * serr
    cdef Svn_error pyerr

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    assert isinstance(path, bytes)
    if scratch_pool is not None:
        assert (<Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<Apr_Pool>scratch_pool)._c_pool)
    else:
        _scratch_pool.clear()
        ast = _c_.apr_pool_create(&_c_tmp_pool, _scratch_pool._c_pool)
    if ast:
        raise PoolError()
    try:
        if _c_.svn_path_is_url(path):
            IF SVN_API_VER >= (1, 7):
                _c_rootpath = _c_.svn_uri_canonicalize(
                                                path, _c_tmp_pool)
            ELSE:
                _c_rootpath = _c_.svn_path_canonicalize(
                                                path, _c_tmp_pool)
            rootpath = _c_rootpath
            if rootpath.lower().startswith(b'file:'):
                IF SVN_API_VER >= (1, 7):
                    serr = _c_.svn_uri_get_dirent_from_file_url(
                                &_c_rootpath, <const char *>rootpath,
                                _c_tmp_pool)
                    if serr is not NULL:
                        pyerr = Svn_error().seterror(serr)
                        raise SVNerr(pyerr)
                    rootpath = _c_rootpath
                ELSE:
                    rootpath_lower = rootpath.lower()
                    if rootpath_lower in [b'file://localhost',
                                          b'file://localhost/',
                                          b'file://',
                                          b'file:///'
                                         ]:
                        rootpath = b'/'
                    elif rootpath_lower.startswith(b'file://localhost/'):
                        rootpath = os.path.normpath(
                                        urllib.unquote(rootpath[16:]))
                    else:
                        assert rootpath_lower.startswith(b'file:///')
                        rootpath = os.path.normpath(
                                        urllib.unquote(rootpath[7:]))
                assert os.path.isabs(rootpath)
        else:
            IF SVN_API_VER >= (1, 6):
                _c_rootpath = _c_.svn_dirent_canonicalize(
                                                path, _c_tmp_pool)
            ELSE:
                _c_rootpath = _c_.svn_path_canonicalize(
                                                path, _c_tmp_pool)
            rootpath = _c_rootpath
            assert os.path.isabs(rootpath)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return rootpath

# called from svn_repos module
def rootpath2url(rootpath, path, scratch_pool=None):
    cdef bytes fullpath
    cdef const char * _c_dirent
    cdef bytes dirent
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef const char * _c_url
    cdef object url
    cdef _c_.svn_error_t * serr
    cdef Svn_error pyerr

    rootpath = os.path.abspath(rootpath)
    if scratch_pool is not None:
        fullpath = canonicalize_path(os.path.join(rootpath, path),
                                     scratch_pool)
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<Apr_Pool>scratch_pool)._c_pool)
    else:
        _scratch_pool.clear()
        fullpath = canonicalize_path(os.path.join(rootpath, path),
                                     _scratch_pool)
        _scratch_pool.clear()
        ast = _c_.apr_pool_create(&_c_tmp_pool, _scratch_pool._c_pool)
    if ast:
        raise PoolError()
    try:
        IF SVN_API_VER >= (1, 7):
            _c_dirent = fullpath
            serr = _c_.svn_uri_get_file_url_from_dirent(
                                &_c_url, _c_dirent, _c_tmp_pool)
            if serr is not NULL:
                pyerr = Svn_error().seterror(serr)
                raise SVNerr(pyerr)
            url = _c_url
        ELSE:
            # implement what svn_uri_get_file_url_from_dirent has done
            # from subversion/libsvn_subr/dirent.c (from subversion 1.10)
            _c_dirent = _c_.svn_path_uri_encode(fullpath, _c_tmp_pool)
            IF not SVN_USE_DOS_PATHS:
                if _c_dirent[0] == ord(b'/') and _c_dirent[1] == 0:
                    url = b'file://'
                else:
                    dirent = _c_dirent
                    url = b'file://' + dirent
            ELSE:
                if _c_dirent[0] == ord(b'/'): # expect  UNC, not non-absolute
                    assert _c_dirent[1] == ord(b'/')
                    dirent = _c_dirent
                    url = b'file:' + dirent
                else:
                    dirent = _c_dirent
                    url = b'file:///' + dirent
                    # "C:/" is a canonical dirent on Windows,
                    # but "file:///C:/' is not a canonical uri */
                    if url[-1:] == b'/':
                        url = url[0:-1]
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return url

# called from svn_repos module
def datestr_to_date(datestr, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef Svn_error pyerr
    cdef _c_.apr_time_t _c_when

    if scratch_pool is not None:
        assert (<Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<Apr_Pool>scratch_pool)._c_pool)
    else:
        _scratch_pool.clear()
        ast = _c_.apr_pool_create(&_c_tmp_pool, _scratch_pool._c_pool)
    if ast:
        raise PoolError()
    try:
        serr = _c_.svn_time_from_cstring(
                        &_c_when, datestr, _c_tmp_pool)
        if serr is not NULL:
            _c_.svn_error_clear(serr)
            when = None
        else:
            when = _c_when
            when = when / 1000000
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return when

# from "svn_io.h"
cdef class svn_stream_t(object):
    # cdef _c_.svn_stream_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
    cdef svn_stream_t set_stream(
             svn_stream_t self, _c_.svn_stream_t * stream, object pool):
        self._c_ptr = stream
        assert pool is None or isinstance(pool, Apr_Pool)
        self.pool = pool
        return self
    def close(self):
        cdef _c_.svn_error_t * serr
        cdef Svn_error pyerr
        if self._c_ptr is not NULL:
            serr = _c_.svn_stream_close(self._c_ptr)
            if serr is not NULL:
                pyerr = Svn_error().seterror(serr)
                raise SVNerr(pyerr)
            self.pool = None
            self._c_ptr = NULL


cdef char _streambuf[_c_.SVN_STREAM_CHUNK_SIZE]


def svn_stream_read_full(svn_stream_t stream, len):
    cdef _c_.apr_size_t _c_len
    cdef char * _c_buf
    cdef _c_.svn_error_t * serr
    cdef Svn_error pyerr
    # Note: this function read stream as bytes stream without decode
    assert len > 0
    assert stream._c_ptr is not NULL
    if len > _c_.SVN_STREAM_CHUNK_SIZE:
        _c_buf = <char *>PyMem_Malloc(len)
    else:
        _c_buf = _streambuf
    _c_len = len
    IF SVN_API_VER >= (1, 9):
        serr = _c_.svn_stream_read_full(stream._c_ptr, _c_buf, &_c_len)
    ELSE:
        serr = _c_.svn_stream_read(stream._c_ptr, _c_buf, &_c_len)
    if serr is not NULL:
        if _c_buf != _streambuf:
            PyMem_Free(_c_buf)
        pyerr = Svn_error().seterror(serr)
        raise SVNerr(pyerr)
    if _c_len > 0:
        buf = (<bytes>_c_buf)[0:_c_len]
    else:
        buf = b''
    if _c_buf != _streambuf:
        PyMem_Free(_c_buf)
    return buf, _c_len


IF SVN_API_VER >= (1, 9):
    def svn_stream_read2(svn_stream_t stream, len):
        cdef _c_.apr_size_t _c_len
        cdef char * _c_buf
        cdef _c_.svn_error_t * serr
        cdef Svn_error pyerr
        # Note: this function read stream as bytes stream without decode
        assert len > 0
        assert stream._c_ptr is not NULL
        if len > _c_.SVN_STREAM_CHUNK_SIZE:
            _c_buf = <char *>PyMem_Malloc(len)
        else:
            _c_buf = _streambuf
        _c_len = len
        IF SVN_API_VER >= (1, 9):
            serr = _c_.svn_stream_read_full(stream._c_ptr, _c_buf, &_c_len)
        ELSE:
            serr = _c_.svn_stream_read(stream._c_ptr, _c_buf, &_c_len)
        if serr is not NULL:
            if _c_buf != _streambuf:
                PyMem_Free(_c_buf)
            pyerr = Svn_error().seterror(serr)
            raise SVNerr(pyerr)
        if _c_len > 0:
            buf = (<bytes>_c_buf)[0:_c_len]
        else:
            buf = b''
        if _c_buf != _streambuf:
            PyMem_Free(_c_buf)
        return buf, _c_len


IF SVN_API_VER >= (1, 7):
    def svn_stream_skip(svn_stream_t stream, len):
        cdef _c_.apr_size_t _c_len
        cdef _c_.svn_error_t * serr
        cdef Svn_error pyerr
        # Note: this function read stream as bytes stream without decode
        assert len > 0
        assert stream._c_ptr is not NULL
        _c_len = len
        serr = _c_.svn_stream_skip(stream._c_ptr, _c_len)
        if serr is not NULL:
            pyerr = Svn_error().seterror(serr)
            raise SVNerr(pyerr)
        return


def svn_stream_write(svn_stream_t stream, const char * data, len):
    cdef _c_.apr_size_t _c_len
    cdef char * _c_buf
    cdef _c_.svn_error_t * serr
    cdef Svn_error pyerr
    # Note: this function write to stream as bytes without encode/decode
    assert len > 0
    assert stream._c_ptr is not NULL
    _c_len = len
    serr = _c_.svn_stream_write(stream._c_ptr, data, &_c_len)
    if serr is not NULL:
        pyerr = Svn_error().seterror(serr)
        raise SVNerr(pyerr)
    return _c_len


def svn_stream_close(svn_stream_t stream):
    stream.close()


IF SVN_API_VER >= (1, 7):
    cdef class svn_stream_mark_t(object):
        cdef _c_.svn_stream_mark_t * _c_mark
        def __cinit__(self):
            self._c_mark = NULL
        cdef inline svn_stream_mark_t set_mark(
                svn_stream_mark_t self, _c_.svn_stream_mark_t * _c_mark):
            self._c_mark = _c_mark
            return self
        cdef inline _c_.svn_stream_mark_t * get_mark(svn_stream_mark_t self):
            return self._c_mark


    def svn_stream_mark(svn_stream_t stream, object pool):
        cdef _c_.svn_error_t * serr
        cdef _c_.svn_stream_mark_t * _c_mark
        cdef svn_stream_mark_t mark
        cdef _c_.apr_pool_t * _c_pool
        cdef Svn_error pyerr
        if pool is not None:
            assert (<Apr_Pool?>pool)._c_pool is not NULL
            _c_pool = (<Apr_Pool>pool)._c_pool
        else:
            _c_pool = _root_pool._c_pool
        serr = _c_.svn_stream_mark(stream._c_ptr, &_c_mark, _c_pool)
        if serr is not NULL:
            pyerr = Svn_error().seterror(serr)
            raise SVNerr(pyerr)
        mark =  svn_stream_mark_t().set_mark(_c_mark)
        return mark


    def svn_stream_seek(svn_stream_t stream, object mark):
        cdef _c_.svn_error_t * serr
        cdef _c_.svn_stream_mark_t * _c_mark
        cdef Svn_error pyerr
        if mark is None:
            _c_mark = NULL
        else:
            _c_mark = (<svn_stream_mark_t?>mark)._c_mark
        serr = _c_.svn_stream_seek(stream._c_ptr, _c_mark)
        if serr is not NULL:
            pyerr = Svn_error().seterror(serr)
            raise SVNerr(pyerr)
        return


IF SVN_API_VER >= (1, 9):
    def svn_stream_data_available(svn_stream_t stream):
        cdef _c_.svn_error_t * serr
        cdef _c_.svn_boolean_t _c_avail
        cdef Svn_error pyerr
        serr = _c_.svn_stream_data_available(stream._c_ptr, &_c_avail)
        if serr is not NULL:
            pyerr = Svn_error().seterror(serr)
            raise SVNerr(pyerr)
        return True if _c_avail != _c_.FALSE else False


def svn_stream_readline(
        svn_stream_t stream, const char *eol, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef Svn_error pyerr
    cdef _c_.svn_stringbuf_t * _c_stringbuf
    cdef _c_.svn_boolean_t _c_eof
    cdef object bufstr
    cdef object eof

    assert (<svn_stream_t?>stream)._c_ptr is not NULL
    if scratch_pool is not None:
        assert (<Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<Apr_Pool>scratch_pool)._c_pool)
    else:
        _scratch_pool.clear()
        ast = _c_.apr_pool_create(&_c_tmp_pool, _scratch_pool._c_pool)
    if ast:
        raise PoolError()
    try:
        serr = _c_.svn_stream_readline(stream._c_ptr, &_c_stringbuf,
                                            eol, &_c_eof, _c_tmp_pool)
        if serr is not NULL:
            pyerr = Svn_error().seterror(serr)
            raise SVNerr(pyerr)
        bufstr = _c_stringbuf.data[0:_c_stringbuf.len]
        eof = True if _c_eof else False
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return bufstr, eof


# baton wrapper ... call back function helper
cdef class CbContainer(object):
    def __cinit__(self, fnobj, btn, pool=None, **m):
        assert callable(fnobj)
        self.fnobj = fnobj
        self.btn = btn
        self.pool = pool

# helper classes/functions to build python objects from C data structures
cdef class TransPtr(object):
    cdef object to_object(self):
        raise NotImplemented()
    cdef void * from_object(self, object obj):
        raise NotImplemented()
    cdef void set_ptr(self, void *_c_ptr):
        raise NotImplemented()
    cdef void ** ptr_ref(self):
        raise NotImplemented()


# warn: passing None as scratch_pool to constructor causes memory leak,
# because _scratch_pool cannot be used as substitute for it here,
# for the life time policy of the pool. The scratch_pool passed
# by constructor should be kept alive (this is achieved by reference count
# of the scratch_pool automatically) and should not be cleared until
# the HashTrans instance is alive.
cdef class HashTrans(TransPtr):
    def __cinit__(
            self, TransPtr key_trans, TransPtr val_trans,
            scratch_pool=None, **m):
        self.tmp_pool = None
        self._c_hash = NULL
    def __init__(
            self, TransPtr key_trans, TransPtr val_trans,
            scratch_pool=None, **m):
        self.key_trans = key_trans
        self.val_trans = val_trans
        if scratch_pool is not None:
            assert (<Apr_Pool?>scratch_pool)._c_pool is not NULL
            self.tmp_pool = Apr_Pool(scratch_pool)
        else:
            self.tmp_pool = Apr_Pool(_root_pool)
    cdef object to_object(self):
        cdef _c_.apr_hash_index_t * hi
        cdef const void * _c_key
        cdef _c_.apr_ssize_t _c_klen
        cdef void * _c_val

        self.tmp_pool.clear()
        hi = _c_.apr_hash_first(
                    self.tmp_pool._c_pool, self._c_hash)
        rdict = {}
        while hi is not NULL:
            _c_.apr_hash_this(hi,
                                   <const void **>(self.key_trans.ptr_ref()),
                                   &_c_klen,
                                   <void **>self.val_trans.ptr_ref())
            rdict[self.key_trans.to_object()] = self.val_trans.to_object()
            hi = _c_.apr_hash_next(hi)
        return rdict
    cdef void set_ptr(self, void *_c_ptr):
        self._c_hash = <_c_.apr_hash_t *>_c_ptr
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_hash)

cdef object hash_to_dict(_c_.apr_hash_t * _c_hash,
                         ptr_to_pyobj_func_t key_func,
                         ptr_to_pyobj_func_t val_func,
                         _c_.apr_pool_t * _c_scratch_pool):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.apr_hash_index_t * hi
    cdef const void * _c_key
    cdef _c_.apr_ssize_t _c_klen
    cdef void * _c_val

    if _c_scratch_pool is NULL:
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, _root_pool._c_pool)
    else:
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, _c_scratch_pool)
    if ast:
        raise PoolError()
    try:
        hi = _c_.apr_hash_first(_c_tmp_pool, _c_hash)
        rdict = {}
        while hi is not NULL:
            _c_.apr_hash_this(hi, &_c_key, &_c_klen, &_c_val)
            rdict[key_func(<void *>_c_key, _c_tmp_pool)] = \
                    val_func(_c_val, _c_tmp_pool)
            hi = _c_.apr_hash_next(hi)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return rdict

cdef class CStringTransBytes(TransPtr):
    def __cinit__(self):
        self._c_str = NULL
    cdef object to_object(self):
        cdef object pybytes
        pybytes = self._c_str
        return pybytes
    cdef void set_ptr(self, void *_c_ptr):
        self._c_str = <char *>_c_ptr
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_str)

IF PY_VERSION >= (3, 0, 0):
    cdef class CStringTransStr(TransPtr):
        def __cinit__(self):
            self._c_str = NULL
        cdef object to_object(self):
            cdef object pybytes
            pybytes = self._c_str
            return pybytes.decode('utf-8')
        cdef void set_ptr(self, void *_c_ptr):
            self._c_str = <char *>_c_ptr
        cdef void ** ptr_ref(self):
            return <void **>&(self._c_str)

ELSE:
    cdef class CStringTransStr(CStringTransBytes):
        pass

cdef class SvnStringTransBytes(TransPtr):
    def __cinit__(self):
        self._c_svn_str = NULL
    cdef object to_object(self):
        cdef object pybytes
        pybytes = self._c_svn_str[0].data[:self._c_svn_str[0].len]
        return pybytes
    cdef void set_ptr(self, void *_c_ptr):
        self._c_svn_str = <_c_.svn_string_t *>_c_ptr
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_svn_str)

IF PY_VERSION >= (3, 0, 0):
    cdef class SvnStringTransStr(TransPtr):
        def __cinit__(self):
            self._c_svn_str = NULL
        cdef object to_object(self):
            cdef object pybytes
            pybytes = self._c_svn_str[0].data[:self._c_svn_str[0].len]
            return pybytes.decode('utf-8')
        cdef void set_ptr(self, void *_c_ptr):
            self._c_svn_str = <_c_.svn_string_t *>_c_ptr
        cdef void ** ptr_ref(self):
            return <void **>&(self._c_svn_str)

ELSE:
    cdef class SvnStringTransStr(SvnStringTransBytes):
        pass

cdef class SvnBooleanTrans(TransPtr):
    cdef object to_object(self):
        if self._c_bool != _c_.FALSE:
            return True
        return False
    cdef void set_c_bool(self, _c_.svn_boolean_t _c_bool):
        self._c_bool = _c_bool
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_bool)


# for test, not used by vclib modules
IF SVN_API_VER < (1, 4):
    # from ^/subversion/tags/1.3.0/subversion/libsvn_subr/stream.c,
    # private struct used by svn_stream_from_aprfile(),
    # and may work on 1.10.0, but there is no warranty to work in future...
    ctypedef struct baton_apr:
        _c_.apr_file_t * file
        _c_.apr_pool_t * pool
    cdef _c_.svn_error_t * close_handler_apr(void *baton) nogil:
        cdef baton_apr * btn
        btn = <baton_apr *>baton
        return _c_.svn_io_file_close(btn[0].file, btn[0].pool)

def svn_stream_open_readonly(
        const char * path, result_pool=None, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef Apr_Pool r_pool
    cdef _c_.svn_stream_t * _c_stream
    cdef _c_.svn_error_t * serr
    cdef Svn_error pyerr
    IF SVN_API_VER < (1, 6):
        cdef _c_.apr_file_t * _c_file

    if result_pool is not None:
        assert (<Apr_Pool?>result_pool)._c_pool is not NULL
        r_pool = result_pool
    else:
        r_pool = _root_pool
    if scratch_pool is not None:
        assert (<Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                       (<Apr_Pool>scratch_pool)._c_pool)
    else:
        _scratch_pool.clear()
        ast = _c_.apr_pool_create(&_c_tmp_pool, _scratch_pool._c_pool)
    if ast:
        raise PoolError()
    try:
        IF SVN_API_VER >= (1, 6):
            serr = _c_.svn_stream_open_readonly(
                            &_c_stream, path, r_pool._c_pool, _c_tmp_pool)
            if serr is not NULL:
                pyerr = Svn_error().seterror(serr)
                raise SVNerr(pyerr)
        ELSE:
            serr = _c_.svn_io_file_open(
                        &_c_file, path,
                        _c_.APR_READ | _c_.APR_BUFFERED,
                        _c_.APR_OS_DEFAULT, r_pool._c_pool)
            if serr is not NULL:
                pyerr = Svn_error().seterror(serr)
                raise SVNerr(pyerr)
            IF SVN_API_VER >= (1, 4):
                _c_stream = _c_.svn_stream_from_aprfile2(
                                    _c_file, _c_.FALSE, r_pool._c_pool)
            ELSE:
                _c_stream = _c_.svn_stream_from_aprfile(
                                    _c_file, r_pool._c_pool)
                _c_.svn_stream_set_close(_c_stream, close_handler_apr)
        stream = svn_stream_t()
        stream.set_stream(_c_stream, r_pool)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return stream


# least class to implement of buffer protocol for Python I/O
cdef class CharPtrWriteBuffer:
    cdef CharPtrWriteBuffer set_buffer(
            CharPtrWriteBuffer self, char * _c_buf, Py_ssize_t len):
        self._c_buf = _c_buf
        self.len = len
        self.shape[0] = len
        self.strides[0] = 1
    def __getbuffer__(self, Py_buffer * buffer, int flags):
        buffer.buf = self._c_buf
        buffer.obj = self
        buffer.len = self.len
        buffer.readonly = 0
        buffer.itemsize = 1
        buffer.format = NULL
        buffer.ndim = 1
        buffer.shape = self.shape
        buffer.strides = self.strides
        buffer.suboffsets = NULL
        buffer.internal = NULL
    def __releasebuffer__(self, Py_buffer * buffer):
        pass


cdef class CharPtrReadBuffer:
    cdef CharPtrReadBuffer set_buffer(
            CharPtrReadBuffer self, const char * _c_buf, Py_ssize_t len):
        self._c_buf = _c_buf
        self.len = len
        self.shape[0] = len
        self.strides[0] = 1

    def __getbuffer__(self, Py_buffer * buffer, int flags):
        buffer.buf = <char *>(self._c_buf)
        buffer.obj = self
        buffer.len = self.len
        buffer.readonly = 1
        buffer.itemsize = 1
        buffer.format = NULL
        buffer.ndim = 1
        buffer.shape = self.shape
        buffer.strides = self.strides
        buffer.suboffsets = NULL
        buffer.internal = NULL

    def __releasebuffer__(self, Py_buffer * buffer):
        pass


# baton for python stream wrapper
cdef class _py_stream_baton(object):
    def __cinit__(self):
        self.baton = None
        IF SVN_API_VER >= (1, 7):
            self.marks = {}
            self.next_mark = 1

# an (least) implementation of svn_stream_t for Python I/O
# baton
cdef class _py_io_stream_baton(object):
    def __cinit__(self, object fo):
        self.fo = None
        self.is_eof = True
    def __init__(self, fo):
        self.fo = fo
        self.is_eof = False

# callbacks
cdef _c_.svn_error_t * _py_io_read_fn(
        void * _c_baton, char * _c_buffer, _c_.apr_size_t * _c_len) with gil:
    cdef _py_io_stream_baton btn
    cdef _c_.svn_error_t * _c_err
    cdef _c_.apr_status_t ast
    cdef char * emsg
    cdef object err
    cdef CharPtrWriteBuffer buf
    cdef object len

    btn = <_py_io_stream_baton>_c_baton
    _c_err = NULL
    if btn.is_eof:
        _c_len[0] = 0
        return _c_err
    if _c_len[0] == 0:
        return _c_err
    # wrap the buffer pointer into buffer object
    buf = CharPtrWriteBuffer.__new__(CharPtrWriteBuffer)
    buf.set_buffer(_c_buffer, _c_len[0])
    try:
        len = btn.fo.readinto(buf)
        if len is None:
            _c_len[0] = 0
            ast = _c_.APR_EAGAIN
            _c_err = _c_.svn_error_create(ast, NULL, NULL)
        else:
            if len == 0:
                btn.is_eof = True
            _c_len[0] = len
    except io.UnsuportedOperation as err:
        IF SVN_API_VER >= (1, 9):
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
        ELSE:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_UNSUPPORTED_FEATURE, NULL, NULL)
    except io.BlockingIOError as err:
        _c_len[0] = err.characters_written
        emsg = NULL
        if err.errno in (errno.EAGAIN, errno.EWOULDBLOCK):
            ast = _c_.APR_EAGAIN
        elif err.errno in (errno.EALREADY, errno.EINPROGRESS):
            ast = _c_.APR_EINPROGRESS
        else:
            # unknown ...
            ast = _c_.APR_EGENERAL
            emsg = b'Unknown BlockingIOError on reading buffer'
        _c_err = _c_.svn_error_create(ast, NULL, emsg)
    except KeyboardInterrupt as err:
        _c_err = _c_.svn_error_create(
                    _c_.SVN_ERR_CANCELLED, NULL, str(err))
    except Exception as err:
        _c_err = _c_.svn_error_create(
                    _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                    ("Python exception has been set while reading buffer: %s"
                      % str(err)))
    finally:
        del buf
    return _c_err


cdef _c_.svn_error_t * _py_io_read_full_fn(
        void * _c_baton, char * _c_buffer, _c_.apr_size_t * _c_len) with gil:
    cdef _py_io_stream_baton btn
    cdef CharPtrWriteBuffer buf
    cdef object len
    cdef char * _c_bp
    cdef _c_.apr_size_t rest
    cdef _c_.svn_error_t * _c_err
    cdef object err

    btn = <_py_io_stream_baton>_c_baton
    _c_err = NULL
    if btn.is_eof:
        _c_len[0] = 0
        return _c_err

    _c_bp = _c_buffer
    rest = _c_len[0]
    buf = CharPtrWriteBuffer.__new__(CharPtrWriteBuffer)
    buf.set_buffer(_c_bp, rest)
    try:
        len = btn.fo.readinto(buf)
        if len is None:
            # no bytes are available in blocking mode
            len = 0
        elif len == 0:
            btn.is_eof = True
            _c_len[0] = 0
            return _c_err
        elif len == rest:
            return _c_err
    except io.BlockingIOError as err:
        # blocking while reading: ignore and retry
        len = err.characters_written
    except io.UnsupportedOperation:
        IF SVN_API_VER >= (1, 9):
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
        ELSE:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_UNSUPPORTED_FEATURE, NULL, NULL)
        _c_len[0] = 0
        del buf
        return _c_err
    except KeyboardInterrupt as err:
        _c_len[0] = err.characters_written
        _c_err = _c_.svn_error_create(
                    _c_.SVN_ERR_CANCELLED, NULL, str(err))
        del buf
        return _c_err
    except Exception as err:
        _c_len[0] = <_c_.apr_size_t>getattr(err, 'characters_written', 0)
        _c_err = _c_.svn_error_create(
                    _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                ("Python exception has been set while reading buffer: %s"
              % str(err)))
        del buf
        return _c_err
    rest -= len
    _c_bp += len
    buf.set_buffer(_c_bp, rest)
    while True:
        try:
            len = btn.fo.readinto(buf)
            if len is None:
                continue
            elif len == 0:
                btn.is_eof = True
                _c_len[0] -= rest
                break
            elif len == rest:
                break
        except io.BlockingIOError as err:
            len = err.characters_written
            if len == rest:
                # may not happen: blocked but already read specified bytes.
                break
        except KeyboardInterrupt as err:
            len = err.characters_written
            rest -= len
            _c_len[0] -= rest
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_CANCELLED, NULL, str(err))
            break
        except Exception as err:
            len = <_c_.apr_size_t>getattr(err, 'characters_written', 0)
            rest -= len
            _c_len[0] -= rest
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                    ("Python exception has been set while reading buffer: %s"
                  % str(err)))
            break
        # end of try block
        rest -= len
        _c_bp += len
        buf.set_buffer(_c_bp, rest)
    # end of loop

    del buf
    return _c_err


IF SVN_API_VER >= (1, 7):
    cdef _c_.svn_error_t * _py_io_skip_with_seek_fn(
                void * _c_baton, _c_.apr_size_t len) with gil:
        cdef _py_io_stream_baton btn
        cdef _c_.svn_error_t * _c_err
        cdef object err

        btn = <_py_io_stream_baton>_c_baton
        _c_err = NULL
        try:
            btn.fo.seek(len, 1)
        except io.UnsupportedOperation:
            # fall back to without seek version
            return _py_io_skip_without_seek_fn(_c_baton, len)
        except Exception as err:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                        ("Python exception has been set in stream_skip: %s"
                          % str(err)))
        return _c_err


    cdef _c_.svn_error_t * _py_io_skip_without_seek_fn(
                void * _c_baton, _c_.apr_size_t len) with gil:
        cdef _py_io_stream_baton btn
        cdef _c_.apr_size_t rest
        cdef _c_.apr_size_t rlen
        cdef object rbytes
        cdef _c_.svn_error_t * _c_err
        cdef object err

        btn = <_py_io_stream_baton>_c_baton
        _c_err = NULL
        rest = len
        while rest > 0:
            try:
                rbytes, rlen = btn.fo.read(rest)
            except io.UnsupportedOperation:
                IF SVN_API_VER >= (1, 9):
                    _c_err = _c_.svn_error_create(
                                _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
                ELSE:
                    _c_err = _c_.svn_error_create(
                                _c_.SVN_ERR_UNSUPPORTED_FEATURE, NULL, NULL)
                break
            except io.BlockingIOError as err:
                rlen = err.characters_written
                if rlen == rest:
                    # may not happen: blocked but already read specified bytes.
                    break
            except KeyboardInterrupt as err:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_CANCELLED, NULL, str(err))
                break
            except Exception as err:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                            ("Python exception has been set in stream_skip: %s"
                              % str(err)))
            # end of try block
            rest -= rlen
        return _c_err


cdef _c_.svn_error_t * _py_io_write_fn(
        void * _c_baton, const char * _c_buffer,
        _c_.apr_size_t * _c_len) with gil:
    cdef _py_io_stream_baton btn
    cdef _c_.svn_error_t * _c_err
    cdef object serr
    cdef object err
    cdef Svn_error svnerr
    cdef CharPtrReadBuffer buf
    cdef object rlen
    cdef const char * _c_bp
    cdef _c_.apr_size_t rest

    btn = <_py_io_stream_baton>_c_baton
    _c_err = NULL
    if btn.is_eof:
        _c_len[0] = 0
        _c_err = _c_.svn_error_create(
                    _c_.APR_EOF, NULL, NULL)
        return _c_err

    buf = CharPtrReadBuffer.__new__(CharPtrReadBuffer)
    _c_bp = _c_buffer
    rest = _c_len[0]
    while rest > 0:
        buf.set_buffer(_c_bp, rest)
        try:
            rlen = btn.fo.write(buf)
            if rlen is None or rlen == 0:
                continue
        except io.UnsupportedOperation:
            IF SVN_API_VER >= (1, 9):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
            ELSE:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_UNSUPPORTED_FEATURE, NULL, NULL)
            break
        except io.BlockingIOError as err:
            rlen = err.characters_written
            if rlen == rest:
                # may not happen: blocked but already write specified bytes.
                rest = 0
                break
        except KeyboardInterrupt as err:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_CANCELLED, NULL, str(err))
            break
        except Exception as err:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                        ("Python exception has been set while writing buffer: "
                         "%s" % str(err)))
        # end of try block
        rest -= rlen
        _c_bp += rlen
    # end of while
    _c_len[0] -= rest
    del buf
    return _c_err


cdef _c_.svn_error_t * _py_io_close_fn(void * _c_baton) with gil:
    cdef _py_io_stream_baton btn
    cdef _c_.svn_error_t * _c_err
    cdef object serr
    cdef object err
    cdef Svn_error svnerr

    btn = <_py_io_stream_baton>_c_baton
    _c_err = NULL
    try:
        btn.fo.close()
        btn.is_eof = True
    except Exception as err:
        _c_err = _c_.svn_error_create(
                         _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                        ("Python exception has been set in "
                         "stream_close: %s" % str(err)))
    return _c_err


IF SVN_API_VER >= (1, 7):
    cdef _c_.svn_error_t * _py_io_mark_fn(
            void * _c_baton, _c_.svn_stream_mark_t ** _c_mark,
            _c_.apr_pool_t * _c_pool) with gil:
        cdef _py_io_stream_baton btn
        cdef object mark
        cdef _c_.svn_error_t * _c_err
        cdef object err

        btn = <_py_io_stream_baton>_c_baton
        _c_err = NULL
        try:
            mark = btn.fo.tell()
            btn.marks[btn.next_mark] = mark
            assert sizeof(void *) >= sizeof(int)
            (<int *>_c_mark)[0]= <int>(btn.next_mark)
            btn.next_mark += 1
        except Exception as err:
            _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                            ("Python exception has been set in "
                             "stream_mark: %s" % str(err)))
        return _c_err


    cdef _c_.svn_error_t * _py_io_seek_fn(
            void * _c_baton, const _c_.svn_stream_mark_t * _c_mark) with gil:
        cdef _py_io_stream_baton btn
        cdef _c_.svn_error_t * _c_err
        cdef object err
        cdef object mark

        btn = <_py_io_stream_baton>_c_baton
        _c_err = NULL
        try:
            if _c_mark is NULL:
                mark = 0
            else:
                mark_key = <int>_c_mark
                mark = btn.marks[mark_key]
            btn.fo.seek(mark, 0)
        except Exception as err:
            _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                            ("Python exception has been set in "
                             "stream_seek: %s" % str(err)))
        return _c_err

# svn_stream_t based on Python io.RawIO or io.BufferdIO
cdef class py_io_stream(svn_stream_t):
    def __cinit__(self, object fo, object pool, **m):
        pass
    def __init__(self, object fo, object pool, **m):
        assert isinstance(fo, io.IOBase)

        if pool is not None:
            assert (<Apr_Pool?>pool)._c_pool is not NULL
            self.pool = pool
        else:
            self.pool = _root_pool
        self.baton = _py_io_stream_baton(fo)
        self._c_ptr = _c_.svn_stream_create(
                                <void *>(self.baton), self.pool._c_pool)
        # check io capability and set callbacks
        if self.baton.fo.readable():
            IF SVN_API_VER >= (1, 9):
                _c_.svn_stream_set_read2(
                    self._c_ptr, _py_io_read_fn, _py_io_read_full_fn)
            ELSE:
                _c_.svn_stream_set_read(
                    self._c_ptr, _py_io_read_full_fn)
            if self.baton.fo.seekable():
                _c_.svn_stream_set_skip(self._c_ptr, _py_io_skip_with_seek_fn)
            else:
                _c_.svn_stream_set_skip(
                            self._c_ptr, _py_io_skip_without_seek_fn)
        else:
            IF SVN_API_VER >= (1, 9):
                _c_.svn_stream_set_read2(
                    self._c_ptr, NULL, NULL)
            ELSE:
                _c_.svn_stream_set_read(
                    self._c_ptr, NULL)
            _c_.svn_stream_set_seek(self._c_ptr, NULL)
        if self.baton.fo.writable():
            _c_.svn_stream_set_write(self._c_ptr, _py_io_write_fn)
        else:
            _c_.svn_stream_set_write(self._c_ptr, NULL)
        _c_.svn_stream_set_close(self._c_ptr, _py_io_close_fn)
        IF SVN_API_VER >= (1, 7):
            if self.baton.fo.seekable():
                _c_.svn_stream_set_mark(self._c_ptr, _py_io_mark_fn)
                _c_.svn_stream_set_seek(self._c_ptr, _py_io_seek_fn)
            else:
                _c_.svn_stream_set_mark(self._c_ptr, NULL)
                _c_.svn_stream_set_seek(self._c_ptr, NULL)
        IF SVN_API_VER >= (1, 9):
            # we don't support svn_stream_data_available()
            _c_.svn_stream_set_data_available(self._c_ptr, NULL)
        IF SVN_API_VER >= (1, 10):
            # we don't support svn_stream_readline() directly, simply
            # because io.BaseIO.readline() is not available here for
            # 'eol' argument, and subversion's internal fall back
            # function may be faster than implementation using Cython.
            _c_.svn_stream_set_readline(self._c_ptr, NULL)


# baton for implement generic svn_stream_t with Python
cdef class _py_generic_stream_baton(_py_stream_baton):
    def __cinit__(self):
        self.read_fn = None
        IF SVN_API_VER >= (1, 9):
            self.read_full_fn = None
        IF SVN_API_VER >= (1, 7):
            self.skip_fn = None
        self.write_fn = None
        self.close_fn = None
        IF SVN_API_VER >= (1, 7):
            self.mark_fn = None
            self.seek_fn = None
        IF SVN_API_VER >= (1, 9):
            self.data_available_fn = None
        IF SVN_API_VER >= (1, 10):
            self.readline_fn = None

# warn: for API version 1.8 and below, read_fn should read full length or
#       to EOF. And for API version 1.9 and above, read_fn is used for
#       svn_stream_read2() (may support partial read)
cdef _c_.svn_error_t * _py_read_fn(
        void * _c_baton, char * _c_buffer, _c_.apr_size_t * _c_len) with gil:
    cdef _py_generic_stream_baton btn
    cdef _c_.svn_error_t * _c_err
    cdef object serr
    cdef object err
    cdef Svn_error svnerr
    cdef CharPtrWriteBuffer buf

    btn = <_py_generic_stream_baton>_c_baton
    _c_err = NULL
    if btn.read_fn is None:
        IF SVN_API_VER >= (1, 9):
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
        ELSE:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_UNSUPPORTED_FEATURE, NULL, NULL)
        return _c_err
    # wrap the buffer pointer into buffer object
    buf = CharPtrWriteBuffer.__new__(CharPtrWriteBuffer)
    buf.set_buffer(_c_buffer, _c_len[0])
    try:
        _c_len[0] = btn.read_fn(btn.baton, buf, _c_len[0])
    except SVNerr as serr:
        svnerr = serr.svnerr
        _c_err = _c_.svn_error_dup(svnerr.geterror())
        del serr
    except Exception as err:
        _c_err = _c_.svn_error_create(
                    _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                    ("Python exception has been set while reading buffer: %s"
                      % str(err)))
    finally:
        del buf
    return _c_err


IF SVN_API_VER >= (1, 9):
    cdef _c_.svn_error_t * _py_read_full_fn(
            void * _c_baton, char * _c_buffer,
            _c_.apr_size_t * _c_len) with gil:
        cdef _py_generic_stream_baton btn
        cdef _c_.svn_error_t * _c_err
        cdef object serr
        cdef object err
        cdef Svn_error svnerr
        cdef CharPtrWriteBuffer buf

        btn = <_py_generic_stream_baton>_c_baton
        _c_err = NULL
        if btn.read_full_fn is None:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
            return _c_err
        # wrap the buffer pointer into buffer object
        buf = CharPtrWriteBuffer.__new__(CharPtrWriteBuffer)
        buf.set_buffer(_c_buffer, _c_len[0])
        try:
            _c_len[0] = btn.read_full_fn(btn.baton, buf, _c_len[0])
        except SVNerr as serr:
            svnerr = serr.svnerr
            _c_err = _c_.svn_error_dup(svnerr.geterror())
            del serr
        except Exception as err:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                        ("Python exception has been set while reading buffer: "
                         "%s" % str(err)))
        finally:
            del buf
        return _c_err


IF SVN_API_VER >= (1, 7):
    cdef _c_.svn_error_t * _py_skip_fn(
                void * _c_baton, _c_.apr_size_t len) with gil:
        cdef _py_generic_stream_baton btn
        cdef _c_.svn_error_t * _c_err
        cdef object serr
        cdef object err
        cdef Svn_error svnerr

        btn = <_py_generic_stream_baton>_c_baton
        _c_err = NULL
        if btn.skip_fn is None:
            IF SVN_API_VER >= (1, 9):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
            ELSE:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_UNSUPPORTED_FEATURE, NULL, NULL)
            return _c_err
        try:
            btn.skip_fn(btn.baton, len)
        except SVNerr as serr:
            svnerr = serr.svnerr
            _c_err = _c_.svn_error_dup(svnerr.geterror())
            del serr
        except Exception as err:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                        ("Python exception has been set in stream_skip: %s"
                          % str(err)))
        return _c_err


cdef _c_.svn_error_t * _py_write_fn(
        void * _c_baton, const char * _c_buffer,
        _c_.apr_size_t * _c_len) with gil:
    cdef _py_generic_stream_baton btn
    cdef _c_.svn_error_t * _c_err
    cdef object serr
    cdef object err
    cdef Svn_error svnerr
    cdef CharPtrReadBuffer buf
    cdef object len

    btn = <_py_generic_stream_baton>_c_baton
    _c_err = NULL
    if btn.write_fn is None:
        IF SVN_API_VER >= (1, 9):
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
        ELSE:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_UNSUPPORTED_FEATURE, NULL, NULL)
        return _c_err
    # wrap the buffer pointer into buffer object
    buf = CharPtrReadBuffer.__new__(CharPtrReadBuffer)
    buf.set_buffer(_c_buffer, _c_len[0])
    try:
        len = btn.write_fn(btn.baton, buf, _c_len[0])
        _c_len[0] = len
    except SVNerr as serr:
        svnerr = serr.svnerr
        _c_err = _c_.svn_error_dup(svnerr.geterror())
        del serr
    except Exception as err:
        _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                    ("Python exception has been set while writing buffer: %s"
                      % str(err)))
    finally:
        del buf
    return _c_err


cdef _c_.svn_error_t * _py_close_fn(void * _c_baton) with gil:
    cdef _py_generic_stream_baton btn
    cdef _c_.svn_error_t * _c_err
    cdef object serr
    cdef object err
    cdef Svn_error svnerr

    btn = <_py_generic_stream_baton>_c_baton
    _c_err = NULL
    if btn.close_fn is not None:
        try:
            btn.close_fn(btn.baton)
        except SVNerr as serr:
            svnerr = serr.svnerr
            _c_err = _c_.svn_error_dup(svnerr.geterror())
            del serr
        except Exception as err:
            _c_err = _c_.svn_error_create(
                             _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                            ("Python exception has been set in "
                             "stream_close: %s" % str(err)))
    return _c_err


IF SVN_API_VER >= (1, 7):
    cdef _c_.svn_error_t * _py_mark_fn(
            void * _c_baton, _c_.svn_stream_mark_t ** _c_mark,
            _c_.apr_pool_t * _c_pool) with gil:
        cdef _py_generic_stream_baton btn
        cdef _c_.svn_error_t * _c_err
        cdef object serr
        cdef object err
        cdef Svn_error svnerr

        btn = <_py_generic_stream_baton>_c_baton
        _c_err = NULL
        if btn.mark_fn is None:
            IF SVN_API_VER >= (1, 9):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
            ELSE:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_UNSUPPORTED_FEATURE, NULL, NULL)
            return _c_err
        try:
            mark = btn.mark_fn(btn.baton)
            btn.marks[btn.next_mark] = mark
            assert sizeof(void *) >= sizeof(int)
            (<int *>_c_mark)[0]= <int>(btn.next_mark)
            btn.next_mark += 1
        except SVNerr as serr:
            svnerr = serr.svnerr
            _c_err = _c_.svn_error_dup(svnerr.geterror())
            del serr
        except Exception as err:
            _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                            ("Python exception has been set in "
                             "stream_mark: %s" % str(err)))
        return _c_err


    cdef _c_.svn_error_t * _py_seek_fn(
            void * _c_baton, const _c_.svn_stream_mark_t * _c_mark) with gil:
        cdef _py_generic_stream_baton btn
        cdef _c_.svn_error_t * _c_err
        cdef object serr
        cdef object err
        cdef Svn_error svnerr
        cdef object mark

        btn = <_py_generic_stream_baton>_c_baton
        _c_err = NULL
        if btn.seek_fn is None:
            IF SVN_API_VER >= (1, 9):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
            ELSE:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_UNSUPPORTED_FEATURE, NULL, NULL)
            return _c_err
        try:
            if _c_mark is NULL:
                mark = None
            else:
                mark_key = <int>_c_mark
                mark = btn.marks[mark_key]
            btn.seek_fn(btn.baton, mark)
        except SVNerr as serr:
            svnerr = serr.svnerr
            _c_err = _c_.svn_error_dup(svnerr.geterror())
            del serr
        except Exception as err:
            _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                            ("Python exception has been set in "
                             "stream_seek: %s" % str(err)))
        return _c_err


IF SVN_API_VER >= (1, 9):
    cdef _c_.svn_error_t * _py_data_available_fn(
            void * _c_baton, _c_.svn_boolean_t * _c_data_available) with gil:
        cdef _py_generic_stream_baton btn
        cdef _c_.svn_error_t * _c_err
        cdef object serr
        cdef object err
        cdef Svn_error svnerr

        btn = <_py_generic_stream_baton>_c_baton
        _c_err = NULL
        if btn.data_available_fn is None:
            IF SVN_API_VER >= (1, 9):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
            ELSE:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_UNSUPPORTED_FEATURE, NULL, NULL)
            return _c_err
        try:
            if btn.data_available_fn(btn.baton):
                _c_data_available[0] = _c_.TRUE
            else:
                _c_data_available[0] = _c_.FALSE
        except SVNerr as serr:
            svnerr = serr.svnerr
            _c_err = _c_.svn_error_dup(svnerr.geterror())
            del serr
        except Exception as err:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                        ("Python exception has been set in "
                         "stream_data_available: %s" % str(err)))
        return _c_err


IF SVN_API_VER >= (1, 10):
    cdef _c_.svn_error_t * _py_readline_fn(
            void * _c_baton, _c_.svn_stringbuf_t ** _c_stringbuf,
            const char * _c_eol, _c_.svn_boolean_t * _c_eof,
            _c_.apr_pool_t * pool) with gil:
        cdef _py_generic_stream_baton btn
        cdef _c_.svn_error_t * _c_err
        cdef object serr
        cdef object err
        cdef Svn_error svnerr
        cdef object eol
        cdef Apr_Pool w_pool

        btn = <_py_generic_stream_baton>_c_baton
        _c_err = NULL
        if btn.readline_fn is None:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_STREAM_NOT_SUPPORTED, NULL, NULL)
            return _c_err
        eol = _c_eol
        IF PY_VERSION >= (3, 0, 0):
            eol = _norm(eol)
        w_pool = Apr_Pool.__new__(Apr_Pool, None)
        w_pool.set_pool(pool)
        try:
             buf, eof = btn.readline_fn(btn.baton, eol, w_pool)
             _c_stringbuf[0] = _c_.svn_stringbuf_create(
                                            <const char *>buf, pool)
        except SVNerr as serr:
            svnerr = serr.svnerr
            _c_err = _c_.svn_error_dup(svnerr.geterror())
            del serr
        except Exception as err:
            _c_err = _c_.svn_error_create(
                        _c_.SVN_ERR_SWIG_PY_EXCEPTION_SET, NULL,
                        ("Python exception has been set in "
                         "stream_readline: %s" % str(err)))
        return _c_err

cdef class py_stream(svn_stream_t):
    def __init__(self, pool=None):
        if pool is not None:
            assert (<Apr_Pool?>pool)._c_pool is not NULL
            self.pool = pool
        else:
            self.pool = _root_pool
        self.baton = _py_generic_stream_baton()
        self._c_ptr = _c_.svn_stream_create(
                                <void *>(self.baton), self.pool._c_pool)
    def set_baton(self, baton):
        self.baton.baton = baton
    IF SVN_API_VER >= (1, 9):
        def set_read(self, read_fn=None, read_full_fn=None):
            if read_fn or read_full_fn:
                _c_.svn_stream_set_read2(
                    self._c_ptr, _py_read_fn, _py_read_full_fn)
            else:
                _c_.svn_stream_set_read2(
                    self._c_ptr, NULL, NULL)
            self.baton.read_fn = read_fn
            self.baton.read_full_fn = read_full_fn
    ELSE:
        def set_read(self, read_fn=None):
            if read_fn:
                _c_.svn_stream_set_read(self._c_ptr, _py_read_fn)
            else:
                _c_.svn_stream_set_read(self._c_ptr, NULL)
            self.baton.read_fn = read_fn
    IF SVN_API_VER >= (1, 7):
        def set_skip(self, skip_fn=None):
            if skip_fn:
                _c_.svn_stream_set_skip(self._c_ptr, _py_skip_fn)
            else:
                _c_.svn_stream_set_skip(self._c_ptr, NULL)
            self.baton.skip_fn = skip_fn
    def set_write(self, write_fn=None):
        if write_fn:
            _c_.svn_stream_set_write(self._c_ptr, _py_write_fn)
        else:
            _c_.svn_stream_set_write(self._c_ptr, NULL)
        self.baton.write_fn = write_fn
    def set_close(self, close_fn=None):
        if close_fn:
            _c_.svn_stream_set_close(self._c_ptr, _py_close_fn)
        else:
            _c_.svn_stream_set_close(self._c_ptr, NULL)
        self.baton.close_fn = close_fn
    IF SVN_API_VER >= (1, 7):
        def set_mark(self, mark_fn=None):
            if mark_fn:
                _c_.svn_stream_set_mark(self._c_ptr, _py_mark_fn)
            else:
                _c_.svn_stream_set_mark(self._c_ptr, NULL)
            self.baton.mark_fn = mark_fn
        def set_seek(self, seek_fn=None):
            if seek_fn:
                _c_.svn_stream_set_seek(self._c_ptr, _py_seek_fn)
            else:
                _c_.svn_stream_set_seek(self._c_ptr, NULL)
            self.baton.seek_fn = seek_fn
    IF SVN_API_VER >= (1, 9):
        def set_data_available(self, data_available_fn=None):
            if data_available_fn:
                _c_.svn_stream_set_data_available(
                                self._c_ptr, _py_data_available_fn)
            else:
                _c_.svn_stream_set_data_available(self._c_ptr, NULL)
            self.baton.data_available_fn = data_available_fn
    IF SVN_API_VER >= (1, 10):
        def set_readline(self, readline_fn=None):
            if readline_fn:
                _c_.svn_stream_set_readline(self._c_ptr, _py_readline_fn)
            else:
                _c_.svn_stream_set_readline(self._c_ptr, NULL)
            self.baton.readline_fn = readline_fn

