include "_py_ver.pxi"
include "_svn_api_ver.pxi"
from cpython.ref cimport PyObject
cimport _svn_repos_capi as _c_
cimport _svn

cdef class svn_fs_t(object):
    cdef _c_.svn_fs_t * _c_ptr
    cdef dict roots
    cdef _svn.Apr_Pool pool
    cdef set_fs(self, _c_.svn_fs_t * fs, object pool)

cdef class svn_fs_root_t(object):
    cdef _c_.svn_fs_root_t * _c_ptr
    cdef _svn.Apr_Pool pool
    cdef set_fs_root(self, _c_.svn_fs_root_t * fs_root, object pool)

cdef class svn_fs_id_t(object):
    cdef _c_.svn_fs_id_t * _c_ptr
    cdef _svn.Apr_Pool pool
    cdef set_fs_id(self, _c_.svn_fs_id_t * fs_id, object pool)

cdef class svn_fs_history_t(object):
    cdef _c_.svn_fs_history_t * _c_ptr
    cdef _svn.Apr_Pool pool
    cdef set_history(self, _c_.svn_fs_history_t * history, object pool)

ctypedef _c_.svn_error_t * (* svn_rv1_root_path_func_t)(
                void ** _c_r_ptr, _c_.svn_fs_root_t *_c_root,
                const char *_c_path, _c_.apr_pool_t * _c_pool) nogil

IF SVN_API_VER < (1, 10):
    cdef class FsPathChangeTrans(_svn.TransPtr):
        IF SVN_API_VER >= (1, 6):
            cdef _c_.svn_fs_path_change2_t * _c_change
        ELSE:
            cdef _c_.svn_fs_path_change_t * _c_change
            cdef _svn.Apr_Pool result_pool
        cdef _svn.Apr_Pool tmp_pool
        cdef object to_object(self)
        IF SVN_API_VER >= (1, 6):
            cdef void set_c_change(
                    self, _c_.svn_fs_path_change2_t * _c_change,
                    object result_pool)
        ELSE:
            cdef void set_c_change(
                    self, _c_.svn_fs_path_change_t * _c_change,
                    object result_pool)
        cdef void ** ptr_ref(self)

cdef class NodeKindTrans(_svn.TransPtr): 
    cdef _c_.svn_node_kind_t _c_kind
    cdef object to_object(self)
    cdef void set_c_kind(self, _c_.svn_node_kind_t _c_kind)
    cdef void ** ptr_ref(self)
    
cdef class FileSizeTrans(_svn.TransPtr):
    cdef _c_.svn_filesize_t _c_fsize
    cdef object to_object(self)
    cdef void set_filesize(self, _c_.svn_filesize_t _c_fsize)
    cdef void ** ptr_ref(self)

cdef class svn_repos_t(object):
    cdef _c_.svn_repos_t * _c_ptr
    cdef _svn.Apr_Pool pool
    cdef svn_repos_t set_repos(
            svn_repos_t self, _c_.svn_repos_t * repos, object pool)

cdef class SvnLock(object):
    cdef public object path
    cdef public object token
    cdef public object owner
    cdef public object comment
    cdef public object is_dav_comment
    cdef public _c_.apr_time_t creation_date
    cdef public _c_.apr_time_t expiration_date

cdef object _svn_lock_to_object(const _c_.svn_lock_t * _c_lock)

cdef class _ChangedPath(object):
    cdef public _c_.svn_node_kind_t item_kind
    cdef public _c_.svn_boolean_t prop_changes
    cdef public _c_.svn_boolean_t text_changed
    IF PY_VERSION >= (3, 0, 0):
        cdef public str base_path
    ELSE:
        cdef public bytes base_path
    cdef public _c_.svn_revnum_t base_rev
    IF PY_VERSION >= (3, 0, 0):
        cdef public str path
    ELSE:
        cdef public bytes path
    cdef public _c_.svn_boolean_t added
    ### we don't use 'None' action
    cdef public _c_.svn_fs_path_change_kind_t action

cdef class _get_changed_paths_EditBaton(object):
    cdef dict changes
    cdef svn_fs_t fs_ptr
    cdef svn_fs_root_t root
    cdef _c_.svn_revnum_t base_rev
    # pool for path in _get_changed_paths_DirBaton
    cdef _c_.apr_pool_t * _c_p_pool

ctypedef struct _get_changed_paths_DirBaton:
    const char * path
    const char * base_path
    _c_.svn_revnum_t base_rev
    void * edit_baton
