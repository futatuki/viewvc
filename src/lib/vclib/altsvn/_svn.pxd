include "_py_ver.pxi"
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
    cdef object is_own
    cdef readonly Apr_Pool _parent_pool
    cdef Apr_Pool set_pool(Apr_Pool self, apr_pools.apr_pool_t * _c_pool)
    cdef inline void * palloc(self, apr.apr_size_t size)

cdef Apr_Pool _root_pool

cdef class Svn_error(object):
    cdef svn_types.svn_error_t * _c_error
    cdef object str_msg
    cdef seterror(self, svn_types.svn_error_t * err)
    cdef svn_types.svn_error_t * geterror(self)

cdef class svn_opt_revision_t(object):
    cdef svn_opt.svn_opt_revision_t _c_opt_revision
    cdef svn_opt_revision_t _c_set(self, svn_opt.svn_opt_revision_t _c_rev)

cdef class svn_stream_t(object):
    cdef svn_io.svn_stream_t * _c_ptr
    cdef set_stream(self, svn_io.svn_stream_t * stream)

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
    cdef apr_hash.apr_pool_t * _c_tmp_pool
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

