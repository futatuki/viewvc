include "_svn_api_ver.pxi"
include "_py_ver.pxi"
from libc.string cimport memcpy
cimport _svn_repos_capi as _c_
cimport _svn
from . import _svn

try:
    import os
    PathLike = os.PathLike
except AttributeError:
    class PathLike(object):
        pass

cdef class svn_fs_t(object):
    # cdef _c_.svn_fs_t * _c_ptr
    # cdef dict roots
    # cdef _svn.Apr_Pool pool
    def __cinit__(self, **m):
        self._c_ptr = NULL
        self.roots = {}
        self.pool = None
    cdef set_fs(self, _c_.svn_fs_t * fs, pool):
        self._c_ptr = fs
        self.roots = {}
        assert pool is None or isinstance(pool, _svn.Apr_Pool)
        self.pool = pool
        return self
    def _getroot(self, rev):
        try:
            return self.roots[rev]
        except KeyError:
            pass
        root = self.roots[rev] = svn_fs_revision_root(self, rev, self.pool)
        return root

cdef class svn_fs_root_t(object):
    # cdef _c_.svn_fs_root_t * _c_ptr
    # cdef _svn.Apr_Pool
    def __cinit__(self):
        self._c_ptr = NULL
        self.pool = None
    cdef set_fs_root(self, _c_.svn_fs_root_t * fs_root, pool):
        self._c_ptr = fs_root
        assert pool is None or isinstance(pool, _svn.Apr_Pool)
        self.pool = pool
        return self

cdef class svn_fs_id_t(object):
    # cdef _c_.svn_fs_id_t * _c_ptr
    # cdef _svn.Apr_Pool pool
    def __cinit__(self):
        self._c_ptr = NULL
    cdef set_fs_id(self, _c_.svn_fs_id_t * fs_id, pool):
        self._c_ptr = fs_id
        assert pool is None or isinstance(pool, _svn.Apr_Pool)
        self.pool = pool
        return self

def svn_fs_compare_ids(svn_fs_id_t a, svn_fs_id_t b):
    return _c_.svn_fs_compare_ids(a._c_ptr, b._c_ptr)


# warn: though pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until
# the program terminates.
def svn_fs_revision_root(svn_fs_t fs, _c_.svn_revnum_t rev, pool=None):
    cdef _svn.Apr_Pool r_pool
    cdef _c_.svn_fs_root_t * _c_root
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef svn_fs_root_t root

    if pool is not None:
        assert (<_svn.Apr_Pool?>pool)._c_pool is not NULL
        r_pool = pool
    else:
        r_pool = _svn._root_pool
    serr = _c_.svn_fs_revision_root(
                            &_c_root, fs._c_ptr, rev, r_pool._c_pool)
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    root = svn_fs_root_t().set_fs_root(_c_root, r_pool)
    return root

cdef object _apply_svn_api_root_path_arg1(
        svn_rv1_root_path_func_t svn_api, _svn.TransPtr rv_trans,
        svn_fs_root_t root, object path, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef const char * _c_path
    cdef object rv

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    _c_path = <const char *>path

    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
    try:
        serr = svn_api(rv_trans.ptr_ref(), root._c_ptr, _c_path, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        rv = rv_trans.to_object()
    except:
        rv = None
        raise
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
        def __cinit__(self, result_pool=None, scratch_pool=None, **m):
            self.result_pool = None
            self.tmp_pool = None
        def __init__(self, result_pool=None, scratch_pool=None, **m):
            if scratch_pool is not None:
                assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
                self.tmp_pool = _svn.Apr_Pool(scratch_pool)
            else:
                self.tmp_pool = _svn.Apr_Pool(_svn.root_pool)
            if result_pool is not None:
                assert (<_svn.Apr_Pool?>result_pool)._c_pool is not NULL
                self.result_pool = result_pool
            else:
                self.result_pool = _svn._root_pool
        cdef object to_object(self):
            IF SVN_API_VER >= (1, 6):
                cdef object copyfrom_path
                if (self._c_change)[0].copyfrom_path is NULL:
                    copyfrom_path = None
                else:
                    copyfrom_path = <bytes>((self._c_change)[0].copyfrom_path)
                    IF PY_VERSION >= (3, 0, 0):
                        copyfrom_path = _svn._norm(copyfrom_path)
            IF SVN_API_VER == (1, 9):
                return FsPathChange(
                        svn_fs_id_t().set_fs_id(
                                <_c_.svn_fs_id_t *>
                                        ((self._c_change)[0].node_rev_id),
                                self.result_pool),
                        (self._c_change)[0].change_kind,
                        (self._c_change)[0].text_mod,
                        (self._c_change)[0].prop_mod,
                        (self._c_change)[0].node_kind,
                        (self._c_change)[0].copyfrom_known,
                        (self._c_change)[0].copyfrom_rev,
                        copyfrom_path,
                        (self._c_change)[0].mergeinfo_mod)
            ELIF SVN_API_VER >= (1, 6):
                return FsPathChange(
                        svn_fs_id_t().set_fs_id(
                                <_c_.svn_fs_id_t *>
                                        ((self._c_change)[0].node_rev_id),
                                self.result_pool),
                        (self._c_change)[0].change_kind,
                        (self._c_change)[0].text_mod,
                        (self._c_change)[0].prop_mod,
                        (self._c_change)[0].node_kind,
                        (self._c_change)[0].copyfrom_known,
                        (self._c_change)[0].copyfrom_rev,
                        copyfrom_path)
            ELSE:
                return FsPathChange(
                        svn_fs_id_t().set_fs_id(
                                <_c_.svn_fs_id_t *>
                                        ((self._c_change)[0].node_rev_id),
                                self.result_pool),
                        (self._c_change)[0].change_kind,
                        (self._c_change)[0].text_mod,
                        (self._c_change)[0].prop_mod)
        IF SVN_API_VER >= (1, 6):
            cdef void set_c_change(
                    self, _c_.svn_fs_path_change2_t * _c_change,
                    object result_pool):
                assert (<_svn.Apr_Pool?>result_pool)._c_pool is not NULL
                self._c_change = _c_change
                self.result_pool = result_pool
        ELSE:
            cdef void set_c_change(
                    self, _c_.svn_fs_path_change_t * _c_change,
                    object result_pool):
                assert (<_svn.Apr_Pool?>result_pool)._c_pool is not NULL
                self._c_change = _c_change
                self._c_change = _c_change
        cdef void ** ptr_ref(self):
            return <void **>&(self._c_change)

# warn: this function doesn't provide full functionally
# (not return apr_hash object but dict, and its contents is neither
#  svn_fs_path_change2_t nor svn_fs_path_change_t object but python
#  object, which cannot be used for arguments for other svn wrapper APIs
#  directly)
def svn_fs_paths_changed(
        svn_fs_root_t root, result_pool=None, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    IF SVN_API_VER >= (1, 10):
        cdef _svn.Apr_Pool tmp_pool
        cdef _c_.svn_fs_path_change_iterator_t * _c_iterator
        cdef _c_.svn_fs_path_change3_t * _c_change
        cdef object copyfrom_path
        cdef object changed_path
    ELSE:
        cdef _svn.Apr_Pool r_pool
        cdef _svn.HashTrans pt_trans

    IF SVN_API_VER >= (1, 10):
        if scratch_pool is not None:
            assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
            tmp_pool = _svn.Apr_Pool(scratch_pool)
        else:
            (<_svn.Apr_Pool>_svn._scratch_pool).clear()
            tmp_pool = _svn.Apr_Pool(_svn._scratch_pool)

        change = {}
        # If Suversion C API >= 1.10, our result doesn't content
        # any object allocate from pool, so we can use tmp_pool safely
        serr = _c_.svn_fs_paths_changed3(
                        &_c_iterator, root._c_ptr,
                        tmp_pool._c_pool, tmp_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        serr = _c_.svn_fs_path_change_get(&_c_change, _c_iterator)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        while _c_change is not NULL:
            copyfrom_path = (<bytes>(_c_change[0].copyfrom_path)
                                if _c_change[0].copyfrom_path is not NULL
                                else None)
            changed_path = (_c_change[0].path.data)[:_c_change[0].data.len]
            IF PY_VERSION >= (3, 0, 0):
                copyfrom_path = _svn._norm(copyfrom_path)
                changed_path  = _svn._norm(changed_path)
            change[changed_path] = \
                FsPathChange(_c_change[0].change_kind,
                             _c_change[0].node_kind,
                             _c_change[0].text_mod,
                             _c_change[0].prop_mod,
                             _c_change[0].mergeinfo_mod,
                             _c_change[0].copyfrom_known,
                             copyfrom_path)
            serr = _c_.svn_fs_path_change_get(&_c_change, _c_iterator)
            if serr is not NULL:
                pyerr = _svn.Svn_error().seterror(serr)
                raise _svn.SVNerr(pyerr)
    ELSE:
        # As svn_fs_id_t object shall be allocated from result_pool
        # as a part of content of svn_fs_change2_t or svn_fs_change_t,
        # we must let FsPathChangeTrans know where it is allocated from.
        if result_pool is not None:
            assert (<_svn.Apr_Pool?>result_pool)._c_pool is not NULL
            r_pool = result_pool
        else:
            r_pool = _svn._root_pool
        pt_trans = HashTrans(CstringTransStr(),
                             FsPathChangeTrans(r_pool, scratch_pool),
                             scratch_pool)
        IF SVN_API_VER >= (1, 6):
            serr = _c_.svn_fs_paths_changed2(
                        <_c_.apr_hash_t **>(pt_trans.ptr_ref()),
                        root._c_ptr, r_pool._c_pool)
        ELSE:
            serr = _c_.svn_fs_paths_changed(
                        <_c_.apr_hash_t **>(pt_trans.ptr_ref()),
                        root._c_ptr, r_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        change = pt_trans.to_object()

    return change


cdef class NodeKindTrans(_svn.TransPtr):
    cdef object to_object(self):
        return self._c_kind
    cdef void set_c_kind(self, _c_.svn_node_kind_t _c_kind):
        self._c_kind = _c_kind
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_kind)


def svn_fs_check_path(
        svn_fs_root_t root, object path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_check_path,
                NodeKindTrans(),
                root, path, scratch_pool)


cdef class svn_fs_history_t(object):
    # cdef _c_.svn_fs_history_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
        self.pool = None
    cdef set_history(self, _c_.svn_fs_history_t * history, object pool):
        assert pool is None or isinstance(pool, _svn.Apr_Pool)
        self.pool = pool
        self._c_ptr = history
        return self


# warn: though result_pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until
# the program terminates. (scratch_pool is used only if API version >= 1.9)
def svn_fs_node_history(
        svn_fs_root_t root, object path, result_pool=None, scratch_pool=None):
    cdef const char * _c_path
    cdef _c_.svn_fs_history_t * _c_history
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _svn.Apr_Pool r_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    _c_path = <const char *>path

    if result_pool is not None:
        assert (<_svn.Apr_Pool>result_pool)._c_pool is not NULL
        r_pool = result_pool
    else:
        r_pool = _svn._root_pool
    IF SVN_API_VER >= (1, 9):
        if scratch_pool is not None:
            assert (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
        else:
            (<_svn.Apr_Pool>_svn._scratch_pool).clear()
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool,
                        (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
        if ast:
            raise _svn.PoolError()
    try:
        IF SVN_API_VER >= (1, 9):
            serr = _c_.svn_fs_node_history2(
                            &_c_history, root._c_ptr, _c_path,
                            r_pool._c_pool, _c_tmp_pool)
        ELSE:
            serr = _c_.svn_fs_node_history(
                            &_c_history, root._c_ptr, _c_path,
                            r_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        IF SVN_API_VER >= (1, 9):
            _c_.apr_pool_destroy(_c_tmp_pool)
        ELSE:
            pass
    return svn_fs_history_t().set_history(_c_history, r_pool)

# warn: though result_pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until
# the program terminates. (scratch_pool is used only if API version >= 1.9)
def svn_fs_history_prev(
        svn_fs_history_t history, object cross_copies,
        result_pool=None, scratch_pool=None):
    cdef _c_.svn_fs_history_t * _c_prev
    cdef _c_.svn_boolean_t _c_cross_copies
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _svn.Apr_Pool r_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if result_pool is not None:
        assert (<_svn.Apr_Pool>result_pool)._c_pool is not NULL
        r_pool = result_pool
    else:
        r_pool = _svn._root_pool
    _c_cross_copies = True if cross_copies else False
    IF SVN_API_VER >= (1, 9):
        if scratch_pool is not None:
            assert (<_svn.Apr_Pool>scratch_pool)._c_pool is not NULL
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
        else:
            (<_svn.Apr_Pool>_svn._scratch_pool).clear()
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool,
                        (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
        if ast:
            raise _svn.PoolError()
    try:
        IF SVN_API_VER >= (1, 9):
            serr = _c_.svn_fs_history_prev2(
                            &_c_prev, history._c_ptr, _c_cross_copies,
                            r_pool._c_pool, _c_tmp_pool)
        ELSE:
            serr = _c_.svn_fs_history_prev(
                            &_c_prev, history._c_ptr, _c_cross_copies,
                            r_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        IF SVN_API_VER >= (1, 9):
            _c_.apr_pool_destroy(_c_tmp_pool)
        ELSE:
            pass
    return svn_fs_history_t().set_history(_c_prev, r_pool)


def svn_fs_history_location(svn_fs_history_t history, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_revnum_t revision
    cdef const char * _c_path
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool,
                        (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
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


def svn_fs_is_dir(svn_fs_root_t root, object path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_is_dir,
                _svn.SvnBooleanTrans(),
                root, path, scratch_pool)


def svn_fs_is_file(svn_fs_root_t root, object path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_is_file,
                _svn.SvnBooleanTrans(),
                root, path, scratch_pool)


# warn: though result_pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until
# the program terminates.
def svn_fs_node_id(svn_fs_root_t root, object path, result_pool=None):
    cdef _svn.Apr_Pool r_pool
    cdef const char * _c_path
    cdef _c_.svn_fs_id_t * _c_id
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    _c_path = <const char *>path

    if result_pool is not None:
        assert (<_svn.Apr_Pool?>result_pool)._c_pool is not NULL
        r_pool = result_pool
    else:
        r_pool = _svn._root_pool
    serr = _c_.svn_fs_node_id(
                    <const _c_.svn_fs_id_t **>&_c_id,
                    root._c_ptr, _c_path, r_pool._c_pool)
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    return svn_fs_id_t().set_fs_id(_c_id, r_pool)

def svn_fs_node_created_rev(
        svn_fs_root_t root, object path, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef const char * _c_path
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_revnum_t _c_revision
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    _c_path = <const char *>path

    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool,
                        (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
    try:
        serr = _c_.svn_fs_node_created_rev(
                    &_c_revision, root._c_ptr, _c_path, _c_tmp_pool)
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
        svn_fs_root_t root, object path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_node_proplist,
                _svn.HashTrans(_svn.CStringTransStr(),
                               _svn.SvnStringTransStr(),
                               scratch_pool),
                root, path, scratch_pool)


def svn_fs_copied_from(
        svn_fs_root_t root, object path, scratch_pool=None):
    cdef const char * _c_path
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_revnum_t _c_rev
    cdef const char * _c_from_path
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    _c_path = <const char *>path

    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        _svn._scratch_pool.clear()
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool,
                        (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
    try:
        serr = _c_.svn_fs_copied_from(
                        &_c_rev, &_c_from_path, root._c_ptr, path, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        from_path = _c_from_path if _c_from_path is not NULL else None
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return _c_rev, from_path


class VCDirEntry(object):
    def __init__(self, name, kind):
        IF PY_VERSION >= (3, 0, 0):
            self.name = _svn._norm(name)
        ELSE:
            self.name = name
        self.kind = kind

# transform content of svn_fs_dirent_t into Python object.
# We don't need node_rev_id member here.
# As I don't want to import vclib here, translation map of node kind is
# needed to be passed by caller.
cdef class _VCDirEntryTrans(_svn.TransPtr):
    cdef _c_.svn_fs_dirent_t *_c_dirent
    cdef dict kind_map
    def __init__(self, kind_map, **m):
        self.kind_map = kind_map
    cdef object to_object(self):
        cdef object name
        name = (self._c_dirent)[0].name
        kind = self.kind_map.get((self._c_dirent)[0].kind, None)
        return VCDirEntry(name, kind)
    cdef void set_c_dirent(
            self, _c_.svn_fs_dirent_t *_c_dirent):
        self._c_dirent = _c_dirent
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_dirent)

def _listdir_helper(
        svn_fs_root_t root, object path, object kind_map,
        scratch_pool=None):
    assert isinstance(kind_map, dict)
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_dir_entries,
                _svn.HashTrans(_svn.CStringTransBytes(),
                               _VCDirEntryTrans(kind_map),
                               scratch_pool),
                root, path, scratch_pool)


cdef class FileSizeTrans(_svn.TransPtr):
    cdef object to_object(self):
        return <object>(self._c_fsize)
    cdef void set_filesize(self, _c_.svn_filesize_t _c_fsize):
        self._c_fsize = _c_fsize
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_fsize)

def svn_fs_file_length(
        svn_fs_root_t root, object path, scratch_pool=None):
    return _apply_svn_api_root_path_arg1(
                <svn_rv1_root_path_func_t>_c_.svn_fs_file_length,
                FileSizeTrans(),
                root, path, scratch_pool)

# warn: though pool is optional, ommiting to specify it causes
# allocation from global pool, and not releases its allocation until
# the program terminates.
def svn_fs_file_contents(svn_fs_root_t root, object path, pool=None):
    cdef const char * _c_path
    cdef _c_.apr_status_t ast
    cdef _svn.Apr_Pool r_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef _c_.svn_stream_t * _c_contents
    cdef _svn.svn_stream_t contents

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    _c_path = <const char *>path

    if pool is not None:
        assert (<_svn.Apr_Pool?>pool)._c_pool is not NULL
        r_pool = pool
    else:
        r_pool = _svn._root_pool
    serr = _c_.svn_fs_file_contents(
                    &_c_contents, root._c_ptr, _c_path, r_pool._c_pool)
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    contents = _svn.svn_stream_t()
    contents.set_stream(_c_contents, r_pool)
    return contents


def svn_fs_youngest_rev(svn_fs_t fs, scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_revnum_t _c_rev
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool,
                        (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
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
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool,
                        (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
    try:
        prop_trans = _svn.HashTrans(_svn.CStringTransStr(),
                                    _svn.SvnStringTransStr(), scratch_pool)
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
cdef class SvnLock(object):
    def __init__(
             self, object path, object token, object owner, object comment,
             _c_.svn_boolean_t is_dav_comment,
             _c_.apr_time_t creation_date, _c_.apr_time_t expiration_date):
        self.path = path
        self.token = token
        self.owner = owner
        self.comment = comment
        self.is_dav_comment = is_dav_comment
        self.creation_date = creation_date
        self.expiration_date = expiration_date


cdef object _svn_lock_to_object(const _c_.svn_lock_t * _c_lock):
    cdef object path
    cdef object token
    cdef object owner
    cdef object comment
    if _c_lock is NULL:
        return None
    else:
        if _c_lock[0].path is NULL:
            path = None
        else:
            path = <bytes>(_c_lock[0].path)
            IF PY_VERSION >= (3, 0, 0):
                path = _svn._norm(path)
        if _c_lock[0].token is NULL:
            token = None
        else:
            token = <bytes>(_c_lock[0].token)
            IF PY_VERSION >= (3, 0, 0):
                token = _svn._norm(token)
        if _c_lock[0].owner is NULL:
            owner = None
        else:
            owner = <bytes>(_c_lock[0].owner)
            IF PY_VERSION >= (3, 0, 0):
                owner = _svn._norm(owner)
        if _c_lock[0].comment is NULL:
            comment = None
        else:
            comment = <bytes>(_c_lock[0].comment)
            IF PY_VERSION >= (3, 0, 0):
                comment = _svn._norm(comment)
        is_dav_comment = (True if _c_lock[0].is_dav_comment != _c_.FALSE
                               else False)
        return SvnLock(path, token, owner, comment, is_dav_comment,
                       _c_lock[0].creation_date, _c_lock[0].expiration_date)


# warn: this function doesn't provide full functionally
# (not return a svn_lock_t object but pure Python SvnLock object.
#  So it cannot be used for arguments for other svn wrapper APIs directly)
def svn_fs_get_lock(svn_fs_t fs, object path, scratch_pool=None):
    cdef const char * _c_path
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef _c_.svn_lock_t * _c_lock

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    _c_path = <const char *>path

    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(
                        &_c_tmp_pool,
                        (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
    try:
        serr = _c_.svn_fs_get_lock(
                        &_c_lock, fs._c_ptr, _c_path, _c_tmp_pool)
        lock = _svn_lock_to_object(_c_lock)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return lock


cdef class svn_repos_t(object):
    # cdef _c_.svn_repos_t * _c_ptr
    def __cinit__(self):
        self._c_ptr = NULL
        self.pool = None
    cdef svn_repos_t set_repos(
            svn_repos_t self, _c_.svn_repos_t * repos, object pool):
        assert (<_svn.Apr_Pool?>pool)._c_pool is not NULL
        self._c_ptr = repos
        self.pool = pool
        return self

# this is only for svn_repos.py{x}, does not provide full function
# but try to newer API.
def svn_repos_open(const char * path, result_pool=None, scratch_pool=None):
    cdef _c_.svn_repos_t * _c_repos
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _svn.Apr_Pool r_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if result_pool is not None:
        assert (<_svn.Apr_Pool?>result_pool)._c_pool is not NULL
        r_pool = result_pool
    else:
        r_pool = _svn._root_pool
    IF SVN_API_VER >= (1, 9):
        if scratch_pool is not None:
            assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool, (<_svn.Apr_Pool>scratch_pool)._c_pool)
        else:
            (<_svn.Apr_Pool?>_svn._scratch_pool).clear()
            ast = _c_.apr_pool_create(
                        &_c_tmp_pool,
                        (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
        if ast:
            raise _svn.PoolError()
    try:
        IF SVN_API_VER >= (1, 9):
            serr = _c_.svn_repos_open3(
                        &_c_repos, path, NULL, r_pool._c_pool, _c_tmp_pool)
        ELIF SVN_API_VER >= (1, 7):
            serr = _c_.svn_repos_open2(
                        &_c_repos, path, NULL, r_pool._c_pool)
        ELSE:
            serr = _c_.svn_repos_open(
                        &_c_repos, path, r_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        IF SVN_API_VER >= (1, 9):
            _c_.apr_pool_destroy(_c_tmp_pool)
        ELSE:
            pass
    return svn_repos_t().set_repos(_c_repos, r_pool)


def svn_repos_fs(svn_repos_t repos):
    return svn_fs_t().set_fs(_c_.svn_repos_fs(repos._c_ptr), repos.pool)


cdef _c_.svn_error_t * _cb_svn_repos_authz_func_wrapper(
        _c_.svn_boolean_t * _c_allowed, _c_.svn_fs_root_t * _c_root,
        const char * _c_path, void * baton, _c_.apr_pool_t * _c_pool) with gil:
    cdef _svn.CbContainer btn
    cdef svn_fs_root_t root
    cdef object path
    cdef _svn.Apr_Pool pool
    cdef object allowed
    cdef object pyerr
    cdef _svn.Svn_error svnerr
    cdef _c_.svn_error_t * _c_err

    btn  = <_svn.CbContainer>baton
    root = svn_fs_root_t().set_fs_root(_c_root, None)
    path = <bytes>_c_path
    IF PY_VERSION >= (3, 0, 0):
        path = _svn._norm(path)
    pool = _svn.Apr_Pool.__new__(_svn.Apr_Pool, pool=None)
    pool.set_pool(_c_pool)
    _c_err = NULL
    try:
        allowed = btn.fnobj(root, path, btn.btn, pool)
        _c_allowed[0] = _c_.TRUE if allowed else _c_.FALSE
    except _svn.SVNerr as pyerr:
        svnerr = pyerr.svnerr
        _c_err = _c_.svn_error_dup(svnerr.geterror())
        del pyerr
    except AssertionError as err:
        _c_err = _c_.svn_error_create(
                    _c_.SVN_ERR_ASSERTION_FAIL, NULL, str(err))
    except KeyboardInterrupt as err:
        _c_err = _c_.svn_error_create(
                    _c_.SVN_ERR_CANCELLED, NULL, str(err))
    except BaseException as err:
        _c_err = _c_.svn_error_create(
                    _c_.SVN_ERR_BASE, NULL, str(err))
    return _c_err


def svn_repos_trace_node_locations(
        svn_fs_t fs, object fs_path, _c_.svn_revnum_t peg_revision,
        object location_revisions, object authz_read_func,
        object authz_read_baton, object scratch_pool=None):
    cdef const char * _c_fs_path
    cdef _c_.apr_status_t ast
    cdef _svn.Apr_Pool tmp_pool
    cdef _c_.apr_array_header_t * _c_location_rivisions
    cdef _svn.CbContainer btn
    cdef _svn.SvnRevnumPtrTrans revtrans
    cdef _svn.CStringTransBytes transbytes
    cdef _svn.HashTrans loctrans
    cdef _c_.svn_error_t * serr
    cdef object locations

    # make sure fs_path is a bytes object
    if isinstance(fs_path, PathLike):
        fs_path = fs_path.__fspath__()
    if not isinstance(fs_path, bytes) and isinstance(fs_path, str):
        fs_path = fs_path.encode('utf-8')
    _c_fs_path = <const char *>fs_path

    assert callable(authz_read_func)
    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        tmp_pool = _svn.Apr_Pool(scratch_pool)
    else:
        tmp_pool = _svn.Apr_Pool(_svn._scratch_pool)
    try:
        _c_location_revisions = _svn.make_revnum_array(location_revisions,
                                                       tmp_pool._c_pool)
        btn = _svn.CbContainer(authz_read_func, authz_read_baton, tmp_pool)
        loctrans = _svn.HashTrans(_svn.SvnRevnumPtrTrans(),
                                  _svn.CStringTransBytes(),
                                  tmp_pool)
        serr = _c_.svn_repos_trace_node_locations(
                    fs._c_ptr, <_c_.apr_hash_t **>(loctrans.ptr_ref()),
                    _c_fs_path, peg_revision, _c_location_revisions,
                    _cb_svn_repos_authz_func_wrapper, <void *>btn,
                    tmp_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        locations = loctrans.to_object()
    finally:
        del tmp_pool
    return locations


# vclib custom revinfo helper
# copy from subversion/bindings/swig/python/svn/repos.py, class ChangedPath,
# with Cython and customize for vclib.svn.svn_repos
cdef class _ChangedPath(object):
    # cdef _c_.svn_node_kind_t item_kind
    # cdef _c_.svn_boolean_t prop_changes
    # cdef _c_.svn_boolean_t text_changed
    # cdef object base_path # (bytes for Python 2, str for Python 3)
    # cdef _c_.svn_revnum_t base_rev
    # cdef object path      # (bytes for Python 2, str for Python 3)
    # cdef _c_.svn_boolean_t added
    ### we don't use 'None' action
    # cdef _c_.svn_fs_path_change_kind_t action
    def __init__(self,
                 _c_.svn_node_kind_t item_kind,
                 _c_.svn_boolean_t prop_changes,
                 _c_.svn_boolean_t text_changed,
                 object base_path, _c_.svn_revnum_t base_rev,
                 object path, _c_.svn_boolean_t added,
                 _c_.svn_fs_path_change_kind_t action):
        self.item_kind = item_kind
        self.prop_changes = prop_changes
        self.text_changed = text_changed
        self.base_path = base_path
        self.base_rev = base_rev
        self.path = path
        self.added = added
        self.action = action

cdef const char * _c_make_base_path(
            const char * parent_path, const char * path,
            _c_.apr_pool_t * pool):
    cdef const char * cpivot
    cdef char * pivot
    cdef size_t p_len
    cdef int need_slash
    cdef const char * bnh # base name head
    cdef size_t b_len
    cdef char * new_base

    p_len = 0
    if parent_path[0] == 0:
        need_slash = 0
    else:
        cpivot = parent_path
        p_len += 1
        while cpivot[1] != 0:
            p_len += 1
            cpivot += 1
        if cpivot[0] != 47: # 47 == ord('/')
            need_slash = 1
    bnh = path
    cpivot = path
    while cpivot[0] != 0:
        if cpivot[0] == 47:
            bnh = cpivot + 1
        cpivot += 1
    b_len = cpivot - bnh
    new_base = <char *>_c_.apr_palloc(pool, (p_len + need_slash + b_len + 1))
    if new_base == NULL:
        return NULL
    if p_len:
        memcpy(<void *>new_base, <const void *>parent_path, p_len)
    pivot = new_base + p_len
    if need_slash:
        pivot[0] = <char>47
        pivot += 1
    if b_len:
        memcpy(<void *>pivot, <const void *>bnh, b_len)
    pivot[b_len] = <char>0
    return <const char *>new_base


cdef class _get_changed_paths_EditBaton(object):
    def __init__(self, svn_fs_t fs_ptr, svn_fs_root_t root):
        self.changes = {}
        self.fs_ptr = fs_ptr
        self.root = root
        # in vclib, svn_fs_root_t root is always revision root
        assert _c_.svn_fs_is_revision_root(root._c_ptr)
        self.base_rev = (
                _c_.svn_fs_revision_root_revision(root._c_ptr) - 1)
        # self._c_p_pool is not initialized here, because this is
        # C pointer which cannot be passed through Pure Python function
    def _getroot(self, rev):
        return self.fs_ptr._getroot(rev)


# custom call back functions used by get_changed_paths(), derived from
# subversion/bindings/swig/python/svn/repos.py, class ChangedCollector,
# with Cython
cdef _c_.svn_error_t * _cb_changed_paths_open_root(
        void * _c_edit_baton, _c_.svn_revnum_t base_revision,
        _c_.apr_pool_t * result_pool, void ** _c_root_baton) with gil:
    cdef _get_changed_paths_EditBaton eb
    cdef _get_changed_paths_DirBaton * rb
    cdef _c_.svn_error_t * _c_err

    eb = <_get_changed_paths_EditBaton>_c_edit_baton
    rb = <_get_changed_paths_DirBaton *>_c_.apr_palloc(
                eb._c_p_pool, sizeof(_get_changed_paths_DirBaton))
    if rb is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    rb[0].path = <const char *>_c_.apr_palloc(eb._c_p_pool, 1)
    if rb[0].path is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    (<char *>(rb[0].path))[0] = <char>0
    rb[0].base_path = rb[0].path
    rb[0].base_rev = eb.base_rev
    rb[0].edit_baton = <void *>eb
    _c_root_baton[0] = <void *>rb
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_delete_entry(
        const char * _c_path, _c_.svn_revnum_t revision,
        void * parent_baton, _c_.apr_pool_t * scratch_pool) with gil:
    cdef _get_changed_paths_DirBaton * pb
    cdef _get_changed_paths_EditBaton eb
    cdef bytes path
    cdef bytes base_path
    cdef const char * _c_base_path
    cdef _c_.svn_error_t * _c_err
    cdef _c_.svn_node_kind_t item_type

    pb = <_get_changed_paths_DirBaton *>parent_baton
    eb = <_get_changed_paths_EditBaton>(pb[0].edit_baton)
    path = <bytes>_c_path
    IF PY_VERSION >= (3, 0, 0):
        path = _svn._norm(path)
    _c_base_path = _c_make_base_path(pb[0].base_path, _c_path, scratch_pool)
    if _c_base_path is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    base_path = <bytes>_c_base_path
    if svn_fs_is_dir(eb._getroot(pb.base_rev), base_path):
        item_type = _c_.svn_node_dir
    else:
        item_type = _c_.svn_node_file
    IF PY_VERSION >= (3, 0, 0):
        base_path = _svn._norm(base_path)
    eb.changes[path] = _ChangedPath(item_type,
                                    _c_.FALSE,
                                    _c_.FALSE,
                                    base_path,
                                    pb[0].base_rev,
                                    path,
                                    _c_.FALSE,
                                    _c_.svn_fs_path_change_delete)
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_add_directory(
        const char * _c_path, void * parent_baton,
        const char * _c_copyfrom_path, _c_.svn_revnum_t copyfrom_revision,
        _c_.apr_pool_t * result_pool, void ** child_baton) with gil:
    cdef _get_changed_paths_DirBaton * pb
    cdef _get_changed_paths_EditBaton eb
    cdef bytes path
    cdef object copyfrom_path
    cdef _get_changed_paths_DirBaton * cb
    cdef _c_.svn_error_t * _c_err
    cdef _c_.svn_fs_path_change_kind_t action

    pb = <_get_changed_paths_DirBaton *>parent_baton
    eb = <_get_changed_paths_EditBaton>(pb[0].edit_baton)
    path = _c_path
    path = <bytes>_c_path
    IF PY_VERSION >= (3, 0, 0):
        path = _svn._norm(path)
    if _c_copyfrom_path is NULL:
        copyfrom_path = None
    else:
        copyfrom_path = <bytes>_c_copyfrom_path
        IF PY_VERSION >= (3, 0, 0):
            copyfrom_path = _svn._norm(copyfrom_path)
    if path in eb.changes:
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
    if copyfrom_path and (copyfrom_revision >= 0):
        _c_base_path = _c_copyfrom_path
    else:
        _c_base_path = _c_path
    cb = <_get_changed_paths_DirBaton *>_c_.apr_palloc(
                eb._c_p_pool, sizeof(_get_changed_paths_DirBaton))
    if cb is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    cb[0].path = _c_.apr_pstrdup(eb._c_p_pool, _c_path)
    if cb[0].path is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    cb[0].base_path = _c_.apr_pstrdup(eb._c_p_pool, _c_base_path)
    if cb[0].base_path is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    cb[0].base_rev = <_c_.svn_revnum_t>copyfrom_revision
    cb[0].edit_baton = <void *>eb
    child_baton[0] = <void *>cb
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_open_directory(
            const char * _c_path, void * parent_baton,
            _c_.svn_revnum_t base_revision,
            _c_.apr_pool_t * result_pool, void ** child_baton) with gil:
    cdef _get_changed_paths_DirBaton * pb
    cdef _get_changed_paths_EditBaton eb
    cdef _get_changed_paths_DirBaton * cb
    cdef _c_.svn_error_t * _c_err

    pb = <_get_changed_paths_DirBaton *>parent_baton
    eb = <_get_changed_paths_EditBaton>(pb[0].edit_baton)
    cb = <_get_changed_paths_DirBaton *>_c_.apr_palloc(
                eb._c_p_pool, sizeof(_get_changed_paths_DirBaton))
    if cb is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    cb[0].path = _c_.apr_pstrdup(eb._c_p_pool, _c_path)
    if cb[0].path is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    cb[0].base_path = _c_make_base_path(
                                pb[0].base_path, _c_path, eb._c_p_pool)
    if cb[0].base_path is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    cb[0].base_rev = pb[0].base_rev
    cb[0].edit_baton = <void *>eb
    child_baton[0] = <void *>cb
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_change_dir_prop(
            void * dir_baton, const char * name,
            const _c_.svn_string_t * value,
            _c_.apr_pool_t * scratch_pool) with gil:
    cdef _get_changed_paths_DirBaton * db
    cdef _get_changed_paths_EditBaton eb
    cdef object db_path
    cdef object db_base_path
    db = <_get_changed_paths_DirBaton *>dir_baton
    eb = <_get_changed_paths_EditBaton>(db[0].edit_baton)
    db_path = <bytes>(db[0].path)
    IF PY_VERSION >= (3, 0, 0):
        db_path = _svn.norm(db_path)
    if db_path in eb.changes:
        (<_ChangedPath>(eb.changes[db_path])).prop_changes = _c_.TRUE
    else:
        # can't be added or deleted, so this must be CHANGED
        if db[0].base_path is NULL:
            db_base_path = None
        else:
            db_base_path = <bytes>(db[0].base_path)
            IF PY_VERSION >= (3, 0, 0):
                db_base_path = _svn._norm(db_base_path)
        eb.changes[db_path] = _ChangedPath(
                                    _c_.svn_node_dir,
                                    _c_.TRUE,
                                    _c_.FALSE,
                                    db_base_path,
                                    db[0].base_rev,
                                    db_path,
                                    _c_.FALSE,
                                    _c_.svn_fs_path_change_modify)
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_add_file(
            const char * _c_path, void * parent_baton,
            const char * _c_copyfrom_path,
            _c_.svn_revnum_t copyfrom_revision,
            _c_.apr_pool_t * result_pool, void ** file_baton) with gil:
    cdef _get_changed_paths_DirBaton * pb
    cdef _get_changed_paths_EditBaton eb
    cdef bytes path
    cdef object copyfrom_path
    cdef _get_changed_paths_DirBaton * fb
    cdef _c_.svn_fs_path_change_kind_t action
    cdef _c_.svn_error_t * _c_err

    pb = <_get_changed_paths_DirBaton *>parent_baton
    eb = <_get_changed_paths_EditBaton >(pb[0].edit_baton)
    path = <bytes>_c_path
    IF PY_VERSION >= (3, 0, 0):
        path = _svn._norm(path)
    if path in eb.changes:
        action = _c_.svn_fs_path_change_replace
    else:
        action = _c_.svn_fs_path_change_add
    if _c_copyfrom_path is NULL:
        copyfrom_path = None
    else:
        copyfrom_path = _c_copyfrom_path
        IF PY_VERSION >= (3, 0, 0):
            copyfrom_path = _svn._norm(copyfrom_path)
    eb.changes[path] = _ChangedPath(_c_.svn_node_file,
                                    _c_.FALSE,
                                    _c_.FALSE,
                                    copyfrom_path,
                                    copyfrom_revision,
                                    path,
                                    _c_.TRUE,
                                    action)
    if copyfrom_path is not None and (copyfrom_revision >= 0):
        _c_base_path = _c_copyfrom_path
    else:
        _c_base_path = _c_path
    fb = <_get_changed_paths_DirBaton *>_c_.apr_palloc(
                result_pool, sizeof(_get_changed_paths_DirBaton))
    if fb is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    fb[0].path = _c_.apr_pstrdup(eb._c_p_pool, _c_path)
    if fb[0].path is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    fb[0].base_path = _c_.apr_pstrdup(eb._c_p_pool, _c_base_path)
    if fb[0].base_path is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    fb[0].base_rev = copyfrom_revision
    fb[0].edit_baton = <void *>eb
    file_baton[0] = <void *>fb
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_open_file(
            const char * _c_path, void * parent_baton,
            _c_.svn_revnum_t base_revision,
            _c_.apr_pool_t * result_pool, void ** file_baton) with gil:
    cdef _get_changed_paths_DirBaton * pb
    cdef _get_changed_paths_EditBaton eb
    cdef _get_changed_paths_DirBaton * fb
    cdef _c_.svn_error_t * _c_err

    pb = <_get_changed_paths_DirBaton *>parent_baton
    eb = <_get_changed_paths_EditBaton >(pb[0].edit_baton)
    fb = <_get_changed_paths_DirBaton *>_c_.apr_palloc(
                result_pool, sizeof(_get_changed_paths_DirBaton))
    if fb is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    fb[0].path = _c_.apr_pstrdup(eb._c_p_pool, _c_path)
    if fb[0].path is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    fb[0].base_path = _c_make_base_path(
                                pb[0].base_path, _c_path, eb._c_p_pool)
    if fb[0].base_path is NULL:
         _c_err = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
         return _c_err
    fb[0].base_rev = pb[0].base_rev
    fb[0].edit_baton = <void *>eb
    file_baton[0] = <void *>fb
    return NULL

cdef _c_.svn_error_t * _null_svn_texdelta_window_handler(
            _c_.svn_txdelta_window_t * window, void * baton) nogil:
    return NULL

cdef _c_.svn_error_t * _cb_changed_paths_apply_textdelta(
            void * file_baton, const char * base_checksum,
            _c_.apr_pool_t * result_pool,
            _c_.svn_txdelta_window_handler_t * handler,
            void ** handler_baton) with gil:
    cdef _get_changed_paths_DirBaton * fb
    cdef _get_changed_paths_EditBaton eb
    cdef object fb_path
    cdef object fb_base_path
    fb = <_get_changed_paths_DirBaton*>file_baton
    eb = <_get_changed_paths_EditBaton>(fb[0].edit_baton)
    fb_path = <bytes>(fb[0].path)
    fb_base_path = <bytes>(fb[0].base_path)
    IF PY_VERSION >= (3, 0, 0):
        fb_path = _svn._norm(fb_path)
        fb_base_path = _svn._norm(fb_base_path)
    if fb_path in eb.changes:
        (<_ChangedPath>(eb.changes[fb_path])).text_changed = _c_.TRUE
    else:
        eb.changes[fb_path] = _ChangedPath(
                                    _c_.svn_node_file,
                                    _c_.FALSE,
                                    _c_.TRUE,
                                    fb_base_path,
                                    fb[0].base_rev,
                                    fb_path,
                                    _c_.FALSE,
                                    _c_.svn_fs_path_change_modify)
    # we know no handlers to be set
    handler[0] = _null_svn_texdelta_window_handler
    handler_baton[0] = NULL
    return NULL

cdef  _c_.svn_error_t * _cb_changed_paths_change_file_prop(
            void * file_baton, const char * name,
            const _c_.svn_string_t * value,
            _c_.apr_pool_t * scratch_pool) with gil:
    cdef _get_changed_paths_DirBaton * fb
    cdef _get_changed_paths_EditBaton eb
    cdef object fb_path
    cdef object fb_base_path
    fb = <_get_changed_paths_DirBaton *>file_baton
    eb = <_get_changed_paths_EditBaton >(fb[0].edit_baton)
    fb_path = <bytes>(fb[0].path)
    fb_base_path = <bytes>(fb[0].base_path)
    IF PY_VERSION >= (3, 0, 0):
        fb_path = _svn._norm(fb_path)
        fb_base_path = _svn._norm(fb_base_path)
    if fb_path in eb.changes:
        (<_ChangedPath>(eb.changes[fb_path])).prop_changes = _c_.TRUE
    else:
        # can't be added or deleted, so this must be CHANGED
        eb.changes[fb_path] = _ChangedPath(
                                    _c_.svn_node_file,
                                    _c_.TRUE,
                                    _c_.FALSE,
                                    fb_base_path,
                                    fb[0].base_rev,
                                    fb_path,
                                    _c_.FALSE,
                                    _c_.svn_fs_path_change_modify)
    return NULL

def _get_changed_paths_helper(
        svn_fs_t fs, svn_fs_root_t fsroot, object pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.svn_error_t * serr
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.apr_pool_t * _c_p_pool
    cdef _c_.svn_delta_editor_t * editor
    cdef _get_changed_paths_EditBaton eb
    cdef _svn.Svn_error pyerr
    IF SVN_API_VER >= (1, 4):
        cdef bytes base_dir

    if pool is not None:
        assert ((<_svn.Apr_Pool?>pool)._c_pool is not NULL)
        ast = _c_.apr_pool_create(
                    &_c_tmp_pool, (<_svn.Apr_Pool>pool)._c_pool)
        if ast:
            raise _svn.PoolError()
        ast = _c_.apr_pool_create(
                    &_c_p_pool, (<_svn.Apr_Pool>pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(
                    &_c_tmp_pool,
                    (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
        if ast:
            raise _svn.PoolError()
        ast = _c_.apr_pool_create(
                    &_c_p_pool,
                    (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        _c_.apr_pool_destroy(_c_tmp_pool)
        raise _svn.PoolError()
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
        eb._c_p_pool = _c_p_pool
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
        _c_.apr_pool_destroy(_c_p_pool)
        _c_.apr_pool_destroy(_c_tmp_pool)
    return eb.changes


# Cython version of vclib.svn.svn_repos.NodeHistory class
# (used as history baton on svn_repos_history2 call)
cdef class NodeHistory(object):
    """A history baton object that builds list of 2-tuple (revision, path)
    locations along a node's change history, orderd from youngest to
    oldest."""
    cdef public list histories
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
    cdef object path
    cdef svn_fs_root_t rev_root
    cdef bytes test_path
    cdef _c_.svn_boolean_t found
    cdef object off
    cdef _c_.svn_revnum_t copyfrom_rev
    cdef object copyfrom_path
    cdef _c_.svn_error_t * serr
    cdef _svn.Apr_Pool wrap_pool
    btn = <NodeHistory>baton
    wrap_pool = _svn.Apr_Pool.__new__(_svn.Apr_Pool,None)
    wrap_pool.set_pool(pool)
    if btn.oldest_rev == _c_.SVN_INVALID_REVNUM:
        btn.oldest_rev = revision
    else:
        assert revision < btn.oldest_rev
    path = <bytes>_c_path
    IF PY_VERSION >= (3, 0, 0):
        path = _svn._norm(path)
    if btn.show_all_logs == _c_.FALSE:
        rev_root = btn.fs_ptr._getroot(revision)
        changed_paths = svn_fs_paths_changed(rev_root, wrap_pool)
        if path not in changed_paths:
            # Look for a copied parent
            test_path = path
            found = _c_.FALSE
            off = test_path.rfind('/')
            while off >= 0:
                test_path = test_path[0:off]
                if test_path in changed_paths:
                    copyfrom_rev, copyfrom_path = \
                            svn_fs_copied_from(rev_root, test_path, wrap_pool)
                    if copyfrom_rev >= 0 and copyfrom_path:
                        found = _c_.TRUE
                        break
                off = test_path.rfind('/')
            if found == _c_.FALSE:
                return NULL
    btn.histories.append([revision,
                          '/'.join([pp for pp in path.split('/') if pp])])
    btn._item_cnt += 1
    if btn.limit and btn._item_cnt >= btn.limit:
        IF SVN_API_VER >= (1, 5):
            serr = _c_.svn_error_create(
                        _c_.SVN_ERR_CEASE_INVOCATION, NULL, NULL)
        ELSE:
            serr = _c_.svn_error_create(
                        _c_.SVN_ERR_CANCELLED, NULL, NULL)
        return serr
    return NULL

def _get_history_helper(
            svn_fs_t fs_ptr, object path,
            _c_.svn_revnum_t rev, _c_.svn_boolean_t cross_copies,
            _c_.svn_boolean_t show_all_logs,
            _c_.svn_revnum_t limit, pool=None):
    cdef const char * _c_path
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef NodeHistory nhbtn

    # make sure path is a bytes object
    if isinstance(path, PathLike):
        path = path.__fspath__()
    if not isinstance(path, bytes) and isinstance(path, str):
        path = path.encode('utf-8')
    _c_path = <const char *>path

    nhbtn = NodeHistory(fs_ptr, show_all_logs, limit)
    if pool is not None:
        assert (<_svn.Apr_Pool?>pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(
                    &_c_tmp_pool, (<_svn.Apr_Pool>pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(
                    &_c_tmp_pool,
                    (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
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
