include "_py_ver.pxi"
include "_svn_api_ver.pxi"
from apr_1 cimport apr
from apr_1 cimport apr_errno
from apr_1 cimport apr_general
from apr_1 cimport apr_pools
from apr_1 cimport apr_hash
from subversion_1 cimport svn_types
from subversion_1 cimport svn_error
from subversion_1 cimport svn_error_codes
from subversion_1 cimport svn_opt
from subversion_1 cimport svn_string
from subversion_1 cimport svn_io

cdef class Apr_Pool(object):
    cdef apr_pools.apr_pool_t* _c_pool
    cdef svn_types.svn_boolean_t is_own
    cdef readonly Apr_Pool _parent_pool
    cdef Apr_Pool set_pool(Apr_Pool self, apr_pools.apr_pool_t * _c_pool)
    cdef inline void * palloc(self, apr.apr_size_t size)

cpdef Apr_Pool _root_pool
cpdef Apr_Pool _scratch_pool

cdef class Svn_error(object):
    cdef svn_types.svn_error_t * _c_error
    cdef object bytes_msg
    cdef seterror(self, svn_types.svn_error_t * err)
    cdef svn_types.svn_error_t * geterror(self)

cdef class svn_opt_revision_t(object):
    cdef svn_opt.svn_opt_revision_t _c_opt_revision
    cdef svn_opt_revision_t _c_set(self, svn_opt.svn_opt_revision_t _c_rev)

cdef class svn_stream_t(object):
    cdef svn_io.svn_stream_t * _c_ptr
    cdef Apr_Pool pool
    cdef svn_stream_t set_stream(
            svn_stream_t self, svn_io.svn_stream_t * stream, object pool)

cdef class CbContainer(object):
    cdef object fnobj
    cdef object btn
    cdef object pool

cdef class TransPtr(object):
    cdef object to_object(self)
    cdef void * from_object(self, object obj)
    cdef void set_ptr(self, void *_c_ptr)
    cdef void ** ptr_ref(self)

cdef class HashTrans(TransPtr):
    cdef apr_hash.apr_hash_t * _c_hash
    cdef TransPtr key_trans
    cdef TransPtr val_trans
    cdef Apr_Pool tmp_pool
    cdef object to_object(self)
    cdef void * from_object(self, object obj)
    cdef void set_ptr(self, void *_c_ptr)
    cdef void ** ptr_ref(self)

ctypedef object (*ptr_to_pyobj_func_t)(void *_c_ptr,
                                       apr_pools.apr_pool_t * _c_scratch_pool)

cdef object hash_to_dict(apr_hash.apr_hash_t * _c_hash,
                       ptr_to_pyobj_func_t key_func,
                       ptr_to_pyobj_func_t val_func,
                       apr_pools.apr_pool_t * _c_scratch_pool)

cdef class CStringTransBytes(TransPtr):
    cdef char * _c_str
    cdef object to_object(self)
    cdef void set_ptr(self, void *_c_ptr)
    cdef void ** ptr_ref(self)

IF PY_VERSION >= (3, 0, 0):
    cdef class CStringTransStr(TransPtr):
        cdef char * _c_str
        cdef object to_object(self)
        cdef void set_ptr(self, void *_c_ptr)
        cdef void ** ptr_ref(self)
ELSE:
    cdef class CStringTransStr(CStringTransBytes):
        pass

cdef class SvnStringTransBytes(TransPtr):
    cdef svn_string.svn_string_t * _c_svn_str
    cdef object to_object(self)
    cdef void set_ptr(self, void *_c_ptr)
    cdef void ** ptr_ref(self)

IF PY_VERSION >= (3, 0, 0):
    cdef class SvnStringTransStr(TransPtr):
        cdef svn_string.svn_string_t * _c_svn_str
        cdef object to_object(self)
        cdef void set_ptr(self, void *_c_ptr)
        cdef void ** ptr_ref(self)
ELSE:
    cdef class SvnStringTransStr(SvnStringTransBytes):
        pass

cdef class SvnBooleanTrans(TransPtr):
    cdef svn_types.svn_boolean_t _c_bool
    cdef object to_object(self)
    cdef void set_c_bool(self, svn_types.svn_boolean_t _c_bool)
    cdef void ** ptr_ref(self)


cdef class _py_stream_baton(object):
    cdef object baton
    cdef object read_fn
    IF SVN_API_VER >= (1, 9):
        cdef object read_full_fn
    IF SVN_API_VER >= (1, 7):
        cdef object skip_fn
    cdef object write_fn
    cdef object close_fn
    IF SVN_API_VER >= (1, 7):
        cdef object mark_fn
        cdef object seek_fn
    IF SVN_API_VER >= (1, 9):
        cdef object data_available_fn
    IF SVN_API_VER >= (1, 10):
        cdef object readline_fn
    IF SVN_API_VER >= (1.7):
        # placeholder to hold marks for mark/seek operation
        # we can use Python object allocation, so we use
        # svn_stream_mark_t as integer key of marks, and hold actual mark
        # as value of marks dict.
        cdef dict marks
        # next_mark == len(marks)+1
        cdef int next_mark

cdef class CharPtrWriteBuffer:
    cdef char * _c_buf
    cdef Py_ssize_t len
    cdef Py_ssize_t shape[1]
    cdef Py_ssize_t strides[1]
    cdef CharPtrWriteBuffer set_buffer(
            CharPtrWriteBuffer self, char * _c_buf, Py_ssize_t len)

cdef class CharPtrReadBuffer:
    cdef const char * _c_buf
    cdef Py_ssize_t len
    cdef Py_ssize_t shape[1]
    cdef Py_ssize_t strides[1]
    cdef CharPtrReadBuffer set_buffer(
            CharPtrReadBuffer self, const char * _c_buf, Py_ssize_t len)

cdef class py_stream(svn_stream_t):
    cdef _py_stream_baton baton
