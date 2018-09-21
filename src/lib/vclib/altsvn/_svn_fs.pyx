include "_svn_api_ver.pxi"
include "_py_ver.pxi"
from apr_1 cimport apr
from apr_1 cimport apr_errno
from apr_1 cimport apr_pools
from apr_1 cimport apr_hash
from subversion_1 cimport svn_types
from subversion_1 cimport svn_fs
from subversion_1 cimport svn_io
cimport _svn
from . import _svn

cdef class svn_fs_t(object):
    # cdef svn_fs.svn_fs_t * _c_ptr
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
    cdef set_fs(self, svn_fs.svn_fs_t * fs):
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
    # cdef svn_fs.svn_fs_root_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
        self._pool = None
    cdef set_fs_root(self, svn_fs.svn_fs_root_t * fs_root):
        self._c_ptr = fs_root
        return self
    def __dealloc__(self):
        if self._c_ptr is not NULL:
            svn_fs.svn_fs_close_root(self._c_ptr)
            self._c_ptr = NULL
            self._pool = None

cdef class svn_fs_id_t(object):
    # cdef svn_fs.svn_fs_id_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
    cdef set_fs_id(self, svn_fs.svn_fs_id_t * fs_id):
        self._c_ptr = fs_id
        return self

def svn_fs_compare_ids(svn_fs_id_t a, svn_fs_id_t b):
    return svn_fs.svn_fs_compare_ids(a._c_ptr, b._c_ptr)


# warn: though pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until 
# the program terminates. 
def svn_fs_revision_root(svn_fs_t fs, svn_types.svn_revnum_t rev, pool=None):
    cdef _svn.Apr_Pool result_pool 
    cdef svn_fs.svn_fs_root_t * _c_root
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if pool is not None:
        assert (    isinstance(pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>pool)._c_pool is not NULL)
        result_pool = pool
    else:
        result_pool = _svn._root_pool
    serr = svn_fs.svn_fs_revision_root(
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
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = svn_api(rv_trans.ptr_ref(), root._c_ptr, path, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        rv = rv_trans.to_object()
    finally:
        apr_pools.apr_pool_destroy(_c_tmp_pool)
    return rv

# export svn C API constants into Python object
svn_fs_path_change_modify  = svn_fs.svn_fs_path_change_modify
svn_fs_path_change_add     = svn_fs.svn_fs_path_change_add
svn_fs_path_change_delete  = svn_fs.svn_fs_path_change_delete
svn_fs_path_change_replace = svn_fs.svn_fs_path_change_replace
svn_fs_path_change_reset   = svn_fs.svn_fs_path_change_reset

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
                     mergeinfo_mod = svn_types.svn_tristate_unknown):
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
            cdef apr_errno.apr_status_t ast
            if scratch_pool is not None:
                assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
                ast = apr_pools.apr_pool_create(
                                &(self._c_tmp_pool),
                                (<_svn.Apr_Pool>scratch_pool)._c_pool)
            else:
                ast = apr_pools.apr_pool_create(
                                &(self._c_tmp_pool), _svn._root_pool._c_pool)
            if ast:
                raise _svn.PoolError()
        def __dealloc__(self):
            if self._c_tmp_pool is not NULL:
                apr_pools.apr_pool_destroy(self._c_tmp_pool)
                self._c_tmp_pool = NULL
        cdef object to_object(self):
            IF SVN_API_VER == (1, 9):
                return FsPathChange(
                        svn_fs_id_t().set_fs_id(
                                <svn_fs.svn_fs_id_t *>
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
                                <svn_fs.svn_fs_id_t *>
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
                                <svn_fs.svn_fs_id_t *>
                                ((self._c_change)[0].node_rev_id)),
                        (self._c_change)[0].change_kind,
                        (self._c_change)[0].text_mod,
                        (self._c_change)[0].prop_mod)
        IF SVN_API_VER >= (1, 6):
            cdef void set_c_change(
                    self, svn_fs.svn_fs_path_change2_t * _c_change):
                self._c_change = _c_change
        ELSE:
            cdef void set_c_change(
                    self, svn_fs.svn_fs_path_change_t * _c_change):
                self._c_change = _c_change
        cdef void ** ptr_ref(self):
            return <void **>&(self._c_change)

# warn: this function doesn't provide full functionally
# (not return apr_hash object but dict, and its contents is neither
#  svn_fs_path_change2_t nor svn_fs_path_change_t object but python
#  object, which cannot be used for arguments for other svn wrapper APIs
#  directly)
def svn_fs_path_changed(svn_fs_root_t root, scratch_pool=None):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    IF SVN_API_VER >= (1, 10):
        cdef svn_fs.svn_fs_path_change_iterator_t * _c_iterator
        cdef svn_fs.svn_fs_path_change3_t * _c_change
    ELSE:
        cdef _svn.HashTrans pt_trans

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = apr_pools.apr_pool_create(
                    &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = apr_pools.apr_pool_create(
                    &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    if ast:
        raise _svn.PoolError()

    try:
        IF SVN_API_VER >= (1, 10):
            change = {}
            serr = svn_fs.svn_fs_paths_changed3(
                        &_c_iterator, root._c_ptr, _c_tmp_pool, _c_tmp_pool)
            if serr is not NULL:
                pyerr = _svn.Svn_error().seterror(serr)
                raise _svn.SVNerr(pyerr)
            serr = svn_fs.svn_fs_path_change_get(&_c_change, _c_iterator)
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
                serr = svn_fs.svn_fs_path_change_get(
                                        &_c_change, _c_iterator)
                if serr is not NULL:
                    pyerr = _svn.Svn_error().seterror(serr)
                    raise _svn.SVNerr(pyerr)
        ELSE:
            pt_trans = FsPathChangeTrans(scratch_pool)
            IF SVN_API_VER >= (1, 6):
                serr = svn_fs.svn_fs_paths_changed2(
                            <apr_hash.apr_hash_t **>(pt_trans.ptr_ref()),
                            root._c_ptr, _c_tmp_pool)
            ELSE:
                serr = svn_fs.svn_fs_paths_changed(
                            <apr_hash.apr_hash_t **>(pt_trans.ptr_ref()),
                            root._c_ptr, _c_tmp_pool)
            if serr is not NULL:
                pyerr = _svn.Svn_error().seterror(serr)
                raise _svn.SVNerr(pyerr)
            change = pt_trans.to_object()
    finally:
        apr_pools.apr_pool_destroy(_c_tmp_pool)
    return change


cdef class NodeKindTrans(_svn.TransPtr): 
    cdef object to_object(self):
        return self._c_kind
    cdef void set_c_kind(self, svn_types.svn_node_kind_t _c_kind):
        self._c_kind = _c_kind
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_kind)

def svn_fs_check_path(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>svn_fs.svn_fs_check_path,
                NodeKindTrans(),
                root, path, scratch_pool)

cdef class svn_fs_history_t(object):
    # cdef svn_fs.svn_fs_history_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
    cdef set_history(self, svn_fs.svn_fs_history_t * history):
        self._c_ptr = history
        return self

# warn: though result_pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until 
# the program terminates. (scratch_pool is used only if API version >= 1.10)
def svn_fs_node_history(
        svn_fs_root_t root, const char * path,
        result_pool=None, scratch_pool=None):
    cdef svn_fs.svn_fs_history_t * _c_history
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef apr_pools.apr_pool_t * _c_result_pool
    cdef svn_types.svn_error_t * serr
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
            ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
        else:
            ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        IF SVN_API_VER >= (1, 10):
            serr = svn_fs.svn_fs_node_history2(
                            &_c_history, root._c_ptr, path,
                            _c_result_pool, _c_tmp_pool)
        ELSE:
            serr = svn_fs.svn_fs_node_history(
                            &_c_history, root._c_ptr, path,
                            _c_result_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        IF SVN_API_VER >= (1, 10):
            apr_pools.apr_pool_destroy(_c_tmp_pool)
        ELSE:
            pass
    return svn_fs_history_t().set_history(_c_history)

# warn: though result_pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until 
# the program terminates. (scratch_pool is used only if API version >= 1.10)
def svn_fs_history_prev(
        svn_fs_history_t history, object cross_copies,
        result_pool=None, scratch_pool=None):
    cdef svn_fs.svn_fs_history_t * _c_prev
    cdef svn_types.svn_boolean_t _c_cross_copies
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef apr_pools.apr_pool_t * _c_result_pool
    cdef svn_types.svn_error_t * serr
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
            ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
        else:
            ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        IF SVN_API_VER >= (1, 10):
            serr = svn_fs.svn_fs_history_prev2(
                            &_c_prev, history._c_ptr, _c_cross_copies, 
                            _c_result_pool, _c_tmp_pool)
        ELSE:
            serr = svn_fs.svn_fs_history_prev(
                            &_c_prev, history._c_ptr, _c_cross_copies,
                            _c_result_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        IF SVN_API_VER >= (1, 10):
            apr_pools.apr_pool_destroy(_c_tmp_pool)
        ELSE:
            pass
    return svn_fs_history_t().set_history(_c_prev)


def svn_fs_history_location(svn_fs_history_t history, scratch_pool=None):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef svn_types.svn_revnum_t revision
    cdef const char * _c_path
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = svn_fs.svn_fs_history_location(
                        &_c_path, &revision, history._c_ptr, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        path = _c_path
    finally:
        apr_pools.apr_pool_destroy(_c_tmp_pool)
    return path, revision

def svn_fs_is_dir(svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>svn_fs.svn_fs_is_dir,
                _svn.SvnBooleanTrans(),
                root, path, scratch_pool)

def svn_fs_is_file(svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>svn_fs.svn_fs_is_file,
                _svn.SvnBooleanTrans(),
                root, path, scratch_pool)

# warn: though result_pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until 
# the program terminates.
def svn_fs_node_id(svn_fs_root_t root, const char * path, result_pool=None):
    cdef apr_pools.apr_pool_t * _c_result_pool
    cdef svn_fs.svn_fs_id_t * _c_id
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if result_pool is not None:
        assert (    isinstance(result_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>result_pool)._c_pool is not NULL)
        _c_result_pool = (<_svn.Apr_Pool>result_pool)._c_pool
    else:
        _c_result_pool = (<_svn.Apr_Pool>_svn._root_pool)._c_pool
    serr = svn_fs.svn_fs_node_id(
                    <const svn_fs.svn_fs_id_t **>&_c_id,
                    root._c_ptr, path, _c_result_pool)
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    return svn_fs_id_t().set_fs_id(_c_id)

def svn_fs_node_created_rev(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef svn_types.svn_revnum_t _c_revision
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = svn_fs.svn_fs_node_created_rev(
                    &_c_revision, root._c_ptr, path, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        apr_pools.apr_pool_destroy(_c_tmp_pool)
    return _c_revision


# warn: this function doesn't provide full functionally
# (not return a apr_hash object but a dict of which key is Python str object,
#  and its contents is not svn_string_t but python str objects.
#  So it cannot be used for arguments for other svn wrapper APIs directly)
def svn_fs_node_proplist(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>svn_fs.svn_fs_node_proplist, 
                _svn.HashTrans(_svn.CStringTransStr(), 
                               _svn.SvnStringTransStr()),
                root, path, scratch_pool)

def svn_fs_copied_from(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef svn_types.svn_revnum_t _c_rev
    cdef const char * _c_from_path
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = svn_fs.svn_fs_copied_from(
                        &_c_rev, &_c_from_path, root._c_ptr, path, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        from_path = _c_from_path
    finally:
        apr_pools.apr_pool_destroy(_c_tmp_pool)
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
        id = svn_fs_id_t().set_fs_id(<svn_fs.svn_fs_id_t *>
                                            ((self._c_dirent)[0].id))
        kind = (self._c_dirent)[0].kind
        return DirEntry(name, id, kind)
    cdef void set_c_dirent(self, svn_fs.svn_fs_dirent_t *_c_dirent):
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
                <svn_rv1_root_path_func_t>svn_fs.svn_fs_dir_entries,
                _svn.HashTrans(_svn.CStringTransBytes(), DirEntryTrans()),
                root, path, scratch_pool)

cdef class FileSizeTrans(_svn.TransPtr):
    cdef object to_object(self):
        return <object>self._c_fsize
    cdef void set_filesize(self, svn_types.svn_filesize_t _c_fsize):
        self._c_fsize = _c_fsize
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_fsize)

def svn_fs_file_length(
        svn_fs_root_t root, const char * path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>svn_fs.svn_fs_file_length,
                FileSizeTrans(),
                root, path, scratch_pool)

# warn: though pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until 
# the program terminates.
def svn_fs_file_contents(svn_fs_root_t root, const char * path, pool=None):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_pool
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef svn_io.svn_stream_t * _c_contents

    if pool is not None:
        assert (    isinstance(pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>pool)._c_pool is not NULL)
        _c_pool = (<_svn.Apr_Pool>pool)._c_pool
    else:
        _c_pool = (<_svn.Apr_Pool>_svn._root_pool)._c_pool
    serr = svn_fs.svn_fs_file_contents(
                    &_c_contents, root._c_ptr, path, _c_pool)
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    return _svn.svn_stream_t().set_stream(_c_contents)


def svn_fs_youngest_rev(svn_fs_t fs, scratch_pool=None):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef svn_types.svn_revnum_t _c_rev
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = svn_fs.svn_fs_youngest_rev(
                        &_c_rev, fs._c_ptr, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        apr_pools.apr_pool_destroy(_c_tmp_pool)
    return _c_rev

# warn: this function doesn't provide full functionally
# (not return a apr_hash object but a dict of which key is Python str object,
#  and its contents is not svn_string_t but python str objects.
#  So it cannot be used for arguments for other svn wrapper APIs directly)
def svn_fs_revision_proplist(
        svn_fs_t fs, svn_types.svn_revnum_t rev, scratch_pool=None):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef apr_hash.apr_hash_t * _c_tp
    cdef _svn.HashTrans prop_trans

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    prop_trans = _svn.HashTrans(_svn.CStringTransStr(), 
                                _svn.SvnStringTransStr(), scratch_pool)
    try:
        IF SVN_API_VER >= (1, 10):
            serr = svn_fs.svn_fs_revision_proplist2(
                        <apr_hash.apr_hash_t **>(prop_trans.ptr_ref()),
                        fs._c_ptr, rev, svn_types.TRUE,
                        _c_tmp_pool, _c_tmp_pool)
        ELSE:
            serr = svn_fs.svn_fs_revision_proplist(
                        <apr_hash.apr_hash_t **>(prop_trans.ptr_ref()),
                        fs._c_ptr, rev, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        apr_pools.apr_pool_destroy(_c_tmp_pool)
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

cdef object _svn_lock_to_object(svn_types.svn_lock_t * _c_lock):
    if _c_lock is NULL:
        return None
    else:
        is_dav_comment = (True if _c_lock[0].is_dav_comment != svn_types.FALSE
                               else False)
        return SvnLock(_c_lock[0].name, _c_lock[0].token, _c_lock[0].owner,
                       _c_lock[0].comment, is_dav_comment,
                       _c_lock[0].creation_date, _c_lock[0].expiration_date)

# warn: this function doesn't provide full functionally
# (not return a svn_lock_t object but pure Python SvnLock object.
#  So it cannot be used for arguments for other svn wrapper APIs directly)
def svn_fs_get_lock(svn_fs_t fs, const char * path, scratch_pool=None):
    cdef apr_errno.apr_status_t ast
    cdef apr_pools.apr_pool_t * _c_tmp_pool
    cdef svn_types.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef svn_types.svn_lock_t * _c_lock

    if scratch_pool is not None:
        assert (    isinstance(scratch_pool, _svn.Apr_Pool)
                and (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL)
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        ast = apr_pools.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>_svn._root_pool)._c_pool)
    try:
        serr = svn_fs.svn_fs_get_lock(
                        &_c_lock, fs._c_ptr, path, _c_tmp_pool)
        lock = _svn_lock_to_object(_c_lock)
    finally:
        apr_pools.apr_pool_destroy(_c_tmp_pool)
    return lock
