include "_svn_api_ver.pxi"
include "_py_ver.pxi"
cimport _svn_ra_capi as _c_
cimport _svn
cimport _svn_repos
from . import _svn
IF PY_VERSION >= (3, 0, 0):
    from . import _norm

def _ra_init():
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    serr = _c_.svn_ra_initialize(_svn._root_pool._c_pool)
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)

_ra_init()
del _ra_init


cdef class svn_ra_session_t(object):
    # cdef _c_.svn_ra_session_t * _c_session
    # cdef _svn.Apr_Pool pool
    cdef svn_ra_session_t set_session(
            self, _c_.svn_ra_session_t * _c_session, pool):
        assert pool is None or (<_svn.Apr_Pool?>pool)._c_pool is not NULL
        self.pool = pool
        assert _c_session is not NULL
        self._c_session = _c_session
        return self


def svn_ra_get_latest_revnum(svn_ra_session_t session, scratch_pool=None):
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.apr_status_t ast
    cdef _c_.svn_revnum_t _c_rev
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
    try:
        serr = _c_.svn_ra_get_latest_revnum(
                    session._c_session, &_c_rev, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return _c_rev


def svn_ra_check_path(
        svn_ra_session_t session, const char * _c_path,
        _c_.svn_revnum_t _c_revision, object scratch_pool=None):
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef _c_.svn_node_kind_t _c_kind

    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
    try:
        serr = _c_.svn_ra_check_path(
                        session._c_session, _c_path, _c_revision, &_c_kind,
                        _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    return _c_kind


def svn_ra_get_locations(
        svn_ra_session_t session, const char * _c_path,
        _c_.svn_revnum_t _c_peg_revision, object location_revisions,
        object scratch_pool):
    cdef _svn.Apr_Pool tmp_pool
    cdef _c_.apr_array_header_t *_c_location_revisions
    cdef _svn.SvnRevnumPtrTrans revtrans
    cdef _svn.CStringTransBytes transbytes
    cdef _svn.HashTrans loctrans
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef object locations

    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        tmp_pool = _svn.Apr_Pool(scratch_pool)
    else:
        tmp_pool = _svn.Apr_Pool(_svn._scratch_pool)
    try:
        _c_location_revisions = _svn.make_revnum_array(location_revisions,
                                                       tmp_pool._c_pool)
        loctrans = _svn.HashTrans(_svn.SvnRevnumPtrTrans(),
                                  _svn.CStringTransBytes(),
                                  tmp_pool)
        serr = _c_.svn_ra_get_locations(
                    session._c_session,
                    <_c_.apr_hash_t **>(loctrans.ptr_ref()),
                    _c_path, _c_peg_revision, _c_location_revisions,
                    tmp_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        locations = loctrans.to_object()
    finally:
        del tmp_pool
    return locations


# custom version of svn_ra_open*() for svn_ra.py, using auth_baton, config,
# and allocation pool from ctx
def open_session_with_ctx(const char * rootpath, _svn.svn_client_ctx_t ctx):
    cdef _c_.svn_ra_callbacks2_t * _c_callbacks
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef _c_.svn_ra_session_t * _c_session
    cdef svn_ra_session_t session

    assert isinstance(ctx, _svn.svn_client_ctx_t)
    serr = _c_.svn_ra_create_callbacks(&_c_callbacks, ctx.pool._c_pool)
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    _c_callbacks[0].auth_baton = (ctx._c_ctx)[0].auth_baton
    # we don't use any callback function, so we pass NULL as callback baton
    IF SVN_API_VER >= (1, 7):
        serr = _c_.svn_ra_open4(
                    &_c_session, NULL, rootpath, NULL, _c_callbacks, NULL,
                    (ctx._c_ctx)[0].config, ctx.pool._c_pool)
    ELIF SVN_API_VER >= (1, 5):
        serr = _c_.svn_ra_open3(
                    &_c_session, rootpath, NULL, _c_callbacks, NULL,
                    (ctx._c_ctx)[0].config, ctx.pool._c_pool)
    ELIF SVN_API_VER >= (1, 3):
        serr = _c_.svn_ra_open2(
                    &_c_session, rootpath, _c_callbacks, NULL,
                    (ctx._c_ctx)[0].config, ctx.pool._c_pool)
    ELSE:
        # foolproof. we don't support API version below 1.3
        raise _svn.NotImplemented()
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    assert _c_session is not NULL
    session = svn_ra_session_t().set_session(_c_session, ctx.pool)
    return session


# pool free object to hold member of svn_dirent_t
# Although the C API document says svn_dirent_t is "@since New in 1.6",
# but there exists in 1.3.0 source (r858024) and used by
# svn_client_ls3() API which is available version 1.3 and above.
cdef class _Dirent(object):
    cdef readonly _c_.svn_node_kind_t kind
    cdef readonly _c_.svn_filesize_t size
    # we don't care has_props member but hold it
    cdef readonly object has_props
    cdef public _c_.svn_revnum_t created_rev
    # we don't care time member but hold it
    cdef readonly _c_.apr_time_t time
    IF PY_VERSION < (3, 0, 0):
        cdef bytes last_author
    ELSE:
        cdef str last_author
    def __init__(
            self, _c_.svn_node_kind_t kind, _c_.svn_filesize_t size,
            _c_.svn_boolean_t has_props, created_rev, _c_.apr_time_t time,
            object last_author):
        self.kind = kind
        self.size = size
        self.has_props = has_props
        self.created_rev = created_rev
        self.time = time
        # assume NULL check and str/bytes conversion has been done by caller
        self.last_author = last_author


cdef inline object _svn_dirent_to_object(const _c_.svn_dirent_t * _c_dirent):
    cdef object has_props
    cdef object last_author

    has_props = True if _c_dirent[0].has_props != _c_.FALSE else False
    last_author = <bytes>(_c_dirent[0].last_author)
    IF PY_VERSION >= (3, 0, 0):
        last_author = _norm(last_author)
    return _Dirent(_c_dirent[0].kind, _c_dirent[0].size, has_props,
                   _c_dirent[0].created_rev, _c_dirent[0].time, last_author)


IF SVN_API_VER >= (1, 4):
    cdef class _list_directory_baton(object):
        cdef public dict dirents
        cdef public dict locks
        def __cinit__(self):
            self.dirents = {}
            self.locks = {}


    IF SVN_API_VER >= (1, 8):
        # simple svn_client_list_func2_t implementation for list_directory()
        cdef _c_.svn_error_t * _cb_list_directory(
                void * _c_baton, const char * _c_path,
                const _c_.svn_dirent_t * _c_dirent,
                const _c_.svn_lock_t * _c_lock,
                const char * _c_abs_path, const char * _c_external_parent_url,
                const char * _c_external_target,
                _c_.apr_pool_t * _c_scratch_pool) with gil:
            cdef object btn
            cdef bytes path
            cdef _Dirent dirent
            cdef _svn_repos.SvnLock lock

            btn = <object>_c_baton
            path = <bytes>_c_path
            btn.dirents[path] = _svn_dirent_to_object(_c_dirent)
            if _c_lock is not NULL:
                btn.locks[path] = _svn_repos._svn_lock_to_object(_c_lock)
            return NULL
    ELSE:
        # simple svn_client_list_func_t implementation for list_directory()
        cdef _c_.svn_error_t * _cb_list_directory(
                void * _c_baton, const char * _c_path,
                const _c_.svn_dirent_t * _c_dirent,
                const _c_.svn_lock_t * _c_lock,
                const char * _c_abs_path,
                _c_.apr_pool_t * _c_scratch_pool) with gil:
            cdef _list_directory_baton btn
            cdef bytes path
            cdef _Dirent dirent
            cdef _svn_repos.SvnLock lock

            btn = <_list_directory_baton>_c_baton
            path = <bytes>_c_path
            btn.dirents[path] = _svn_dirent_to_object(_c_dirent)
            if _c_lock is not NULL:
                btn.locks[path] = _svn_repos._svn_lock_to_object(_c_lock)
            return NULL
ELSE:
    cdef class _DirentTrans(_svn.TransPtr):
        cdef const _c_.svn_dirent_t * _c_dirent
        def __cinit__(self):
            self._c_dirent = NULL
        cdef object to_object(self):
            return _svn_dirent_to_object(self._c_dirent)
        cdef void set_ptr(self, void *_c_ptr):
            self._c_dirent = <const _c_.svn_dirent_t *>_c_ptr
        cdef void ** ptr_ref(self):
            return <void **>&(self._c_dirent)

    cdef class SvnLockTrans(_svn.TransPtr):
        cdef const _c_.svn_lock_t * _c_lock
        def __cinit__(self):
            self._c_lock = NULL
        cdef object to_object(self):
            return _svn_repos._svn_lock_to_object(self._c_lock)
        cdef void set_ptr(self, void *_c_ptr):
            self._c_lock = <const _c_.svn_lock_t *>_c_ptr
        cdef void ** ptr_ref(self):
            return <void **>&(self._c_lock)


def list_directory(
        const char * url, _c_.svn_revnum_t peg_rev, _c_.svn_revnum_t rev,
        object recurse, _svn.svn_client_ctx_t ctx,
        object scratch_pool=None):
    cdef _svn.svn_opt_revision_t opt_peg_rev
    cdef _svn.svn_opt_revision_t opt_rev
    IF SVN_API_VER >= (1, 5):
        cdef _c_.svn_depth_t _c_depth
    ELSE:
        cdef _c_.svn_boolean_t _c_recurse
    IF SVN_API_VER >= (1, 4):
        cdef _list_directory_baton btn
    ELSE:
        cdef _svn.HashTrans dirents_trans
        cdef _svn.HashTrans locks_trans
        cdef dict dirents
        cdef dict locks
    cdef _c_.apr_status_t ast
    cdef _c_.apr_pool_t * _c_tmp_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    opt_peg_rev = _svn.svn_opt_revision_t(_c_.svn_opt_revision_number, peg_rev)
    opt_rev = _svn.svn_opt_revision_t(_c_.svn_opt_revision_number, rev)
    IF SVN_API_VER >= (1, 4):
        btn = _list_directory_baton()
    ELSE:
        dirents_trans = _svn.HashTrans(_svn.CstringTransBytes(),
                                       _DirentTrans(), scratch_pool)
        locks_trans   = _svn.HashTrans(_svn.CstringTransBytes(),
                                       SvnLockTrans(), scratch_pool)
    IF SVN_API_VER >= (1, 5):
        if recurse:
            _c_depth = _c_.svn_depth_infinity
        else:
            _c_depth = _c_.svn_depth_immediates
    ELSE:
        _c_recurse = _c_.TRUE if recurse else _c_.FALSE
    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<_svn.Apr_Pool>scratch_pool)._c_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        ast = _c_.apr_pool_create(&_c_tmp_pool,
                                  (<_svn.Apr_Pool>_svn._scratch_pool)._c_pool)
    if ast:
        raise _svn.PoolError()
    try:
        IF SVN_API_VER >= (1, 10):
            serr = _c_.svn_client_list4(
                        url, &(opt_peg_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), NULL, _c_depth,
                        _c_.SVN_DIRENT_ALL, _c_.TRUE, _c_.FALSE,
                        _cb_list_directory, <void *>btn,
                        ctx._c_ctx, _c_tmp_pool)
        ELIF SVN_API_VER >= (1, 8):
            serr = _c_.svn_client_list3(
                        url, &(opt_peg_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_depth,
                        _c_.SVN_DIRENT_ALL, _c_.TRUE, _c_.FALSE,
                        _cb_list_directory, <void *>btn,
                        ctx._c_ctx, _c_tmp_pool)
        ELIF SVN_API_VER >= (1, 5):
            serr = _c_.svn_client_list2(
                        url, &(opt_peg_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_depth,
                        _c_.SVN_DIRENT_ALL, _c_.TRUE,
                        _cb_list_directory, <void *>btn,
                        ctx._c_ctx, _c_tmp_pool)
        ELIF SVN_API_VER >= (1, 4):
            serr = _c_.svn_client_list(
                        url, &(opt_peg_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_recurse,
                        _c_.SVN_DIRENT_ALL, _c_.TRUE,
                        _cb_list_directory, <void *>btn,
                        ctx._c_ctx, _c_tmp_pool)
        ELSE:
            serr = _c_.svn_client_ls3(
                        <_c_.apr_hash_t **>(dirents_trans.ptr_ref()),
                        <_c_.apr_hash_t **>  (locks_trans.ptr_ref()),
                        url, &(opt_peg_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_recurse,
                        ctx._c_ctx, _c_tmp_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        IF SVN_API_VER < (1, 4):
            dirents = dirents_trans.to_object()
            del dirents_trans
            locks   = locks_trans.to_object()
            del locks_trans
    finally:
        _c_.apr_pool_destroy(_c_tmp_pool)
    IF SVN_API_VER >= (1, 4):
        return btn.dirents, btn.locks
    ELSE:
        return dirents, locks


# compatibility wrapper of svn_client_cat*(), for minimum option
def svn_client_cat(
        _svn.svn_stream_t out, const char * url, _c_.svn_revnum_t peg_rev,
        _c_.svn_revnum_t rev, object expand_keywords,
        object with_props, _svn.svn_client_ctx_t ctx,
        object scratch_pool):
    cdef _svn.Apr_Pool tmp_pool
    cdef _svn.svn_opt_revision_t opt_peg_rev
    cdef _svn.svn_opt_revision_t opt_rev
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    IF SVN_API_VER >= (1, 9):
        cdef _svn.HashTrans prop_trans
        cdef _c_.apr_hash_t ** props_p
        cdef _c_.svn_boolean_t _c_expand
        cdef object props

    opt_peg_rev = _svn.svn_opt_revision_t(_c_.svn_opt_revision_number, peg_rev)
    opt_rev = _svn.svn_opt_revision_t(_c_.svn_opt_revision_number, rev)
    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        tmp_pool = _svn.Apr_Pool(scratch_pool)
    else:
        tmp_pool = _svn.Apr_Pool(_svn._scratch_pool)

    IF SVN_API_VER >= (1, 9):
        if with_props:
            prop_trans = _svn.HashTrans(_svn.CStringTransStr(),
                                        _svn.SvnStringTransStr(),
                                        tmp_pool)
            props_p = <_c_.apr_hash_t **>prop_trans.ptr_ref()
        else:
            props_p = NULL
        _c_expand = _c_.TRUE if expand_keywords else _c_.FALSE
        try:
            serr = _c_.svn_client_cat3(
                       props_p, out._c_ptr, url,
                       &(opt_peg_rev._c_opt_revision),
                       &(opt_rev._c_opt_revision),
                       _c_expand, ctx._c_ctx,
                       tmp_pool._c_pool, tmp_pool._c_pool)
            if serr is not NULL:
                pyerr = _svn.Svn_error().seterror(serr)
                raise _svn.SVNerr(pyerr)
            if with_props:
                props = prop_trans.to_object()
            else:
                props = None
        finally:
            if with_props:
                del prop_trans
            del tmp_pool
    ELSE:
        try:
            serr = _c_.svn_client_cat2(
                       out._c_ptr, url, &(opt_peg_rev._c_opt_revision),
                       &(opt_rev._c_opt_revision),
                       ctx._c_ctx, tmp_pool._c_pool)
            if serr is not NULL:
                pyerr = _svn.Svn_error().seterror(serr)
                raise _svn.SVNerr(pyerr)
            props = None
        finally:
            del tmp_pool
    return props


# helper function to convert Python list of bytes to apr_array of C string
cdef _c_.apr_array_header_t * _bytes_list_to_apr_array(
            object byteslist, _c_.apr_pool_t *pool) except? NULL:
    cdef _c_.apr_array_header_t * _c_arrayptr
    cdef object elmstr
    cdef const char * bytesptr
    cdef int nelts
    try:
        nelts = len(byteslist)
    except TypeError:
        raise TypeError("Argment 'lists' must be sequence of bytes")
    _c_arrayptr = _c_.apr_array_make(pool, nelts, sizeof(char *))
    if _c_arrayptr is NULL:
        raise _svn.PoolError('fail to allocate memory from pool')
    for elmstr in byteslist:
        assert isinstance(elmstr, bytes)
        # To do: make copies for each elmstr for safe. othewise, we must
        # destroy the array pointed by _c_arrayptr before delete or
        # modify byteslist.
        bytesptr = elmstr
        (<void**>(_c_.apr_array_push(_c_arrayptr)))[0] = (
                 <void*>bytesptr)
    return _c_arrayptr


cdef _c_.apr_array_header_t * _revrange_list_to_apr_array(
            object range_list, _c_.apr_pool_t *pool) except? NULL:
    cdef _c_.apr_array_header_t * _c_arrayptr
    cdef _svn.svn_opt_revision_range_t elmrange
    cdef int nelts
    try:
        nelts = len(range_list)
    except TypeError:
        raise TypeError("Argment 'lists' must be sequence of "
                        "svn_opt_revision_range_t")
    _c_arrayptr = _c_.apr_array_make(pool, nelts,
                                     sizeof(_c_.svn_opt_revision_range_t *))
    if _c_arrayptr is NULL:
        raise _svn.PoolError('fail to allocate memory from pool')
    for elmrange in range_list:
        # To do: make copies for each elmrange for safe. othewise, we must
        # destroy the array pointed by _c_arrayptr before delete or
        # modify range_list.
        (<void**>(_c_.apr_array_push(_c_arrayptr)))[0] = (
                 <void*>&((<_svn.svn_opt_revision_range_t?>elmrange)._c_range))
    return _c_arrayptr


# call back function for svn_client_info*() used in get_last_changed_rev
IF SVN_API_VER >= (1, 7):
    cdef _c_.svn_error_t * _cb_get_last_change_rev(
            void * _c_baton, const char * abspath_or_url,
            const _c_.svn_client_info2_t * info,
            _c_.apr_pool_t * scratch_pool) nogil:

        if (<_c_.svn_revnum_t *>_c_baton)[0] != _c_.SVN_INVALID_REVNUM:
            _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_ASSERTION_FAIL, NULL,
                            "_cb_get_last_changed_rev has been called "
                            "more than once")
            return _c_err

        (<_c_.svn_revnum_t *>_c_baton)[0] = info[0].last_changed_rev
        return NULL
ELSE:
    cdef _cb_get_last_change_rev(
            void * _c_baton, const char * path, const _c_.svn_info_t * info,
            _c_.apr_pool_t * pool) nogil:

        if (<_c_.svn_revnum_t *>_c_baton)[0] != _c_.SVN_INVALID_REVNUM:
            _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_ASSERTION_FAIL, NULL,
                            "_cb_get_last_changed_rev has been called "
                            "more than once")
            return _c_err

        (<_c_.svn_revnum_t *>_c_baton)[0] = info[0].last_changed_rev
        return NULL


# call back function for svn_client_log*() used in get_last_changed_rev
IF SVN_API_VER >= (1, 5):
    # svn_log_entry_receiver_t signature
    cdef _c_.svn_error_t * _cb_get_last_changed_log_rev(
            void * _c_baton, _c_.svn_log_entry_t *_c_log_entry,
            _c_.apr_pool_t * _c_pool) nogil:
        cdef _c_.svn_error_t * _c_err

        if (<_c_.svn_revnum_t *>_c_baton)[0] != _c_.SVN_INVALID_REVNUM:
            _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_ASSERTION_FAIL, NULL,
                            "_cb_get_last_changed_log_rev has been called "
                            "more than once")
            return _c_err

        (<_c_.svn_revnum_t *>_c_baton)[0] = _c_log_entry[0].revision
        return NULL
ELSE:
    # svn_log_message_receiver_t signature
    cdef _c_.svn_error_t * _cb_get_last_changed_log_rev(
            void * _c_baton, _c_.apr_hash_t * _c_changed_paths,
            _c_.svn_revnum_t _c_revision, const char * _c_author,
            const char * _c_date, const char * _c_message,
            _c_.apr_pool_t * pool) nogil:
        cdef _c_.svn_error_t * _c_err

        if (<_c_.svn_revnum_t *>_c_baton)[0] != _c_.SVN_INVALID_REVNUM:
            _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_ASSERTION_FAIL, NULL,
                            "_cb_get_last_changed_log_rev has been called "
                            "more than once")
            return _c_err

        (<_c_.svn_revnum_t *>_c_baton)[0] = _c_revision
        return NULL

def get_last_history_rev(
        const char * url, _c_.svn_revnum_t rev, _svn.svn_client_ctx_t ctx,
        object scratch_pool=None):
    cdef _svn.Apr_Pool tmp_pool
    cdef _svn.svn_opt_revision_t opt_rev
    cdef _c_.svn_revnum_t lcrev
    cdef _svn.svn_opt_revision_t opt_lc_rev
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef list targets
    cdef _c_.apr_array_header_t * _c_targets
    cdef list rev_ranges
    IF SVN_API_VER >= (1, 6):
        cdef _c_.apr_array_header_t * _c_rev_ranges
    cdef _c_.apr_array_header_t * _c_revprops
    cdef _c_.svn_revnum_t lhrev

    opt_rev = _svn.svn_opt_revision_t(_c_.svn_opt_revision_number, rev)
    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        tmp_pool = _svn.Apr_Pool(scratch_pool)
    else:
        tmp_pool = _svn.Apr_Pool(_svn._scratch_pool)
    lcrev = _c_.SVN_INVALID_REVNUM
    lhrev = _c_.SVN_INVALID_REVNUM
    _c_targets = NULL
    try:
        IF SVN_API_VER >= (1, 9):
            serr = _c_.svn_client_info4(
                        url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_.svn_depth_empty,
                        _c_.FALSE, _c_.TRUE, _c_.FALSE, NULL,
                        _cb_get_last_change_rev, <void *>&lcrev,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELIF SVN_API_VER >= (1, 7):
            serr = _c_.svn_client_info3(
                        url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_.svn_depth_empty,
                        _c_.FALSE, _c_.TRUE, NULL,
                        _cb_get_last_change_rev, <void *>&lcrev,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELIF SVN_API_VER >= (1, 5):
            serr = _c_.svn_client_info2(
                        url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision),
                        _cb_get_last_change_rev, <void *>&lcrev,
                        _c_.svn_depth_empty, NULL,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELSE:
            serr = _c_.svn_client_info(
                        url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision),
                        _cb_get_last_change_rev, <void *>&lcrev,
                        _c_.FALSE, ctx._c_ctx, tmp_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        # now we can get lastest revision that the object was modified its
        # text or properties, however it might have been modified the
        # path (i.e. copied from somewhere.) To detect such the latest
        # action and its revision only, call back of LogCollector are
        # too complex. So we can use simple call back that hold revision.
        opt_lc_rev = _svn.svn_opt_revision_t(_c_.svn_opt_revision_number,
                                             lcrev)
        targets = [url]
        _c_targets = _bytes_list_to_apr_array(targets, tmp_pool._c_pool)
        IF SVN_API_VER >= (1, 4):
            # we don't need any revision props.
            _c_rev_props = _c_.apr_array_make(tmp_pool._c_pool, 0,
                                              sizeof(const char *))
        IF SVN_API_VER >= (1, 6):
            rev_ranges = [_svn.svn_opt_revision_range_t(opt_rev, opt_lc_rev)]
            _c_rev_ranges = _revrange_list_to_apr_array(
                                    rev_ranges, tmp_pool._c_pool)
            serr = _c_.svn_client_log5(
                        _c_targets, &(opt_rev._c_opt_revision),
                        _c_rev_ranges, 1, _c_.FALSE, _c_.TRUE,
                        _c_.FALSE, _c_rev_props,
                        _cb_get_last_changed_log_rev, <void *>&lhrev,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELIF SVN_API_VER >= (1, 5):
            serr = _c_.svn_client_log4(
                        _c_targets, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision),
                        &(opt_lc_rev._c_opt_revision),
                        1, _c_.FALSE, _c_.TRUE,
                        _c_.FALSE, _c_rev_props,
                        _cb_get_last_changed_log_rev, <void *>&lhrev,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELIF SVN_API_VER >= (1, 4):
            serr = _c_.svn_client_log3(
                        _c_targets, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision),
                        &(opt_lc_rev._c_opt_revision),
                        1, _c_.FALSE, _c_.TRUE,
                        _cb_get_last_changed_log_rev, <void *>&lhrev,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELSE:
            serr = _c_.svn_client_log2(
                        _c_targets,
                        &(opt_rev._c_opt_revision),
                        &(opt_lc_rev._c_opt_revision),
                        1, _c_.FALSE, _c_.TRUE,
                        _cb_get_last_changed_log_rev, <void *>&lhrev,
                        ctx._c_ctx, tmp_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        IF SVN_API_VER >= (1, 6):
            if _c_rev_ranges is not NULL:
                _c_.apr_array_clear(_c_rev_ranges)
                _c_rev_ranges = NULL
        IF SVN_API_VER >= (1, 5):
            if _c_rev_props is not NULL:
                _c_.apr_array_clear(_c_rev_props)
                _c_rev_props = NULL
        if _c_targets is not NULL:
            _c_.apr_array_clear(_c_targets)
            _c_targets = NULL
        del tmp_pool
    if lhrev != _c_.SVN_INVALID_REVNUM:
        return lhrev, lcrev
    else:
        return lcrev, lcrev


# apr_pool free data reference objects for svn_log_entry_t
IF SVN_API_VER >= (1, 6):
    cdef class py_svn_log_changed_path2_ref(object):
        def __cinit__(self):
            self.action = None
            self.copyfrom_path = None
            self.copyfrom_rev = None
            self.node_kind = _c_.svn_node_unknown
            IF SVN_API_VER >= (1, 7):
                self.text_modified = _c_.svn_tristate_unknown
                self.props_modified = _c_.svn_tristate_unknown

        cdef py_svn_log_changed_path2_ref bind(
                    py_svn_log_changed_path2_ref self,
                    const _c_.svn_log_changed_path2_t * ptr):
            assert ptr is not NULL
            self.action = chr(ptr[0].action)
            if ptr[0].copyfrom_path is NULL:
                self.copyfrom_path = None
                self.copyfrom_rev = None
            else:
                self.copyfrom_path = <bytes>(ptr[0].copyfrom_path)
                self.copyfrom_rev  = ptr[0].copyfrom_rev
            self.node_kind = ptr[0].node_kind
            IF SVN_API_VER >= (1, 7):
                self.text_modified  = ptr[0].text_modified
                self.props_modified = ptr[0].props_modified
            return self

    cdef class SvnLogChangedPath2Trans(_svn.TransPtr):
        cdef _c_.svn_log_changed_path2_t * _c_ptr
        cdef void ** ptr_ref(self):
            return <void **>&(self._c_ptr)
        cdef void set_changed_path2(
                self, _c_.svn_log_changed_path2_t * _c_ptr):
            self._c_ptr = _c_ptr
        cdef object to_object(self):
            cdef py_svn_log_changed_path2_ref changed_path
            changed_path = py_svn_log_changed_path2_ref()
            changed_path.bind(self._c_ptr)
            return changed_path


cdef class py_svn_log_changed_path_ref(object):
    def __cinit__(self):
        self.action = None
        self.copyfrom_path = None
        self.copyfrom_rev = None

    cdef py_svn_log_changed_path_ref bind(
                py_svn_log_changed_path_ref self,
                const _c_.svn_log_changed_path_t * ptr):
        assert ptr is not NULL
        self.action = chr(ptr[0].action)
        if ptr[0].copyfrom_path is NULL:
            self.copyfrom_path = None
            self.copyfrom_rev = None
        else:
            self.copyfrom_path = <bytes>(ptr[0].copyfrom_path)
            self.copyfrom_rev  = ptr[0].copyfrom_rev
        return self

cdef class SvnLogChangedPathTrans(_svn.TransPtr):
    cdef _c_.svn_log_changed_path_t * _c_ptr
    cdef void ** ptr_ref(self):
        return <void **>&(self._c_ptr)
    cdef void set_changed_path(self, _c_.svn_log_changed_path_t * _c_ptr):
        self._c_ptr = _c_ptr
    cdef object to_object(self):
        cdef py_svn_log_changed_path_ref changed_path
        changed_path = py_svn_log_changed_path_ref()
        changed_path.bind(self._c_ptr)
        return changed_path


# apr_pool free data reference object for svn_log_entry_t
cdef class py_svn_log_entry(object):
    def __cinit__(self):
        self.changed_paths = None
        self.revision = _c_.SVN_INVALID_REVNUM
        self.revprops = None
        IF SVN_API_VER >= (1, 5):
            self.has_children = False
        IF SVN_API_VER >= (1, 6):
            self.changed_paths2 = None
        IF SVN_API_VER >= (1, 7):
            self.non_inheritable = False
            self.subtractive_merge = False
        return

    IF SVN_API_VER >= (1, 5):
        cdef void bind(self, const _c_.svn_log_entry_t *_c_ptr,
                _svn.Apr_Pool scratch_pool):
            cdef _svn.Apr_Pool tmp_pool
            cdef _svn.HashTrans cp_trans
            cdef _svn.HashTrans prop_trans
            IF SVN_API_VER >= (1, 6):
                cdef _svn.HashTrans cp2_trans

            assert _c_ptr is not NULL
            assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
            tmp_pool = _svn.Apr_Pool(scratch_pool)
            if _c_ptr[0].changed_paths is NULL:
                self.changed_paths = {}
            else:
                cp_trans = _svn.HashTrans(_svn.CStringTransBytes(),
                                          SvnLogChangedPathTrans(),
                                          tmp_pool)
                try:
                    cp_trans.set_ptr(<void *>(_c_ptr[0].changed_paths))
                    self.changed_paths = cp_trans.to_object()
                finally:
                    del cp_trans
            self.revision = _c_ptr[0].revision
            if _c_ptr[0].revprops is NULL:
                self.revprops = {}
            else:
                prop_trans = _svn.HashTrans(_svn.CStringTransStr(),
                                            _svn.SvnStringTransStr(),
                                            tmp_pool)
                try:
                    prop_trans.set_ptr(<void *>(_c_ptr[0].revprops))
                    self.revprops = prop_trans.to_object()
                finally:
                    del prop_trans
            if _c_ptr[0].has_children:
                self.has_children = True
            else:
                self.has_children = False
            IF SVN_API_VER >= (1, 6):
                if _c_ptr[0].changed_paths2 is NULL:
                    self.changed_paths2 = {}
                else:
                    cp2_trans = _svn.HashTrans(
                                            _svn.CStringTransBytes(),
                                            SvnLogChangedPath2Trans(),
                                            tmp_pool)
                    try:
                        cp2_trans.set_ptr(<void *>(_c_ptr[0].changed_paths2))
                        self.changed_paths2 = cp2_trans.to_object()
                    finally:
                        del cp2_trans
            IF SVN_API_VER >= (1, 7):
                if _c_ptr[0].non_inheritable:
                    self.non_inheritable = True
                else:
                    self.non_inheritable = False
                if _c_ptr[0].subtractive_merge:
                    self.subtractive_merge = True
                else:
                    self.subtractive_merge = False
            del tmp_pool
            return
    ELSE:
        cdef void bind(
                self, const _c_.apr_hash_t *_c_changed_paths,
                _c_.svn_revision_t _c_revision, const char * author,
                const char * date, const char * message,
                _svn.Apr_Pool scratch_pool):
            cdef _svn.Apr_Pool tmp_pool
            cdef _svn.HashTrans cp_trans

            assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
            tmp_pool = Apr_Pool(scratch_pool)
            if _c_ptr[0].changed_paths is NULL:
                self.changed_paths = {}
            else:
                cp_trans = _svn.HashTrans(_svn.CStringTransBytes(),
                                          _svn.SvnLogChangedPathTrans(),
                                          tmp_pool)
                try:
                    cp_trans.set_ptr(<void *>(_c_changed_paths))
                    self.changed_paths = cp_trans.to_object()
                finally:
                    del cp_trans
            self.revision = _c_.revision
            IF PY_VERSION >= (3, 0, 0):
                self.revprops = {
                        _svn.SVN_PROP_REVISION_LOG :
                                (_norm(<bytes>_c_message)
                                        if _c_message is not NULL else ''),
                        _svn.SVN_PROP_REVISION_AUTHOR :
                                (_norm(<bytes>_c_author)
                                        if _c_author is not NULL else ''),
                        _svn.SVN_PROP_REVISION_DATE :
                                (_norm(<bytes>_c_date)
                                        if _c_date is not NULL else '')}
            ELSE:
                self.revprops = {
                        _svn.SVN_PROP_REVISION_LOG :
                                (<bytes>_c_message
                                        if _c_message is not NULL else ''),
                        _svn.SVN_PROP_REVISION_AUTHOR :
                                (<bytes>_c_author
                                        if _c_author is not NULL else ''),
                        _svn.SVN_PROP_REVISION_DATE :
                                (<bytes>_c_date
                                        if _c_date is not NULL else '') }
            del tmp_pool
            return

# call back function for svn_client_log*()
IF SVN_API_VER >= (1, 5):
    cdef _c_.svn_error_t * _cb_svn_log_entry_receiver_t_wrapper(
            void * _c_baton, _c_.svn_log_entry_t * _c_log_entry,
            _c_.apr_pool_t * _c_pool) with gil:
        cdef _svn.CbContainer btn
        cdef py_svn_log_entry log_entry
        cdef _c_.svn_error_t * _c_err
        cdef _svn.Svn_error svnerr

        btn = <_svn.CbContainer>_c_baton
        log_entry = py_svn_log_entry()
        _c_err = NULL
        try:
            log_entry.bind(_c_log_entry, btn.pool)
            btn.fnobj(btn.btn, log_entry, btn.pool)
        except _svn.SVNerr as serr:
            svnerr = serr.svnerr
            _c_err = _c_.svn_error_dup(svnerr.geterror())
            del serr
        except AssertionError, err:
            IF PY_VERSION >= (3, 0, 0):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_ASSERTION_FAIL, NULL,
                            str(err).encode('utf-8'))
            ELSE:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_ASSERTION_FAIL, NULL, str(err))
        except KeyboardInterrupt, err:
            IF PY_VERSION >= (3, 0, 0):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_CANCELLED, NULL,
                            str(err).encode('utf-8'))
            ELSE:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_CANCELLED, NULL, str(err))
        except BaseException, err:
            IF PY_VERSION >= (3, 0, 0):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_BASE, NULL, str(err).encode('utf-8'))
            ELSE:
                _c_err = _c_.svn_error_create(_c_.SVN_ERR_BASE, NULL, str(err))
        return _c_err
ELSE:
    cdef _c_.svn_error_t * _cb_svn_log_message_receiver_t_wrapper(
            void * _c_baton, _c_.apr_hash_t * _c_changed_paths,
            _c_.svn_revnum_t _c_revision, const char * _c_author,
            const char * _c_date, const char * _c_message,
            _c_.apr_pool_t * pool) with gil:
        cdef _svn.CbContainer btn
        cdef py_svn_log_entry log_entry
        cdef _c_.svn_error_t * _c_err
        cdef _svn.Svn_error svnerr

        btn = <_svn.CbContainer>_c_baton
        log_entry = py_svn_log_entry()
        _c_err = NULL
        try:
            log_entry.bind(
                    _c_changed_paths, _c_revision, _c_author, _c_date,
                    _c_message, btn.pool)
            btn.fnobj(btn.btn, log_entry, btn.pool)
        except _svn.SVNerr as serr:
            svnerr = serr.svnerr
            _c_err = _c_.svn_error_dup(svnerr.geterror())
            del serr
        except AssertionError, err:
            IF PY_VERSION >= (3, 0, 0):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_ASSERTION_FAIL, NULL,
                            str(err).encode('utf-8'))
            ELSE:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_ASSERTION_FAIL, NULL, str(err))
        except KeyboardInterrupt, err:
            IF PY_VERSION >= (3, 0, 0):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_CANCELLED, NULL,
                            str(err).encode('utf-8'))
            ELSE:
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_CANCELLED, NULL, str(err))
        except BaseException, err:
            IF PY_VERSION >= (3, 0, 0):
                _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_BASE, NULL, str(err).encode('utf-8'))
            ELSE:
                _c_err = _c_.svn_error_create(_c_.SVN_ERR_BASE, NULL, str(err))
        return _c_err


# svn_client_log*() wrapper for vclib: disable some feature unused
def client_log(
        const char * url, object start_rev, object end_rev, int log_limit,
        object include_changes, object cross_copies, object cb_func,
        object baton, _svn.svn_client_ctx_t ctx, object scratch_pool=None):
    cdef _svn.Apr_Pool tmp_pool
    cdef _svn.svn_opt_revision_t opt_start_rev
    cdef _svn.svn_opt_revision_t opt_end_rev
    cdef _c_.svn_boolean_t _c_discover_changed_paths
    cdef _c_.svn_boolean_t _c_strict_node_history
    cdef object targets
    cdef _c_.apr_array_header_t * _c_targets
    cdef _svn.CbContainer btn
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    IF SVN_API_VER >= (1, 6):
        cdef list rev_ranges
        cdef _c_.apr_array_header_t * _c_rev_ranges

    if isinstance(start_rev, _svn.svn_opt_revision_t):
        opt_start_rev = start_rev
    else:
        opt_start_rev = _svn.svn_opt_revision_t(
                                _c_.svn_opt_revision_number, start_rev)
    if isinstance(end_rev, _svn.svn_opt_revision_t):
        opt_end_rev = end_rev
    else:
        opt_end_rev = _svn.svn_opt_revision_t(
                                _c_.svn_opt_revision_number, end_rev)
    _c_discover_changed_paths = _c_.TRUE if include_changes else _c_.FALSE
    _c_strict_node_history = _c_.TRUE if not cross_copies else _c_.FALSE
    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        tmp_pool = _svn.Apr_Pool(scratch_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        tmp_pool = _svn.Apr_Pool(_svn._scratch_pool)
    try:
        targets = [<bytes>url]
        _c_targets = _bytes_list_to_apr_array(targets, tmp_pool._c_pool)
        btn = _svn.CbContainer(cb_func, baton, tmp_pool)
        IF SVN_API_VER >= (1, 6):
            rev_ranges = [_svn.svn_opt_revision_range_t(opt_start_rev,
                                                        opt_end_rev)]
            _c_rev_ranges = _revrange_list_to_apr_array(
                                    rev_ranges, tmp_pool._c_pool)
            serr = _c_.svn_client_log5(
                        _c_targets, &(opt_start_rev._c_opt_revision),
                        _c_rev_ranges, log_limit, _c_discover_changed_paths,
                        _c_strict_node_history, _c_.FALSE, NULL,
                        _cb_svn_log_entry_receiver_t_wrapper,<void *>btn,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELIF SVN_API_VER >= (1, 5):
            serr = _c_.svn_client_log4(
                        _c_targets, &(opt_start_rev._c_opt_revision),
                        &(opt_start_rev._c_opt_revision),
                        &(opt_end_rev._c_opt_revision),
                        log_limit, _c_discover_changed_paths,
                        _c_strict_node_history, _c_.FALSE, NULL,
                        _cb_svn_log_entry_receiver_t_wrapper,<void *>btn,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELIF SVN_API_VER >= (1, 4):
            serr = _c_.svn_client_log3(
                        _c_targets, &(opt_start_rev._c_opt_revision),
                        &(opt_start_rev._c_opt_revision),
                        &(opt_end_rev._c_opt_revision),
                        log_limit, _c_discover_changed_paths,
                        _c_strict_node_history,
                        _cb_svn_log_message_receiver_t_wrapper, <void *>btn,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELSE:
            serr = _c_.svn_client_log2(
                        _c_targets,
                        &(opt_start_rev._c_opt_revision),
                        &(opt_end_rev._c_opt_revision),
                        log_limit, _c_discover_changed_paths,
                        _c_strict_node_history,
                        _cb_svn_log_message_receiver_t_wrapper, <void *>btn,
                        ctx._c_ctx, tmp_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        IF SVN_API_VER >= (1, 6):
            if _c_rev_ranges is not NULL:
                _c_.apr_array_clear(_c_rev_ranges)
                _c_rev_ranges = NULL
        if _c_targets is not NULL:
            _c_.apr_array_clear(_c_targets)
            _c_targets = NULL
        del tmp_pool
    return

# simplified svn_client_prolist*() API for single node and single revision
# without inherited props
IF SVN_API_VER >= (1, 5):
    cdef _c_.svn_error_t * _cb_simple_proplist_body(
            void *_c_baton, _c_.apr_hash_t * _c_prop_hash,
            _c_.apr_pool_t * _c_scratch_pool) with gil:
        cdef object baton
        cdef _c_.svn_error_t * _c_err
        cdef _svn.Svn_error pyerr
        cdef _svn.Apr_Pool scratch_pool
        cdef _svn.Apr_Pool tmp_pool
        cdef _svn.HashTrans prop_trans
        cdef object propdict

        baton = <object>_c_baton
        if baton:
            _c_err = _c_.svn_error_create(
                            _c_.SVN_ERR_ASSERTION_FAIL, NULL,
                            "_cb_simple_proplist_receiver has been called "
                            "more than once")
            return _c_err
        _c_err = NULL
        if _c_prop_hash is NULL:
            baton.append({})
        else:
            scratch_pool = _svn.Apr_Pool.__new__(_svn.Apr_Pool, pool=None)
            scratch_pool.set_pool(_c_scratch_pool)
            tmp_pool = _svn.Apr_Pool(scratch_pool)
            try:
                prop_trans = _svn.HashTrans(_svn.CStringTransStr(),
                                            _svn.SvnStringTransStr(),
                                            tmp_pool)
                prop_trans.set_ptr(<void *>(_c_prop_hash))
                propdict = prop_trans.to_object()
                del prop_trans
                baton.append(propdict)
            except _svn.SVNerr as serr:
                pyerr = serr.svnerr
                _c_err = _c_.svn_error_dup(pyerr.geterror())
                del serr
            except AssertionError, err:
                IF PY_VERSION >= (3, 0, 0):
                    _c_err = _c_.svn_error_create(
                                _c_.SVN_ERR_ASSERTION_FAIL, NULL,
                                str(err).encode('utf-8'))
                ELSE:
                    _c_err = _c_.svn_error_create(
                                _c_.SVN_ERR_ASSERTION_FAIL, NULL, str(err))
            except KeyboardInterrupt, err:
                IF PY_VERSION >= (3, 0, 0):
                    _c_err = _c_.svn_error_create(
                                _c_.SVN_ERR_CANCELLED, NULL,
                                str(err).encode('utf-8'))
                ELSE:
                    _c_err = _c_.svn_error_create(
                                _c_.SVN_ERR_CANCELLED, NULL, str(err))
            except BaseException, err:
                IF PY_VERSION >= (3, 0, 0):
                    _c_err = _c_.svn_error_create(
                                _c_.SVN_ERR_BASE, NULL,
                                str(err).encode('utf-8'))
                ELSE:
                    _c_err = _c_.svn_error_create(
                                _c_.SVN_ERR_BASE, NULL, str(err))
            finally:
                del tmp_pool
                del scratch_pool
        return _c_err


    IF SVN_API_VER >= (1, 8):
        cdef _c_.svn_error_t * _cb_simple_proplist_receiver(
                void * _c_baton, const char * _c_path,
                _c_.apr_hash_t * _c_prop_hash,
                _c_.apr_array_header_t * inherited_props,
                _c_.apr_pool_t * _c_scratch_pool) nogil:
            return _cb_simple_proplist_body(
                            _c_baton, _c_prop_hash, _c_scratch_pool)
    ELSE:
        cdef _c_.svn_error_t * _cb_simple_proplist_receiver(
                void * _c_baton, const char * _c_path,
                _c_.apr_hash_t * _c_prop_hash,
                _c_.apr_pool_t * _c_scratch_pool) nogil:
            return _cb_simple_proplist_body(
                            _c_baton, _c_prop_hash, _c_scratch_pool)

def simple_proplist(
        const char * url, object rev, _svn.svn_client_ctx_t ctx,
        object scratch_pool=None):
    cdef _svn.Apr_Pool tmp_pool
    cdef _svn.svn_opt_revision_t opt_rev
    IF SVN_API_VER >= (1, 5):
        cdef object propdic_list
    ELSE:
        cdef _c_.apr_array_header_t * _c_props
        cdef _c_.svn_client_proplist_item_t * _c_prop_item
        cdef _svn.HashTrans prop_trans
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef object propdic

    if isinstance(rev, _svn.svn_opt_revision_t):
        opt_rev = rev
    else:
        opt_rev = _svn.svn_opt_revision_t(_c_.svn_opt_revision_number, rev)
    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        tmp_pool = _svn.Apr_Pool(scratch_pool)
    else:
        (<_svn.Apr_Pool>_svn._scratch_pool).clear()
        tmp_pool = _svn.Apr_Pool(_svn._scratch_pool)
    IF SVN_API_VER >= (1, 5):
        propdic_list = []
    try:
        IF SVN_API_VER >= (1, 8):
            serr = _c_.svn_client_proplist4(
                        url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_.svn_depth_empty,
                        NULL, _c_.FALSE,
                        _cb_simple_proplist_receiver, <void *>propdic_list,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELIF SVN_API_VER >= (1, 5):
            serr = _c_.svn_client_proplist3(
                        url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_.svn_depth_empty, NULL,
                        _cb_simple_proplist_receiver, <void *>propdic_list,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELSE:
            _c_props = NULL
            serr = _c_.svn_client_proplist2(
                        &_c_props, url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_.FALSE,
                        ctx._c_ctx, tmp_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        IF SVN_API_VER > (1, 5):
            # extract props from array
            if propdic_list:
                assert len(propdic_list) == 1
                propdic = propdic_list[0]
            else:
                propdic = {}
        ELSE:
            # extract props from array
            assert _c_props is not NULL
            assert _c_props[0].nels == 1
            prop_trans = _svn.HashTrans(_svn.CStringTransStr(),
                                        _svn.SvnStringTransStr(),
                                        tmp_pool)
            if _c_props[0].elts is NULL:
                propdic = {}
            else:
                (<_c_.apr_hash_t **>(prop_trans.ptr_ref()))[0] = \
                                <_c_.apr_hash_t *>(_c_props[0].elts)
                propdic = prop_trans.to_object()
            del prop_trans
    finally:
        del tmp_pool
    return propdic
