include "subversion_1/_svn_api_ver.pxi"
include "_py_ver.pxi"
from libc.stdlib cimport atexit
from libc.stddef cimport size_t
from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free
from apr_1 cimport apr
from apr_1 cimport apr_errno
from apr_1 cimport apr_general
from apr_1 cimport apr_pools
from apr_1 cimport apr_time
from apr_1 cimport apr_hash
IF SVN_API_VER < (1, 6):
    from apr_1 cimport apr_file_io
from subversion_1 cimport svn_types
from subversion_1 cimport svn_error
from subversion_1 cimport svn_error_codes
from subversion_1 cimport svn_props
from subversion_1 cimport svn_version
from subversion_1 cimport svn_opt
from subversion_1 cimport svn_path
from subversion_1 cimport svn_time
from subversion_1 cimport svn_string
from subversion_1 cimport svn_io
IF SVN_API_VER >= (1, 6):
    from subversion_1 cimport svn_dirent_uri

import os
import os.path
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

def _initialize():
    cdef void* errstrbuf
    cdef apr_errno.apr_status_t ast
    cdef int nelm = 1024
    cdef size_t bufsize
    cdef crv
    ast = apr_general.apr_initialize()
    if ast:
        bufsize = nelm * sizeof(char)
        errstrbuf = PyMem_Malloc(nelm)
        if not errstrbuf:
            raise MemoryError()
        estr = apr_errno.apr_strerror(ast, <char *>errstrbuf, bufsize)
        PyMem_Free(errstrbuf)
        raise InitError(estr)
    else:
        if 0 != atexit(apr_general.apr_terminate2):
            apr_general.apr_terminate2()
            raise MemoryError()
    return

_initialize()
del _initialize

# from "apr_pools.h" representation of apr_pool_t
cdef class Apr_Pool(object):
#    cdef apr_pools.apr_pool_t* _c_pool
    def __cinit__(self, Apr_Pool pool=None):
        self._c_pool = NULL
        self.is_own = False
        self._parent_pool = None
    def __init__(self, Apr_Pool pool=None):
        cdef apr_errno.apr_status_t ast
        if pool is None:
            ast = apr_pools.apr_pool_create(&(self._c_pool),NULL)
        else:
            ast = apr_pools.apr_pool_create(&(self._c_pool),pool._c_pool)
        if ast:
            raise PoolError()
        self._parent_pool = pool
        self.is_own = True
    def clear(self):
        if self._c_pool is not NULL:
            apr_pools.apr_pool_clear(self._c_pool)
    def destroy(self):
        # do not try to destroy the pool. this will cause segmentation fault.
        if self.is_own and self._c_pool is not NULL:
            apr_pools.apr_pool_destroy(self._c_pool)
        self._c_pool = NULL
        self.is_own = False
    cdef Apr_Pool set_pool(Apr_Pool self, apr_pools.apr_pool_t * _c_pool):
        self._c_pool = _c_pool
        return self
    cdef inline void * palloc(self, apr.apr_size_t size):
        return apr_pools.apr_palloc(self._c_pool, size)
    def __dealloc__(self):
        if self.is_own and self._c_pool is not NULL:
            apr_pools.apr_pool_destroy(self._c_pool)
            self._c_pool = NULL

cpdef Apr_Pool _root_pool
_root_pool = Apr_Pool()

# from "svn_error_codes.h"
SVN_NO_ERROR                   = svn_error_codes.SVN_NO_ERROR
SVN_ERR_FS_NOT_FOUND           = svn_error_codes.SVN_ERR_FS_NOT_FOUND
SVN_ERR_CLIENT_IS_BINARY_FILE  = svn_error_codes.SVN_ERR_CLIENT_IS_BINARY_FILE
IF SVN_API_VER >= (1, 5):
    SVN_ERR_CEASE_INVOCATION       = svn_error_codes.SVN_ERR_CEASE_INVOCATION
ELSE:
    SVN_ERR_CEASE_INVOCATION       = svn_error_codes.SVN_ERR_CANCELLED

# from "svn_types.h" representation of svn_error_t
cdef class Svn_error(object):
#    cdef svn_types.svn_error_t * _c_error
    def __cinit__(self, msg=None, stat=None):
        self._c_error = NULL
    def __init__(self, msg=None, stat=None):
        cdef apr_errno.apr_status_t ast
        cdef const char * _c_msg
        if stat:
            ast = stat
            if msg:
                str_msg = str(msg)
                _c_msg = str_msg
            else:
                _c_msg = NULL
            self._c_error = svn_error.svn_error_create(stat, NULL, _c_msg)
    cdef seterror(self, svn_types.svn_error_t * err):
        if self._c_error is NULL:
            self._c_error = err
        elif err is not NULL:
            svn_error.svn_error_compose(self._c_error, err)
        return self
    cdef svn_error.svn_error_t * geterror(self):
        return self._c_error
    def __str__(self):
        cdef object estr
        cdef svn_error.svn_error_t * eptr
        if self._c_error is NULL:
            estr = None
        else:
            eptr = self._c_error
            if eptr.message is not NULL:
                estr = eptr.message
            eptr = eptr.child
            while eptr is not NULL:
                if eptr.message is not NULL:
                    estr = estr + '\n' + eptr.message
                eptr = eptr.child
        return estr
    def __dealloc__(self):
        if self._c_error is not NULL:
            svn_error.svn_error_clear(self._c_error)

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
            return None
        else:
            return (<Svn_error>self.svnerr)._c_error.apr_err
    def get_code_list(self):
        cdef svn_error.svn_error_t * eptr
        eptr = (<Svn_error>self.svnerr)._c_error
        r = []
        while eptr is not NULL:
            r.append(eptr.apr_err)
            eptr = eptr.child
        return r

# from "svn_types.h"
SVN_INVALID_REVNUM = svn_types.SVN_INVALID_REVNUM
SVN_IGNORED_REVNUM = svn_types.SVN_IGNORED_REVNUM
SVN_STREAM_CHUNK_SIZE = svn_types.SVN_STREAM_CHUNK_SIZE

# from "svn_props.h"
IF PY_VERSION < (3, 0, 0):
    SVN_PROP_REVISION_LOG   = svn_props.SVN_PROP_REVISION_LOG
    SVN_PROP_REVISION_AUTOR = svn_props.SVN_PROP_REVISION_AUTHOR
    SVN_PROP_REVISION_DATE  = svn_props.SVN_PROP_REVISION_DATE
    SVN_PROP_EXECUTABLE     = svn_props.SVN_PROP_EXECUTABLE
    SVN_PROP_SPECIAL        = svn_props.SVN_PROP_SPECIAL
ELSE:
    SVN_PROP_REVISION_LOG   = (
            <bytes>(svn_props.SVN_PROP_REVISION_LOG)).decode('utf-8')
    SVN_PROP_REVISION_AUTOR = (
            <bytes>(svn_props.SVN_PROP_REVISION_AUTHOR)).decode('utf-8')
    SVN_PROP_REVISION_DATE  = (
            <bytes>(svn_props.SVN_PROP_REVISION_DATE)).decode('utf-8')
    SVN_PROP_EXECUTABLE     = (
            <bytes>(svn_props.SVN_PROP_EXECUTABLE)).decode('utf-8')
    SVN_PROP_SPECIAL        = (
            <bytes>(svn_props.SVN_PROP_SPECIAL)).decode('utf-8')

# from "svn_version.h"
SVN_VER_MAJOR = svn_version.SVN_VER_MAJOR
SVN_VER_MINOR = svn_version.SVN_VER_MINOR
SVN_VER_PATCH = svn_version.SVN_VER_PATCH

# from "svn_opt.h"
svn_opt_revision_unspecified = svn_opt.svn_opt_revision_unspecified
svn_opt_revision_number      = svn_opt.svn_opt_revision_number
svn_opt_revision_date        = svn_opt.svn_opt_revision_date
svn_opt_revision_committed   = svn_opt.svn_opt_revision_committed
svn_opt_revision_previous    = svn_opt.svn_opt_revision_previous
svn_opt_revision_base        = svn_opt.svn_opt_revision_base
svn_opt_revision_working     = svn_opt.svn_opt_revision_working
svn_opt_revision_head        = svn_opt.svn_opt_revision_head

cdef class svn_opt_revision_t(object):
# cdef svn_opt.svn_opt_revision_t _c_opt_revision
    def __cinit__(self, kind=svn_opt.svn_opt_revision_unspecified, value=0):
        self.set(kind, value)
    def set(self, kind, value=0):
        cdef svn_opt_revision_t ref
        if kind is None:
            self._c_opt_revision.kind = svn_opt.svn_opt_revision_unspecified
            self._c_opt_revision.value.number = 0
        elif isinstance(kind, svn_opt_revision_t):
            ref = kind
            self._c_opt_revision.kind  = ref._c_opt_revision.kind
            self._c_opt_revision.value.number = \
                    ref._c_opt_revision.value.number
        elif kind == svn_opt.svn_opt_revision_number:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.number = value
        elif kind == svn_opt.svn_opt_revision_date:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.date = value
        elif kind in [
                svn_opt.svn_opt_revision_unspecified,
                svn_opt.svn_opt_revision_committed,
                svn_opt.svn_opt_revision_previous,
                svn_opt.svn_opt_revision_base,
                svn_opt.svn_opt_revision_working,
                svn_opt.svn_opt_revision_head]:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.number = 0
        else:
            raise ValueError('unknown svn_opt_revision_kind: ' + str(kind))
        return self
    cdef svn_opt_revision_t _c_set(self, svn_opt.svn_opt_revision_t _c_rev):
        if _c_rev.kind == svn_opt.svn_opt_revision_number:
            self._c_opt_revision.kind = _c_rev.kind
            self._c_opt_revision.value.number = _c_rev.value.number
        elif _c_rev.kind == svn_opt.svn_opt_revision_date:
            self._c_opt_revision.kind = _c_rev.kind
            self._c_opt_revision.value.date = _c_rev.value.date
        elif _c_rev.kind in [
                svn_opt.svn_opt_revision_unspecified,
                svn_opt.svn_opt_revision_committed,
                svn_opt.svn_opt_revision_previous,
                svn_opt.svn_opt_revision_base,
                svn_opt.svn_opt_revision_working,
                svn_opt.svn_opt_revision_head]:
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
        if kind == svn_opt.svn_opt_revision_number:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.number = svn_types.SVN_INVALID_REVNUM
        elif kind == svn_opt.svn_opt_revision_date:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.date = 0
        elif kind in [
                svn_opt.svn_opt_revision_unspecified,
                svn_opt.svn_opt_revision_committed,
                svn_opt.svn_opt_revision_previous,
                svn_opt.svn_opt_revision_base,
                svn_opt.svn_opt_revision_working,
                svn_opt.svn_opt_revision_head]:
            self._c_opt_revision.kind = kind
            self._c_opt_revision.value.number = 0
        else:
            raise ValueError('unknown svn_opt_revision_kind: ' + str(kind))
    @property
    def value(self):
        if self._c_opt_revision.kind == svn_opt.svn_opt_revision_number:
            return self._c_opt_revision.value.number
        elif self._c_opt_revision.kind == svn_opt.svn_opt_revision_date:
            return self._c_opt_revision.value.date
        elif self._c_opt_revision.kind in [
                svn_opt.svn_opt_revision_unspecified,
                svn_opt.svn_opt_revision_committed,
                svn_opt.svn_opt_revision_previous,
                svn_opt.svn_opt_revision_base,
                svn_opt.svn_opt_revision_working,
                svn_opt.svn_opt_revision_head]:
            # Though value has no mean, return it
            return self._c_opt_revision.value.number
        else:
            # foolproof
            raise ValueError('unknown svn_opt_revision_kind "'
                             + str(self._c_opt_revision.kind)
                             + '" has set')
    @value.setter
    def value(self, value):
        if self._c_opt_revision.kind == svn_opt.svn_opt_revision_number:
            self._c_opt_revision.value.number = value
        elif self._c_opt_revision.kind == svn_opt.svn_opt_revision_date:
            self._c_opt_revision.value.date = value
        elif self._c_opt_revision.kind in [
                svn_opt.svn_opt_revision_unspecified,
                svn_opt.svn_opt_revision_committed,
                svn_opt.svn_opt_revision_previous,
                svn_opt.svn_opt_revision_base,
                svn_opt.svn_opt_revision_working,
                svn_opt.svn_opt_revision_head]:
            # Though value has no mean, set it
            self._c_opt_revision.value.number = value
        else:
            # foolproof
            raise ValueError('unknown svn_opt_revision_kind "'
                             + str(self._c_opt_revision.kind)
                             + '" has set')

def canonicalize_path(path):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_scratch_pool
    cdef const char * _c_rpath
    cdef object rpath
    cdef svn_error.svn_error_t * serr
    cdef Svn_error pyerr

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    assert isinstance(path, bytes)
    ast = apr_pools.apr_pool_create(&_c_scratch_pool, _root_pool._c_pool)
    if ast:
        raise MemoryError()
    try:
        IF SVN_API_VER >= (1, 7):
            if svn_path.svn_path_is_url(path):
                _c_rpath = svn_dirent_uri.svn_uri_canonicalize(
                                                path, _c_scratch_pool)
                rpath = _c_rpath
            else:
                _c_rpath = svn_dirent_uri.svn_dirent_canonicalize(
                                                path, _c_scratch_pool)
                rpath = _c_rpath
                assert os.path.isabs(rpath)
        ELSE:
            _c_rpath = svn_path.svn_path_canonicalize(path, _c_scratch_pool)
            rpath = _c_rpath
    finally:
        apr_pools.apr_pool_destroy(_c_scratch_pool)
    return rpath

def canonicalize_rootpath(path):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_scratch_pool
    cdef const char * _c_rootpath
    cdef object rootpath
    cdef svn_error.svn_error_t * serr
    cdef Svn_error pyerr

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    assert isinstance(path, bytes)
    ast = apr_pools.apr_pool_create(&_c_scratch_pool, _root_pool._c_pool)
    if ast:
        raise MemoryError()
    try:
        if svn_path.svn_path_is_url(path):
            IF SVN_API_VER >= (1, 7):
                _c_rootpath = svn_dirent_uri.svn_uri_canonicalize(
                                                path, _c_scratch_pool)
            ELSE:
                _c_rootpath = svn_path.svn_path_canonicalize(
                                                path, _c_scratch_pool)
            rootpath = _c_rootpath
            if rootpath.lower().startswith(b'file:'):
                IF SVN_API_VER >= (1, 7):
                    serr = svn_dirent_uri.svn_uri_get_dirent_from_file_url(
                                &_c_rootpath, _c_rootpath, _c_scratch_pool)
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
                        assert rootpath.lower.startswith(b'file:///')
                        rootpath = os.path.normpath(
                                        urllib.unquote(rootpath[7:]))
                assert os.path.isabs(rootpath)
        else:
            IF SVN_API_VER >= (1, 6):
                _c_rootpath = svn_dirent_uri.svn_dirent_canonicalize(
                                                path, _c_scratch_pool)
            ELSE:
                _c_rootpath = svn_path.svn_path_canonicalize(
                                                path, _c_scratch_pool)
            rootpath = _c_rootpath
            assert os.path.isabs(rootpath)
    finally:
        apr_pools.apr_pool_destroy(_c_scratch_pool)
    return rootpath

# called from svn_repos module
def rootpath2url(rootpath, path):
    cdef bytes fullpath
    cdef const char * _c_dirent
    cdef bytes dirent
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef const char * _c_url
    cdef object url
    cdef svn_error.svn_error_t * serr
    cdef Svn_error pyerr

    rootpath = os.path.abspath(rootpath)
    fullpath = canonicalize_path(os.path.join(rootpath, path))
    ast = apr_pools.apr_pool_create(&_c_tmp_pool, _root_pool._c_pool)
    if ast:
        raise MemoryError()
    try:
        IF SVN_API_VER >= (1, 7):
            _c_dirent = fullpath
            serr = svn_dirent_uri.svn_uri_get_file_url_from_dirent(
                                &_c_url, _c_dirent, _c_tmp_pool)
            if serr is not NULL:
                pyerr = Svn_error().seterror(serr)
                raise SVNerr(pyerr)
            url = _c_url
        ELSE:
            # implement what svn_uri_get_file_url_from_dirent has done
            # from subversion/libsvn_subr/dirent.c (from subversion 1.10)
            _c_dirent = svn_path.svn_path_uri_encode(fullpath, _c_tmp_pool)
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
        apr_pools.apr_pool_destroy(_c_tmp_pool)
    return url

# called from svn_repos module
def datestr_to_date(datestr):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_scratch_pool
    cdef svn_error.svn_error_t * serr
    cdef Svn_error pyerr
    cdef apr_time.apr_time_t _c_when

    ast = apr_pools.apr_pool_create(&_c_scratch_pool, _root_pool._c_pool)
    if ast:
        raise MemoryError()
    try:
        serr = svn_time.svn_time_from_cstring(
                        &_c_when, datestr, _c_scratch_pool)
        if serr is not NULL:
            svn_error.svn_error_clear(serr)
            when = None
        else:
            when = _c_when
            when = when / 1000000
    finally:
        apr_pools.apr_pool_destroy(_c_scratch_pool)
    return when

# from "svn_types.h"
cdef class svn_stream_t(object):
    # cdef svn_io.svn_stream_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
    cdef set_stream(self, svn_io.svn_stream_t * stream):
        self._c_ptr = stream
    def close(self):
        cdef svn_error.svn_error_t * serr
        cdef Svn_error pyerr
        if self._c_ptr is not NULL:
            serr = svn_io.svn_stream_close(self._c_ptr)
            if serr is not NULL:
                pyerr = Svn_error().seterror(serr)
                raise SVNerr(pyerr)

cdef char _streambuf[svn_types.SVN_STREAM_CHUNK_SIZE]

def svn_stream_read(svn_stream_t stream, len):
    cdef apr.apr_size_t _c_len
    cdef char * _c_buf
    cdef svn_error.svn_error_t * serr
    cdef Svn_error pyerr
    # Note: this function read stream as bytes stream without decode
    assert len > 0
    assert stream._c_ptr is not NULL
    if len > svn_types.SVN_STREAM_CHUNK_SIZE:
        _c_buf = <char *>PyMem_Malloc(len)
    else:
        _c_buf = _streambuf
    _c_len = len
    IF SVN_API_VER >= (1, 9):
        serr = svn_io.svn_stream_read2(stream._c_ptr, _c_buf, &_c_len)
    ELSE:
        serr = svn_io.svn_stream_read(stream._c_ptr, _c_buf, &_c_len)
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
    return buf

def svn_stream_close(svn_stream_t stream):
    stream.close()

def svn_stream_readline(svn_stream_t stream, const char *eol, pool=None):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_scratch_pool
    cdef svn_error.svn_error_t * serr
    cdef Svn_error pyerr
    cdef svn_string.svn_stringbuf_t * _c_stringbuf
    cdef svn_types.svn_boolean_t _c_eof
    cdef object bufstr
    cdef object eof

    assert stream._c_ptr is not NULL
    if pool is not None:
        assert (    isinstance(pool, Apr_Pool)
                and (<Apr_Pool>pool)._c_pool is not NULL)
        ast = apr_pools.apr_pool_create(&_c_scratch_pool,
                                       (<Apr_Pool>pool)._c_pool)
    else:
        ast = apr_pools.apr_pool_create(&_c_scratch_pool, _root_pool._c_pool)
    if ast:
        raise MemoryError()
    try:
        serr = svn_io.svn_stream_readline(stream._c_ptr, &_c_stringbuf,
                                            eol, &_c_eof, _c_scratch_pool)
        if serr is not NULL:
            pyerr = Svn_error().seterror(serr)
            raise SVNerr(pyerr)
        bufstr = _c_stringbuf.data[0:_c_stringbuf.len]
        eof = True if _c_eof else False
    finally:
        apr_pools.apr_pool_destroy(_c_scratch_pool)
    return bufstr, eof

# baton wrapper ... call back function helper
cdef class CbContainer(object):
    def __cinit__(self, fnobj, btn, pool=None):
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

cdef class HashTrans(TransPtr):
    def __cinit__(self, **m):
        self._c_tmp_pool = NULL
        self._c_hash = NULL
    def __init__(
            self, TransPtr key_trans, TransPtr val_trans,
            scratch_pool=None, **m):
        cdef apr_errno.apr_status_t ast
        self.key_trans = key_trans
        self.val_trans = val_trans
        if scratch_pool is not None:
            assert (     isinstance(scratch_pool, Apr_Pool)
                     and  (<Apr_Pool>scratch_pool)._c_pool is not NULL)
            ast = apr_pools.apr_pool_create(
                            &(self._c_tmp_pool),
                            (<Apr_Pool>scratch_pool)._c_pool)
        else:
            ast = apr_pools.apr_pool_create(
                            &(self._c_tmp_pool), _root_pool._c_pool)
        if ast:
            raise PoolError()
    def __dealloc__(self):
        if self._c_tmp_pool is not NULL:
            apr_pools.apr_pool_destroy(self._c_tmp_pool)
            self._c_tmp_pool = NULL
    cdef object to_object(self):
        cdef apr_hash.apr_hash_index_t * hi
        cdef const void * _c_key
        cdef apr.apr_ssize_t _c_klen
        cdef void * _c_val

        apr_pools.apr_pool_clear(self._c_tmp_pool)
        hi = apr_hash.apr_hash_first(
                    self._c_tmp_pool, self._c_hash)
        rdict = {}
        while hi is not NULL:
            apr_hash.apr_hash_this(hi,
                                   <const void **>(self.key_trans.ptr_ref()),
                                   &_c_klen,
                                   <void **>self.val_trans.ptr_ref())
            rdict[self.key_trans.to_object()] = self.val_trans.to_object()
            hi = apr_hash.apr_hash_next(hi)
        return rdict
    cdef void set_ptr(self, void *_c_ptr):
        self._c_hash = <apr_hash.apr_hash_t *>_c_ptr
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_hash)

cdef object hash_to_dict(apr_hash.apr_hash_t * _c_hash,
                         ptr_to_pyobj_func_t key_func,
                         ptr_to_pyobj_func_t val_func,
                         apr_pools.apr_pool_t * _c_scratch_pool):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef apr_hash.apr_hash_index_t * hi
    cdef const void * _c_key
    cdef apr.apr_ssize_t _c_klen
    cdef void * _c_val

    if _c_scratch_pool is NULL:
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, _root_pool._c_pool)
    else:
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, _c_scratch_pool)
    if ast:
        raise PoolError()
    try:
        hi = apr_hash.apr_hash_first(_c_tmp_pool, _c_hash)
        rdict = {}
        while hi is not NULL:
            apr_hash.apr_hash_this(hi, &_c_key, &_c_klen, &_c_val)
            rdict[key_func(<void *>_c_key, _c_tmp_pool)] = \
                    val_func(_c_val, _c_tmp_pool)
            hi = apr_hash.apr_hash_next(hi)
    finally:
        apr_pools.apr_pool_destroy(_c_tmp_pool)
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
    CStringTransStr = CStringTransBytes
    # cdef object (*_c_string_to_str)(
    #                     void *_c_ptr, apr_pools.apr_pool_t *_c_scratch_pool)

cdef class SvnStringTransBytes(TransPtr):
    def __cinit__(self):
        self._c_svn_str = NULL
    cdef object to_object(self):
        cdef object pybytes
        pybytes = self._c_svn_str[0].data[:self._c_svn_str[0].len]
        return pybytes
    cdef void set_ptr(self, void *_c_ptr):
        self._c_svn_str = <svn_string.svn_string_t *>_c_ptr
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
            self._c_svn_str = <svn_string.svn_string_t *>_c_ptr
        cdef void ** ptr_ref(self):
            return <void **>&(self._c_svn_str)

ELSE:
    SvnStringTransStr = SvnStringTransBytes
    # cdef object (*_svn_string_to_str)(
    #                     void *_c_ptr, apr_pools.apr_pool_t *_c_scratch_pool)

cdef class SvnBooleanTrans(TransPtr):
    cdef object to_object(self):
        if self._c_bool != svn_types.FALSE:
            return True
        return False
    cdef void set_c_bool(self, svn_types.svn_boolean_t _c_bool):
        self._c_bool = _c_bool
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_bool)

# for test, not used by vclib modules
IF SVN_API_VER >= (1, 4):
    def svn_stream_open_readonly(
            const char * path, result_pool=None, scratch_pool=None):
        cdef apr_errno.apr_status_t ast
        cdef apr_pools.apr_pool_t * _c_tmp_pool
        cdef apr_pools.apr_pool_t * _c_result_pool
        cdef svn_io.svn_stream_t * _c_stream
        cdef svn_error.svn_error_t * serr
        cdef Svn_error pyerr
        IF SVN_API_VER < (1, 6):
            cdef apr_file_io.apr_file_t * _c_file

        if result_pool is not None:
            assert (    isinstance(result_pool, Apr_Pool)
                    and (<Apr_Pool>result_pool)._c_pool is not NULL)
            _c_result_pool = (<Apr_Pool>result_pool)._c_pool
        else:
            _c_result_pool = _root_pool._c_pool
        if scratch_pool is not None:
            assert (    isinstance(scratch_pool, Apr_Pool)
                    and (<Apr_Pool>scratch_pool)._c_pool is not NULL)
            ast = apr_pools.apr_pool_create(&_c_tmp_pool,
                                           (<Apr_Pool>scratch_pool)._c_pool)
        else:
            ast = apr_pools.apr_pool_create(&_c_tmp_pool, _root_pool._c_pool)
        if ast:
            raise MemoryError()
        try:
            IF SVN_API_VER >= (1, 6):
                serr = svn_io.svn_stream_open_readonly(
                                &_c_stream, path, _c_result_pool, _c_tmp_pool)
                if serr is not NULL:
                    pyerr = Svn_error().seterror(serr)
                    raise SVNerr(pyerr)
            ELSE:
                serr = svn_io.svn_io_file_open(
                            &_c_file, path,
                            apr_file_io.APR_READ | apr_file_io.APR_BUFFERED,
                            apr_file_io.APR_OS_DEFAULT, _c_result_pool)
                if serr is not NULL:
                    pyerr = Svn_error().seterror(serr)
                    raise SVNerr(pyerr)
                _c_stream = svn_io.svn_stream_from_aprfile2(
                                    _c_file, svn_types.FALSE, _c_result_pool)
            stream = svn_stream_t()
            stream.set_stream(_c_stream)
        finally:
            apr_pools.apr_pool_destroy(_c_tmp_pool)
        return stream
