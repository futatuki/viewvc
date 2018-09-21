include "_svn_api_ver.pxi"
cimport _svn_repos_capi as _c_
cimport _svn
cimport _svn_fs
import _svn
import _svn_fs

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
    return _svn_fs.svn_fs_t().set_fs(_c_.svn_repos_fs(repos._c_ptr))

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
    cdef _svn_fs.svn_fs_t fs_ptr
    cdef _svn_fs.svn_fs_root_t root
    cdef _c_.svn_revnum_t base_rev
    def __init__(self, _svn_fs.svn_fs_t fs_ptr, _svn_fs.svn_fs_root_t root):
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
    if _svn_fs.svn_fs_is_dir(eb._get_root(pb.base_rev), base_path):
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
        _svn_fs.svn_fs_t fs, _svn_fs.svn_fs_root_t fsroot, object pool=None):
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
    cdef _svn_fs.svn_fs_t fs_ptr
    cdef _c_.svn_boolean_t show_all_logs 
    cdef _c_.svn_revnum_t oldest_rev
    cdef _c_.svn_revnum_t limit
    def __init__(self, _svn_fs.svn_fs_t fs_ptr,
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
    cdef _svn_fs.svn_fs_root_t rev_root
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
        changed_paths = _svn_fs.svn_fs_paths_changed(rev_root)
        if path not in changed_paths:
            # Look for a copied parent
            test_path = path
            found = _c_.FALSE
            off = test_path.rfind(b'/')
            while off >= 0: 
                test_path = test_path[0:off]
                if test_path in changed_paths:
                    copyfrom_rev, copyfrom_path = \
                            _svn_fs.svn_fs_copied_from(rev_root, test_path)
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
            _svn_fs.svn_fs_t fs_ptr, const char * path,
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
