include "_svn_api_ver.pxi"
include "_py_ver.pxi"
cimport _svn_repos_capi as _c_
cimport _svn
from . import _svn

cdef class svn_fs_t(object):
    # cdef _c_.svn_fs_t * _c_ptr
    # cdef dict roots
    # cdef _svn.Apr_Pool pool
    def __cinit__(self, **m):
        self._c_ptr = NULL
        self.roots = {}
    def __init__(self, pool=None, **m):
        if pool is not None: 
            self.pool = _svn.Apr_pool(pool)
        else:
            self.pool = _svn.Apr_pool(_svn._root_pool)
    cdef set_fs(self, _c_.svn_fs_t * fs):
        self._c_ptr = fs
        self.roots = {}
        return self
    def _get_root(self, rev):
        try:
            return self.roots[rev]
        except KeyError:
            pass
        root = self.roots[rev] = svn_fs_revision_root(self, rev, self.pool)
        return root

cdef class svn_fs_root_t(object):
    # cdef _c_.svn_fs_root_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
        self._pool = None
    cdef set_fs_root(self, _c_.svn_fs_root_t * fs_root):
        self._c_ptr = fs_root
        return self
    def __dealloc__(self):
        if self._c_ptr is not NULL:
            _c_.svn_fs_close_root(self._c_ptr)
            self._c_ptr = NULL
            self._pool = None

cdef class svn_fs_id_t(object):
    # cdef _c_.svn_fs_id_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
    cdef set_fs_id(self, _c_.svn_fs_id_t * fs_id):
        self._c_ptr = fs_id
        return self

def svn_fs_compare_ids(svn_fs_id_t a, svn_fs_id_t b):
    return _c_.svn_fs_compare_ids(a._c_ptr, b._c_ptr)


# warn: though pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until 
# the program terminates. 
def svn_fs_revision_root(svn_fs_t fs, _c_.svn_revnum_t rev, pool=None):
    cdef _svn.Apr_Pool result_pool 
    cdef _c_.svn_fs_root_t * _c_root
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if pool is not None:
        assert (    isinstance(pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>pool)._c_pool is not NULL)
        result_pool = pool
    else:
        result_pool = _svn._root_pool
    serr = _c_.svn_fs_revision_root(
                            &_c_root, fs._c_ptr, rev, result_pool._c_pool) 
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    root = svn_fs_root_t().set_fs_root(_c_root)
    root.pool = result_pool
    return root

cdef object _apply_svn_api_root_path_arg1(
        svn_rv1_root_path_func_t svn_api, _svn.TransPtr rv_trans,
        svn_fs_root_t root, const char * path, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = svn_api(rv_trans.ptr_ref(), root._c_ptr, path, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        rv = rv_trans.to_object()
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return rv

# export svn C API constants into Python object
svn_fs_path_change_modify  = _c_.svn_fs_path_change_modify
svn_fs_path_change_add     = _c_.svn_fs_path_change_add
svn_fs_path_change_delete  = _c_.svn_fs_path_change_delete
svn_fs_path_change_replace = _c_.svn_fs_path_change_replace
svn_fs_path_change_reset   = _c_.svn_fs_path_change_reset

# This class is a placeholder of contents of svn_fs_path_change_t,
# svn_fs_path_change2_t, svn_fs_path_change3_t enough to the extent
# to use from svn_repos.py[x], but not provide full function.
class FsPathChange(object):
    IF SVN_API_VER >= (1, 10):
        # svn_fs_path_change3_t
        def __init__(self, change_kind, node_kind, text_mod, prop_mod,
                     mergeinfo_mod, copyfrom_known, copyfrom_path):
            self.change_kind = change_kind
            self.node_kind = node_kind
            self.text_mod = text_mod
            self.prop_mod = prop_mod
            self.mergeinfo_mod = mergeinfo_mod
            self.copyfrom_known = copyfrom_known
            self.copyfrom_path = copyfrom_path
    ELIF SVN_API_VER >= (1, 9):
        # svn_fs_path_change2_t
        def __init__(self, node_rev_id, change_kind, text_mod, prop_mod,
                     node_kind, copyfrom_known, copyfrom_rev, copyfrom_path,
                     mergeinfo_mod = _c_.svn_tristate_unknown):
            self.node_rev_id = node_rev_id
            self.change_kind = change_kind
            self.text_mod = text_mod
            self.prop_mod = prop_mod
            self.node_kind = node_kind
            self.copyfrom_known = copyfrom_known
            self.copyfrom_rev = copyfrom_rev
            self.copyfrom_path = copyfrom_path
            self.mergeinfo_mod = mergeinfo_mod
    ELIF SVN_API_VER >= (1, 6):
        def __init__(self, node_rev_id, change_kind, text_mod, prop_mod,
                     node_kind, copyfrom_known, copyfrom_rev, copyfrom_path):
            self.node_rev_id = node_rev_id
            self.change_kind = change_kind
            self.text_mod = text_mod
            self.prop_mod = prop_mod
            self.node_kind = node_kind
            self.copyfrom_known = copyfrom_known
            self.copyfrom_rev = copyfrom_rev
            self.copyfrom_path = copyfrom_path
    ELSE:
        def __init__(self, node_rev_id, change_kind, text_mod, prop_mod):
            self.node_rev_id = node_rev_id
            self.change_kind = change_kind
            self.text_mod = text_mod
            self.prop_mod = prop_mod

IF SVN_API_VER < (1, 10):
    cdef class FsPathChangeTrans(_svn.TransPtr):
        def __cinit__(self, **m):
            self._c_tmp_pool = NULL
        def __init__(self, scratch_pool=None, **m):
            cdef _c_.apr_status_t ast
            if scratch_pool is not None:
                assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
                ast = _c_.apr_pool_create(
                                &(self._c_tmp_pool),
                                (<_svn.Apr_Pool>scratch_pool)._c_pool)
            else:
                ast = _c_.apr_pool_create(
                                &(self._c_tmp_pool), _svn._root_pool._c_pool)
            if ast:
                raise _svn.PoolError()
        def __dealloc__(self):
            if self._c_tmp_pool is not NULL:
                _c_.apr_pool_destroy(self._c_tmp_pool)
                self._c_tmp_pool = NULL
        cdef object to_object(self):
            IF SVN_API_VER == (1, 9):
                return FsPathChange(
                        svn_fs_id_t().set_fs_id(
                                <_c_.svn_fs_id_t *>
                                ((self._c_change)[0].node_rev_id)),
                        (self._c_change)[0].change_kind,
                        (self._c_change)[0].text_mod,
                        (self._c_change)[0].prop_mod,
                        (self._c_change)[0].node_kind,
                        (self._c_change)[0].copyfrom_known,
                        (self._c_change)[0].copyfrom_rev,
                        (self._c_change)[0].copyfrom_path,
                        (self._c_change)[0].mergeinfo_mod)
            ELIF SVN_API_VER >= (1, 6):
                return FsPathChange(
                        svn_fs_id_t().set_fs_id(
                                <_c_.svn_fs_id_t *>
                                ((self._c_change)[0].node_rev_id)),
                        (self._c_change)[0].change_kind,
                        (self._c_change)[0].text_mod,
                        (self._c_change)[0].prop_mod,
                        (self._c_change)[0].node_kind,
                        (self._c_change)[0].copyfrom_known,
                        (self._c_change)[0].copyfrom_rev,
                        (self._c_change)[0].copyfrom_path)
            ELSE:
                return FsPathChange(
                        svn_fs_id_t().set_fs_id(
                                <_c_.svn_fs_id_t *>
                                ((self._c_change)[0].node_rev_id)),
                        (self._c_change)[0].change_kind,
                        (self._c_change)[0].text_mod,
                        (self._c_change)[0].prop_mod)
        IF SVN_API_VER >= (1, 6):
            cdef void set_c_change(
                    self, _c_.svn_fs_path_change2_t * _c_change):
                self._c_change = _c_change
        ELSE:
            cdef void set_c_change(
                    self, _c_.svn_fs_path_change_t * _c_change):
                self._c_change = _c_change
        cdef void ** ptr_ref(self):
            return <void **>&(self._c_change)

# warn: this function doesn't provide full functionally
# (not return apr_hash object but dict, and its contents is neither
#  svn_fs_path_change2_t nor svn_fs_path_change_t object but python
#  object, which cannot be used for arguments for other svn wrapper APIs
#  directly)
def svn_fs_paths_changed(svn_fs_root_t root, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    IF SVN_API_VER >= (1, 10):
        cdef _c_.svn_fs_path_change_iterator_t * _c_iterator
        cdef _c_.svn_fs_path_change3_t * _c_change
    ELSE:
        cdef _svn.HashTrans pt_trans

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                    &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = _c_.apr_pool_create(
                    &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    if ast:
        raise _svn.PoolError()

    try:
        IF SVN_API_VER >= (1, 10):
            change = {}
            serr = _c_.svn_fs_paths_changed3(
                        &_c_iterator, root._c_ptr, _c_tmp_pool, _c_tmp_pool)
            if serr is not NULL:
                pyerr = _svn.Svn_error().seterror(serr)
                raise _svn.SVNerr(pyerr)
            serr = _c_.svn_fs_path_change_get(&_c_change, _c_iterator)
            if serr is not NULL:
                pyerr = _svn.Svn_error().seterror(serr)
                raise _svn.SVNerr(pyerr)
            while _c_change is not NULL:
                copyfrom_path = (_c_change[0].copyfrom_path
                                    if _c_change[0].copyfrom_path is not NULL 
                                    else None)
                change[(_c_change[0].path.data)[:_c_change[0].data.len]] = \
                    FsPathChange(
                        _c_change[0].change_kind,
                        _c_change[0].node_kind,
                        _c_change[0].text_mod,
                        _c_change[0].prop_mod,
                        _c_change[0].mergeinfo_mod,
                        _c_change[0].copyfrom_known,
                        copyfrom_path)
                serr = _c_.svn_fs_path_change_get(
                                        &_c_change, _c_iterator)
                if serr is not NULL:
                    pyerr = _svn.Svn_error().seterror(serr)
                    raise _svn.SVNerr(pyerr)
        ELSE:
            pt_trans = FsPathChangeTrans(scratch_pool)
            IF SVN_API_VER >= (1, 6):
                serr = _c_.svn_fs_paths_changed2(
                            <_c_.apr_hash_t **>(pt_trans.ptr_ref()),
                            root._c_ptr, _c_tmp_pool)
            ELSE:
                serr = _c_.svn_fs_paths_changed(
                            <_c_.apr_hash_t **>(pt_trans.ptr_ref()),
                            root._c_ptr, _c_tmp_pool)
            if serr is not NULL:
                pyerr = _svn.Svn_error().seterror(serr)
                raise _svn.SVNerr(pyerr)
            change = pt_trans.to_object()
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return change


cdef class NodeKindTrans(_svn.TransPtr): 
    cdef object to_object(self):
        return self._c_kind
    cdef void set_c_kind(self, _c_.svn_node_kind_t _c_kind):
        self._c_kind = _c_kind
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_kind)

def svn_fs_check_path(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_check_path,
                NodeKindTrans(),
                root, path, scratch_pool)

cdef class svn_fs_history_t(object):
    # cdef _c_.svn_fs_history_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
    cdef set_history(self, _c_.svn_fs_history_t * history):
        self._c_ptr = history
        return self

# warn: though result_pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until 
# the program terminates. (scratch_pool is used only if API version >= 1.10)
def svn_fs_node_history(
        svn_fs_root_t root, const char * path,
        result_pool=None, scratch_pool=None):
    cdef _c_.svn_fs_history_t * _c_history
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.apr_pool_t * _c_result_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if result_pool is not None:
        assert (    isinstance(result_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>result_pool)._c_pool is not NULL)
        _c_result_pool = (<_svn.Apr_Pool>result_pool)._c_pool
    else:
        _c_result_pool = (<_svn.Apr_Pool>_svn._root_pool)._c_pool
    IF SVN_API_VER >= (1, 10):
        if scratch_pool is not None:
            assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                    and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
        else:
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        IF SVN_API_VER >= (1, 10):
            serr = _c_.svn_fs_node_history2(
                            &_c_history, root._c_ptr, path,
                            _c_result_pool, _c_tmp_pool)
        ELSE:
            serr = _c_.svn_fs_node_history(
                            &_c_history, root._c_ptr, path,
                            _c_result_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        IF SVN_API_VER >= (1, 10):
            _c_.apr_pool_destroy(_c_tmp_pool)
        ELSE:
            pass
    return svn_fs_history_t().set_history(_c_history)

# warn: though result_pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until 
# the program terminates. (scratch_pool is used only if API version >= 1.10)
def svn_fs_history_prev(
        svn_fs_history_t history, object cross_copies,
        result_pool=None, scratch_pool=None):
    cdef _c_.svn_fs_history_t * _c_prev
    cdef _c_.svn_boolean_t _c_cross_copies
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.apr_pool_t * _c_result_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if result_pool is not None:
        assert (    isinstance(result_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>result_pool)._c_pool is not NULL)
        _c_result_pool = (<_svn.Apr_Pool>result_pool)._c_pool
    else:
        _c_result_pool = (<_svn.Apr_Pool>_svn._root_pool)._c_pool
    _c_cross_copies = True if cross_copies else False
    IF SVN_API_VER >= (1, 10):
        if scratch_pool is not None:
            assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                    and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
        else:
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        IF SVN_API_VER >= (1, 10):
            serr = _c_.svn_fs_history_prev2(
                            &_c_prev, history._c_ptr, _c_cross_copies, 
                            _c_result_pool, _c_tmp_pool)
        ELSE:
            serr = _c_.svn_fs_history_prev(
                            &_c_prev, history._c_ptr, _c_cross_copies,
                            _c_result_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        IF SVN_API_VER >= (1, 10):
            _c_.apr_pool_destroy(_c_tmp_pool)
        ELSE:
            pass
    return svn_fs_history_t().set_history(_c_prev)


def svn_fs_history_location(svn_fs_history_t history, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_revnum_t revision
    cdef const char * _c_path
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = _c_.svn_fs_history_location(
                        &_c_path, &revision, history._c_ptr, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        path = _c_path
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return path, revision

def svn_fs_is_dir(svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_is_dir,
                _svn.SvnBooleanTrans(),
                root, path, scratch_pool)

def svn_fs_is_file(svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_is_file,
                _svn.SvnBooleanTrans(),
                root, path, scratch_pool)

# warn: though result_pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until 
# the program terminates.
def svn_fs_node_id(svn_fs_root_t root, const char * path, result_pool=None):
    cdef _c_.apr_pool_t * _c_result_pool
    cdef _c_.svn_fs_id_t * _c_id
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if result_pool is not None:
        assert (    isinstance(result_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>result_pool)._c_pool is not NULL)
        _c_result_pool = (<_svn.Apr_Pool>result_pool)._c_pool
    else:
        _c_result_pool = (<_svn.Apr_Pool>_svn._root_pool)._c_pool
    serr = _c_.svn_fs_node_id(
                    <const _c_.svn_fs_id_t **>&_c_id,
                    root._c_ptr, path, _c_result_pool)
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    return svn_fs_id_t().set_fs_id(_c_id)

def svn_fs_node_created_rev(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_revnum_t _c_revision
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = _c_.svn_fs_node_created_rev(
                    &_c_revision, root._c_ptr, path, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return _c_revision


# warn: this function doesn't provide full functionally
# (not return a apr_hash object but a dict of which key is Python str object,
#  and its contents is not svn_string_t but python str objects.
#  So it cannot be used for arguments for other svn wrapper APIs directly)
def svn_fs_node_proplist(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_node_proplist, 
                _svn.HashTrans(_svn.CStringTransStr(), 
                               _svn.SvnStringTransStr()),
                root, path, scratch_pool)

def svn_fs_copied_from(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_revnum_t _c_rev
    cdef const char * _c_from_path
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = _c_.svn_fs_copied_from(
                        &_c_rev, &_c_from_path, root._c_ptr, path, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        from_path = _c_from_path
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return _c_rev, from_path

# This class placeholder of contents of svn_fs_dirent_t, enough to the extent
# to use from svn_repos.py[x], but not provide full function.
class DirEntry(object):
    def __init__(self, name, id, kind):
        self.name = name
        self.id = id
        self.id = kind

cdef class DirEntryTrans(_svn.TransPtr):
    cdef object to_object(self):
        name = (self._c_dirent)[0].name
        id = svn_fs_id_t().set_fs_id(<_c_.svn_fs_id_t *>
                                            ((self._c_dirent)[0].id))
        kind = (self._c_dirent)[0].kind
        return DirEntry(name, id, kind)
    cdef void set_c_dirent(self, _c_.svn_fs_dirent_t *_c_dirent):
        self._c_dirent = _c_dirent
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_dirent)

# warn: this function doesn't provide full functionally
# (not return a apr_hash object but a dict of which key is Python str object,
#  and its contents is not svn_fs_dirent_t but python DirEntry objects.
#  So it cannot be used for arguments for other svn wrapper APIs directly)
def svn_fs_dir_entries(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_dir_entries,
                _svn.HashTrans(_svn.CStringTransBytes(), DirEntryTrans()),
                root, path, scratch_pool)

cdef class FileSizeTrans(_svn.TransPtr):
    cdef object to_object(self):
        return <object>self._c_fsize
    cdef void set_filesize(self, _c_.svn_filesize_t _c_fsize):
        self._c_fsize = _c_fsize
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_fsize)

def svn_fs_file_length(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_file_length,
                FileSizeTrans(),
                root, path, scratch_pool)

# warn: though pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until 
# the program terminates.
def svn_fs_file_contents(svn_fs_root_t root, const char * path, pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef _c_.svn_stream_t * _c_contents

    if pool is not None:
        assert (    isinstance(pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>pool)._c_pool is not NULL)
        _c_pool = (<_svn.Apr_Pool>pool)._c_pool
    else:
        _c_pool = (<_svn.Apr_Pool>_svn._root_pool)._c_pool
    serr = _c_.svn_fs_file_contents(
                    &_c_contents, root._c_ptr, path, _c_pool)
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    return _svn.svn_stream_t().set_stream(_c_contents)


def svn_fs_youngest_rev(svn_fs_t fs, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_revnum_t _c_rev
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = _c_.svn_fs_youngest_rev(
                        &_c_rev, fs._c_ptr, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return _c_rev

# warn: this function doesn't provide full functionally
# (not return a apr_hash object but a dict of which key is Python str object,
#  and its contents is not svn_string_t but python str objects.
#  So it cannot be used for arguments for other svn wrapper APIs directly)
def svn_fs_revision_proplist(
        svn_fs_t fs, _c_.svn_revnum_t rev, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef _c_.apr_hash_t * _c_tp
    cdef _svn.HashTrans prop_trans

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    prop_trans = _svn.HashTrans(_svn.CStringTransStr(), 
                                _svn.SvnStringTransStr(), scratch_pool)
    try:
        IF SVN_API_VER >= (1, 10):
            serr = _c_.svn_fs_revision_proplist2(
                        <_c_.apr_hash_t **>(prop_trans.ptr_ref()),
                        fs._c_ptr, rev, _c_.TRUE,
                        _c_tmp_pool, _c_tmp_pool)
        ELSE:
            serr = _c_.svn_fs_revision_proplist(
                        <_c_.apr_hash_t **>(prop_trans.ptr_ref()),
                        fs._c_ptr, rev, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return prop_trans.to_object()

# This class placeholder of contents of svn_lock_t, enough to the extent
# to use from svn_repos.py[x], but not provide full function.
class SvnLock(object):
    def __init__(self, name, token, owner, comment, is_dav_comment,
                 creation_date, expiration_date):
        self.name = name
        self.token = token
        self.owner = owner
        self.comment = comment
        self.is_dav_comment = is_dav_comment
        self.creation_date = creation_date
        self.expiration_date = expiration_date

cdef object _svn_lock_to_object(_c_.svn_lock_t * _c_lock):
    if _c_lock is NULL:
        return None
    else:
        is_dav_comment = (True if _c_lock[0].is_dav_comment != _c_.FALSE
                               else False)
        return SvnLock(_c_lock[0].name, _c_lock[0].token, _c_lock[0].owner,
                       _c_lock[0].comment, is_dav_comment,
                       _c_lock[0].creation_date, _c_lock[0].expiration_date)

# warn: this function doesn't provide full functionally
# (not return a svn_lock_t object but pure Python SvnLock object.
#  So it cannot be used for arguments for other svn wrapper APIs directly)
def svn_fs_get_lock(svn_fs_t fs, const char * path, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef _c_.svn_lock_t * _c_lock

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = _c_.svn_fs_get_lock(
                        &_c_lock, fs._c_ptr, path, _c_tmp_pool)
        lock = _svn_lock_to_object(_c_lock)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return lock



cdef class svn_repos_t(object):
    # cdef _c_.svn_repos_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
    cdef svn_repos_t set_repos(
            svn_repos_t self, _c_.svn_repos_t * repos):
        self._c_ptr = repos
        return self

# this is only for svn_repos.py{x}, does not provide full function
# but try to newer API.
def svn_repos_open(const char * path, result_pool=None, scratch_pool=None):
    cdef _c_.svn_repos_t * _c_repos
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    IF SVN_API_VER >= (1, 9):
        cdef _c_.apr_pool_t * _c_result_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if result_pool is not None:
        assert (    isinstance(result_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>result_pool)._c_pool is not NULL)
        _c_result_pool = (<_svn.Apr_Pool>result_pool)._c_pool
    else:
        _c_result_pool = (<_svn.Apr_Pool>_svn._root_pool)._c_pool
    IF SVN_API_VER >= (1, 9):
        if scratch_pool is not None:
            assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                    and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
        else:
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        IF SVN_API_VER >= (1, 9):
            serr = _c_.svn_repos_open3(
                        &_c_repos, path, NULL, _c_result_pool, _c_tmp_pool)
        ELIF SVN_API_VER >= (1, 4):
            serr = _c_.svn_repos_open2(
                        &_c_repos, path, NULL, _c_result_pool)
        ELSE:
            serr = _c_.svn_repos_open(
                        &_c_repos, path, _c_result_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        IF SVN_API_VER >= (1, 9):
            _c_.apr_pool_destroy(_c_tmp_pool)
        ELSE:
            pass
    return svn_repos_t().set_repos(_c_repos)

def svn_repos_fs(svn_repos_t repos):
    return svn_fs_t().set_fs(_c_.svn_repos_fs(repos._c_ptr))

# vclib custom revinfo helper
# copy from subversion/bindings/swig/python/svn/repos.py, class ChangedPath,
# with Cython and customize for vclib.svn.svn_repos
cdef class _ChangedPath(object):
    cdef _c_.svn_node_kind_t item_kind
    cdef _c_.svn_boolean_t prop_changes
    cdef _c_.svn_boolean_t prop_text_changed
    cdef bytes base_path
    cdef _c_.svn_revnum_t base_rev
    cdef bytes path
    cdef _c_.svn_boolean_t added
    # we don't use 'None' action
    cdef _c_.svn_fs_path_change_kind_t action
    def __init__(self,
                 _c_.svn_node_kind_t item_kind,
                 _c_.svn_boolean_t prop_changes,
                 _c_.svn_boolean_t text_changed,
                 bytes base_path, _c_.svn_revnum_t base_rev,
                 bytes path, _c_.svn_boolean_t added,
                 _c_.svn_fs_path_change_kind_t action):
        self.item_kind = item_kind
        self.prop_changes = prop_changes
        self.text_changed = text_changed
        self.base_path = base_path
        self.base_rev = base_rev
        self.path = path
        self.action = action

cdef class _get_changed_paths_EditBaton(object):
    cdef dict changes
    cdef svn_fs_t fs_ptr
    cdef svn_fs_root_t root
    cdef _c_.svn_revnum_t base_rev
    def __init__(self, svn_fs_t fs_ptr, svn_fs_root_t root):
        self.changes = {}
        self.fs_ptr = fs_ptr
        self.fs_root = root
        # in vclib, svn_fs_root_t root is always revision root
        assert _c_.svn_fs_is_revision_root(root._c_ptr)
        self.base_rev = (
                _c_.svn_fs_revision_root_revision(root._c_ptr) - 1)
        assert self.base_rev >= 0
    # copy from subversion/bindings/swig/python/svn/repos.py,
    # ChangeCollector._make_base_path(), with modification for Python 3
    # aware. we treat all path strings as bytes.
    def _make_base_path(self, parent_path, path):
        idx = path.rfind(b'/')
        if parent_path:
            parent_path = parent_path + b'/'
        if idx == -1:
            return parent_path + path
        return parent_path + path[idx+1:]
    def _get_root(self, rev):
        return self.fs_ptr._get_root(rev)

cdef class _get_changed_paths_DirBaton(object):
    cdef _get_changed_paths_EditBaton edit_baton
    cdef bytes path
    cdef bytes base_path
    cdef _c_.svn_revnum_t base_rev
    def __init__(self, path, base_path, _c_.svn_revnum_t base_rev,
                 _get_changed_paths_EditBaton edit_baton):
        self.path = path
        self.base_path = base_path
        self.base_rev = base_rev
        self.edit_baton = edit_baton

# custom call back used by get_changed_paths(), derived from
# subversion/bindings/swig/python/svn/repos.py, class ChangedCollector,
# with Cythonize
cdef _c_.svn_error_t * _cb_changed_paths_open_root(
        void * _c_edit_baton, _c_.svn_revnum_t base_revision,
        _c_.apr_pool_t * result_pool, void ** _c_root_baton) with gil:
    cdef _get_changed_paths_EditBaton eb
    cdef _get_changed_paths_DirBaton rb
    eb = <_get_changed_paths_EditBaton>_c_edit_baton
    rb = _get_changed_paths_DirBaton(
                    b'', b'', eb.base_rev, eb)
    _c_root_baton[0] = <void *>rb
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_delete_entry(
        const char * path, _c_.svn_revnum_t revision,
        void * parent_baton, _c_.apr_pool_t * scratch_pool) with gil:
    cdef _get_changed_paths_DirBaton pb
    cdef _get_changed_paths_EditBaton eb
    cdef _c_.svn_node_kind_t item_type
    pb = <_get_changed_paths_DirBaton>parent_baton
    eb = pb.edit_baton
    base_path = eb._make_base_path(pb.base_path, path)
    if svn_fs_is_dir(eb._get_root(pb.base_rev), base_path):
        item_type = _c_.svn_node_dir
    else:
        item_type = _c_.svn_node_file
    eb.changes[path] = _ChangedPath(item_type,
                                    _c_.FALSE,
                                    _c_.FALSE,
                                    base_path,
                                    pb.base_rev,
                                    path,
                                    _c_.FALSE,
                                    _c_.svn_fs_path_change_delete)
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_add_directory(
        const char * path, void * parent_baton,
        const char * copyfrom_path, _c_.svn_revnum_t copyfrom_revision,
        _c_.apr_pool_t * result_pool, void ** child_baton) with gil:
    cdef _get_changed_paths_DirBaton pb
    cdef _get_changed_paths_EditBaton eb
    cdef _get_changed_paths_DirBaton cb
    cdef _c_.svn_fs_path_change_kind_t action
    pb = <_get_changed_paths_DirBaton>parent_baton
    eb = pb.edit_baton
    if <bytes>path in eb.changes:
        action = _c_.svn_fs_path_change_replace
    else:
        action = _c_.svn_fs_path_change_add
    eb.changes[path] = _ChangedPath(_c_.svn_node_dir,
                                    _c_.FALSE,
                                    _c_.FALSE,
                                    copyfrom_path,
                                    copyfrom_revision,
                                    path,
                                    _c_.TRUE,
                                    action)
    if copyfrom_path is not NULL:
        assert copyfrom_revision >= 0
        base_path = copyfrom_path
    else:
        base_path = path
    # it is endored to allocate child baton from result_pool, but
    # we use Python's memory management
    cb = _get_changed_paths_DirBaton(
                    path, base_path, copyfrom_revision, eb)
    child_baton[0] = <void *>cb
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_open_directory(
            const char * path, void * parent_baton,
            _c_.svn_revnum_t base_revision,
            _c_.apr_pool_t * result_pool, void ** child_baton) with gil:
    cdef _get_changed_paths_DirBaton pb
    cdef _get_changed_paths_EditBaton eb
    cdef _get_changed_paths_DirBaton cb
    cdef bytes base_path
    pb = <_get_changed_paths_DirBaton>parent_baton
    eb = pb.edit_baton
    base_path = eb._make_base_path(pb.base_path, path)
    cb = _get_changed_paths_DirBaton(
                    path, base_path, pb.base_rev, eb)
    child_baton[0] = <void *>cb
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_change_dir_prop(
            void * dir_baton, const char * name,
            const _c_.svn_string_t * value,
            _c_.apr_pool_t * scratch_pool) with gil:
    cdef _get_changed_paths_DirBaton db
    cdef _get_changed_paths_EditBaton eb
    db = <_get_changed_paths_DirBaton>dir_baton
    eb = db.edit_baton
    if <bytes>(db.path) in eb.changes:
        (<_ChangedPath>(eb.changes[db.path])).prop_changes = _c_.TRUE
    else:
        # can't be added or deleted, so this must be CHANGED
        eb.changes[db.path] = _ChangedPath(
                                    _c_.svn_node_dir,
                                    _c_.TRUE,
                                    _c_.FALSE,
                                    db.base_path,
                                    db.base_rev,
                                    db.path,
                                    _c_.FALSE,
                                    _c_.svn_fs_path_change_modify)
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_add_file(
            const char * path, void * parent_baton, const char * copyfrom_path,
            _c_.svn_revnum_t copyfrom_revision,
            _c_.apr_pool_t * result_pool, void ** file_baton) with gil:
    cdef _get_changed_paths_DirBaton pb
    cdef _get_changed_paths_EditBaton eb
    cdef _get_changed_paths_DirBaton fb
    cdef _c_.svn_fs_path_change_kind_t action
    pb = <_get_changed_paths_DirBaton>parent_baton
    eb = pb.edit_baton
    if <bytes>path in eb.changes:
        action = _c_.svn_fs_path_change_replace
    else:
        action = _c_.svn_fs_path_change_add
    eb.changes[path] = _ChangedPath(_c_.svn_node_file,
                                    _c_.FALSE,
                                    _c_.FALSE,
                                    copyfrom_path,
                                    copyfrom_revision,
                                    path,
                                    _c_.TRUE,
                                    action)
    if copyfrom_path is not NULL:
        assert copyfrom_revision >= 0
        base_path = copyfrom_path
    else:
        base_path = path
    # it is endored to allocate child baton from result_pool, but
    # we use Python's memory management
    fb = _get_changed_paths_DirBaton(
                    path, base_path, copyfrom_revision, eb)
    file_baton[0] = <void *>fb
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_open_file(
            const char * path, void * parent_baton,
            _c_.svn_revnum_t base_revision,
            _c_.apr_pool_t * result_pool, void ** file_baton) with gil:
    cdef _get_changed_paths_DirBaton pb
    cdef _get_changed_paths_EditBaton eb
    cdef _get_changed_paths_DirBaton fb
    cdef bytes base_path
    pb = <_get_changed_paths_DirBaton>parent_baton
    eb = pb.edit_baton
    base_path = eb._make_base_path(pb.base_path, path)
    fb = _get_changed_paths_DirBaton(
                    path, base_path, pb.base_rev, eb)
    file_baton[0] = <void *>fb
    return NULL

cdef  _c_.svn_error_t * _cb_changed_paths_apply_textdelta(
            void * file_baton, const char * base_checksum,
            _c_.apr_pool_t * result_pool,
            _c_.svn_txdelta_window_handler_t * handler,
            void ** handler_baton) with gil:
    cdef _get_changed_paths_DirBaton pb
    cdef _get_changed_paths_EditBaton eb
    cdef _get_changed_paths_DirBaton fb
    pb = <_get_changed_paths_DirBaton>file_baton
    eb = pb.edit_baton
    if <bytes>(pb.path) in eb.changes:
        (<_ChangedPath>(eb.changes[pb.path])).text_changed = _c_.TRUE
    else:
        eb.changes[pb.path] = _ChangedPath(
                                    _c_.svn_node_file,
                                    _c_.FALSE,
                                    _c_.TRUE,
                                    pb.base_path,
                                    pb.base_rev,
                                    pb.path,
                                    _c_.FALSE,
                                    _c_.svn_fs_path_change_modify)
    # we know no handlers to be set
    handler_baton[0] = NULL
    return NULL

cdef  _c_.svn_error_t * _cb_changed_paths_change_file_prop(
            void * file_baton, const char * name,
            const _c_.svn_string_t * value,
            _c_.apr_pool_t * scratch_pool) with gil:
    cdef _get_changed_paths_DirBaton fb
    cdef _get_changed_paths_EditBaton eb
    fb = <_get_changed_paths_DirBaton>file_baton
    eb = fb.edit_baton
    if <bytes>(fb.path) in eb.changes:
        (<_ChangedPath>(eb.changes[fb.path])).prop_changes = _c_.TRUE
    else:
        # can't be added or deleted, so this must be CHANGED
        eb.changes[fb.path] = _ChangedPath(
                                    _c_.svn_node_file,
                                    _c_.TRUE,
                                    _c_.FALSE,
                                    fb.base_path,
                                    fb.base_rev,
                                    fb.path,
                                    _c_.FALSE,
                                    _c_.svn_fs_path_change_modify)
    return NULL

def _get_changed_paths_helper(
        svn_fs_t fs, svn_fs_root_t fsroot, object pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.svn_error_t * serr
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_delta_editor_t * editor
    cdef _get_changed_paths_EditBaton eb
    cdef _svn.Svn_error pyerr
    IF SVN_API_VER >= (1, 4):
        cdef bytes base_dir

    if pool is not None:
        assert ((<_svn.Apr_Pool?>pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                    &_c_tmp_pool, (<_svn.Apr_Pool>pool)._c_pool)
    else:
        ast = _c_.apr_pool_create(
                    &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        editor = _c_.svn_delta_default_editor(_c_tmp_pool)
        editor[0].open_root        = _cb_changed_paths_open_root
        editor[0].delete_entry     = _cb_changed_paths_delete_entry
        editor[0].add_directory    = _cb_changed_paths_add_directory
        editor[0].open_directory   = _cb_changed_paths_open_directory
        editor[0].change_dir_prop  = _cb_changed_paths_change_dir_prop
        editor[0].add_file         = _cb_changed_paths_add_file
        editor[0].open_file        = _cb_changed_paths_open_file
        editor[0].apply_textdelta  = _cb_changed_paths_apply_textdelta
        editor[0].change_file_prop = _cb_changed_paths_change_file_prop
        eb = _get_changed_paths_EditBaton(fs, fsroot)
        IF SVN_API_VER >= (1, 4):
            base_dir = b''
            serr = _c_.svn_repos_replay2(
                            fsroot._c_ptr, <const char *>base_dir,
                            _c_.SVN_INVALID_REVNUM, _c_.FALSE,
                            editor, <void *>eb, NULL, NULL, _c_tmp_pool)
        ELSE:
            serr = _c_.svn_repos_replay(
                            fsroot._c_ptr, editor, <void *>eb,  _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return eb.changes

# Cython version of vclib.svn.svn_repos.NodeHistory class
# (used as history baton on svn_repos_history2 call)
cdef class NodeHistory(object):
    """A history baton object that builds list of 2-tuple (revision, path)
    locations along a node's change history, orderd from youngest to
    oldest."""
    cdef list histories
    cdef _c_.svn_revnum_t _item_cnt # cache of len(self.histories)
    cdef svn_fs_t fs_ptr
    cdef _c_.svn_boolean_t show_all_logs 
    cdef _c_.svn_revnum_t oldest_rev
    cdef _c_.svn_revnum_t limit
    def __init__(self, svn_fs_t fs_ptr,
                 _c_.svn_boolean_t show_all_logs,
                 _c_.svn_revnum_t limit):
        self.histories = []
        self.fs_ptr = fs_ptr
        self.show_all_logs = show_all_logs
        self.oldest_rev = _c_.SVN_INVALID_REVNUM
        self.limit = limit

# call back function for _get_history_helper()
cdef _c_.svn_error_t * _cb_collect_node_history(
            void * baton, const char * _c_path, _c_.svn_revnum_t revision,
            _c_.apr_pool_t * pool) with gil:
    cdef NodeHistory btn
    cdef object changed_paths
    cdef bytes path 
    cdef svn_fs_root_t rev_root
    cdef bytes test_path
    cdef _c_.svn_boolean_t found
    cdef object off
    cdef _c_.svn_revnum_t copyfrom_rev
    cdef bytes copyfrom_path
    cdef _c_.svn_error_t * serr
    btn = <NodeHistory>baton
    if btn.oldest_rev == _c_.SVN_INVALID_REVNUM:
        btn.oldest_rev = revision
    else:
        assert revision < btn.oldest_rev
    path = <bytes>_c_path
    if btn.show_all_logs == _c_.FALSE:
        rev_root = btn.fs_ptr._get_root(revision)
        changed_paths = svn_fs_paths_changed(rev_root)
        if path not in changed_paths:
            # Look for a copied parent
            test_path = path
            found = _c_.FALSE
            off = test_path.rfind(b'/')
            while off >= 0: 
                test_path = test_path[0:off]
                if test_path in changed_paths:
                    copyfrom_rev, copyfrom_path = \
                            svn_fs_copied_from(rev_root, test_path)
                    if copyfrom_rev >= 0 and copyfrom_path:
                        found = _c_.TRUE
                        break
                off = test_path.rfind(b'/')
            if found == _c_.FALSE:
                return NULL
    btn.histories.append([revision, b'/'.join(filter(None, path.split(b'/')))])
    btn._item_cnt += 1
    if btn.limit and btn.item_cnt >= btn.limit:
        IF SVN_API_VER >= (1, 5):
            serr = _c_.svn_error_create(
                        _c_.SVN_ERR_CEASE_INVOCATION, NULL, NULL)
        ELSE:
            serr = _c_.svn_error_create(
                        _c_.SVN_ERR_CANCELLED, NULL, NULL)
        return serr
    return NULL

def _get_history_helper(
            svn_fs_t fs_ptr, const char * path,
            _c_.svn_revnum_t rev, _c_.svn_boolean_t cross_copies,
            _c_.svn_boolean_t show_all_logs,
            _c_.svn_revnum_t limit, pool = None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef NodeHistory nhbtn

    nhbtn = NodeHistory(fs_ptr, show_all_logs, limit)
    if pool is not None:
        assert ((<_svn.Apr_Pool?>pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                    &_c_tmp_pool, (<_svn.Apr_Pool>pool)._c_pool)
    else:
        ast = _c_.apr_pool_create(
                    &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = _c_.svn_repos_history2(
                    fs_ptr._c_ptr, path, _cb_collect_node_history, 
                    <void *>nhbtn, NULL, NULL, 1, rev, cross_copies,
                    _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return nhbtn.histories
