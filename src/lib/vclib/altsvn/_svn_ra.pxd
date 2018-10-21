include "_svn_api_ver.pxi"
cimport _svn_ra_capi as _c_
cimport _svn

cdef class svn_ra_session_t(object):
    cdef _c_.svn_ra_session_t * _c_session
    cdef _svn.Apr_Pool pool
    cdef svn_ra_session_t set_session(
            self, _c_.svn_ra_session_t * _c_session, pool)

IF SVN_API_VER >= (1, 6):
    cdef class py_svn_log_changed_path2_ref(object):
        cdef public object action
        cdef public object copyfrom_path
        cdef public object copyfrom_rev
        cdef public object node_kind
        IF SVN_API_VER >= (1, 7):
            cdef public object text_modified
            cdef public object props_modified
        cdef py_svn_log_changed_path2_ref bind(
                py_svn_log_changed_path2_ref self,
                _c_.svn_log_changed_path2_t * _c_ptr)

cdef class py_svn_log_changed_path_ref(object):
    cdef public object action
    cdef public object copyfrom_path
    cdef public object copyfrom_rev
    cdef py_svn_log_changed_path_ref bind(
            py_svn_log_changed_path_ref self,
            _c_.svn_log_changed_path_t * _c_ptr)

cdef class py_svn_log_entry(object):
    cdef public object changed_paths
    cdef public object revision
    cdef public object revprops
    IF SVN_API_VER >= (1, 5):
        cdef public object has_children
    IF SVN_API_VER >= (1, 6):
        cdef public object changed_paths2
    IF SVN_API_VER >= (1, 7):
        cdef public object non_inheritable
        cdef public object subtractive_merge
    IF SVN_API_VER >= (1, 5):
        cdef void bind(self, const _c_.svn_log_entry_t *_c_ptr,
                _svn.Apr_Pool scratch_pool)
    ELSE:
        cdef void bind(
                self, const _c_.apr_hash_t *_c_changed_paths,
                _c_.svn_revision_t _c_revision, const char * author,
                const char * date, const char * message,
                _svn.Apr_Pool scratch_pool)
