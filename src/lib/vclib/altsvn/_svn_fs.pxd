include "_svn_api_ver.pxi"
from apr_1 cimport apr_pools 
from subversion_1 cimport svn_types
from subversion_1 cimport svn_fs
cimport _svn

cdef class svn_fs_t(object):
    cdef svn_fs.svn_fs_t * _c_ptr
    cdef dict roots
    cdef _svn.Apr_Pool pool
    cdef set_fs(self, svn_fs.svn_fs_t * fs)

cdef class svn_fs_root_t(object):
    cdef svn_fs.svn_fs_root_t * _c_ptr
    cdef object _pool
    cdef set_fs_root(self, svn_fs.svn_fs_root_t * fs_root)

cdef class svn_fs_id_t(object):
    cdef svn_fs.svn_fs_id_t * _c_ptr
    cdef set_fs_id(self, svn_fs.svn_fs_id_t * fs_id)

cdef class svn_fs_history_t(object):
    cdef svn_fs.svn_fs_history_t * _c_ptr
    cdef set_history(self, svn_fs.svn_fs_history_t * history)

ctypedef svn_types.svn_error_t * (*svn_rv1_root_path_func_t)(
                void **_c_r_ptr, svn_fs.svn_fs_root_t *_c_root,
                const char *_c_path, apr_pools.apr_pool_t * _c_pool) nogil

IF SVN_API_VER < (1, 10):
    cdef class FsPathChangeTrans(_svn.TransPtr):
        IF SVN_API_VER >= (1, 6):
            cdef svn_fs.svn_fs_path_change2_t * _c_change
        ELSE:
            cdef svn_fs.svn_fs_path_change_t * _c_change
        cdef apr_pools.apr_pool_t * _c_tmp_pool
        cdef object to_object(self)
        IF SVN_API_VER >= (1, 6):
            cdef void set_c_change(
                        self, svn_fs.svn_fs_path_change2_t * _c_change)
        ELSE:
            cdef void set_c_change(
                        self, svn_fs.svn_fs_path_change_t * _c_change)
        cdef void ** ptr_ref(self)

cdef class NodeKindTrans(_svn.TransPtr): 
    cdef svn_types.svn_node_kind_t _c_kind
    cdef object to_object(self)
    cdef void set_c_kind(self, svn_types.svn_node_kind_t _c_kind)
    cdef void ** ptr_ref(self)
    
cdef class DirEntryTrans(_svn.TransPtr):
    cdef svn_fs.svn_fs_dirent_t *_c_dirent
    cdef object to_object(self)
    cdef void set_c_dirent(self, svn_fs.svn_fs_dirent_t *_c_dirent)
    cdef void ** ptr_ref(self)

cdef class FileSizeTrans(_svn.TransPtr):
    cdef svn_types.svn_filesize_t _c_fsize
    cdef object to_object(self)
    cdef void set_filesize(self, svn_types.svn_filesize_t _c_fsize)
    cdef void ** ptr_ref(self)
