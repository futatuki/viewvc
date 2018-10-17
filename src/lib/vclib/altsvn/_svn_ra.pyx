include "_svn_api_ver.pxi"
include "_py_ver.pxi"
cimport _svn_ra_capi as _c_
cimport _svn
cimport _svn_repos
import _svn

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


cdef class svn_client_ctx_t(object):
    # cdef _c_.svn_client_ctx_t * _c_ctx
    # cdef _svn.Apr_Pool pool
    cdef svn_client_ctx_t set_ctx(self, _c_.svn_client_ctx_t * _c_ctx, pool):
        assert pool is None or (<_svn.Apr_Pool?>pool)._c_pool is not NULL
        self.pool = pool
        assert _c_ctx is not NULL
        self._c_ctx = _c_ctx
        return self


# custom version of svn_client_ctx*() for svn_ra.py
def setup_client_ctx(object config_dir, object result_pool=None):
    cdef const char * _c_config_dir
    cdef _svn.Apr_Pool r_pool
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef _c_.apr_hash_t * _c_cfg_hash
    cdef _c_.svn_client_ctx_t * _c_ctx
    cdef _c_.svn_auth_baton_t * _c_auth_baton
    cdef svn_client_ctx_t ctx
    IF SVN_API_VER >= (1, 6):
        cdef _c_.svn_config_t * _c_cfg
    ELSE:
        cdef _c_.apr_array_header_t * _c_providers
        cdef _c_.svn_auth_provider_object_t * _c_provider

    if result_pool is not None:
        assert (<_svn.Apr_Pool?>result_pool)._c_pool is not NULL
        r_pool = result_pool
    else:
        r_pool = _svn._root_pool
    assert isinstance(config_dir, bytes) or config_dir is None
    _c_config_dir = <char *>config_dir if config_dir else NULL

    serr = _c_.svn_config_ensure(_c_config_dir, r_pool._c_pool)
    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    serr = _c_.svn_config_get_config(
                    &_c_cfg_hash, _c_config_dir, r_pool._c_pool)

    if serr is not NULL:
        pyerr = _svn.Svn_error().seterror(serr)
        raise _svn.SVNerr(pyerr)
    IF SVN_API_VER >= (1, 8):
        serr = _c_.svn_client_create_context2(
                        &_c_ctx, _c_cfg_hash, r_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    ELSE:
        serr = _c_.svn_client_create_context(&_c_ctx, r_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        _c_ctx[0].config = _c_cfg_hash
    IF SVN_API_VER >= (1, 6):
        _c_cfg = <_c_.svn_config_t *>_c_.apr_hash_get(
                            _c_cfg_hash, _c_.SVN_CONFIG_CATEGORY_CONFIG,
                            _c_.APR_HASH_KEY_STRING)
        IF SVN_API_VER >= (1, 8):
            serr = _c_.svn_cmdline_create_auth_baton2(
                        &_c_auth_baton, _c_.TRUE, NULL, NULL,
                        _c_config_dir, _c_.TRUE,
                        _c_.TRUE, _c_.TRUE, _c_.TRUE, _c_.TRUE, _c_.TRUE,
                        _c_cfg, NULL, NULL, r_pool._c_pool)
        ELSE:
            serr = _c_.svn_cmdline_create_auth_baton(
                        &_c_auth_baton, _c_.TRUE, NULL, NULL,
                        _c_config_dir,  _c_.TRUE, _c_.TRUE,
                        _c_cfg, NULL, NULL, r_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    ELSE:
        _c_providers = _c_.apr_array_make(
                            r_pool._c_pool, 5,
                            sizeof(_c_.svn_auth_provider_object_t *))
        if _c_providers is NULL:
            serr = _c_.svn_error_create(_c_.APR_ENOMEM, NULL, NULL)
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
        IF SVN_API_VER >= (1, 4):
            _c_.svn_auth_get_simple_provider(&_c_provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_auth_get_username_provider(&_c_provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_auth_get_ssl_server_trust_file_provider(
                            &_c_provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_auth_get_ssl_client_cert_file_provider(
                            &_c_provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_auth_get_ssl_client_cert_pw_file_provider(
                            &_c_provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
        ELSE:
            _c_.svn_client_get_simple_provider(&_c_provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_client_get_username_provider(&_c_provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_client_get_ssl_server_trust_file_provider(
                            &_c_provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_client_get_ssl_client_cert_file_provider(
                            &_c_provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_client_get_ssl_client_cert_pw_file_provider(
                            &_c_provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
        _c_.svn_auth_open(&_c_auth_baton, _c_providers, r_pool._c_pool)
    _c_ctx[0].auth_baton = _c_auth_baton
    ctx = svn_client_ctx_t().set_ctx(_c_ctx, r_pool)
    return ctx


# custom version of svn_ra_open*() for svn_ra.py, using auth_baton, config,
# and allocation pool from ctx
def open_session_with_ctx(const char * rootpath, svn_client_ctx_t ctx):
    cdef _c_.svn_ra_callbacks2_t * _c_callbacks
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr
    cdef _c_.svn_ra_session_t * _c_session
    cdef svn_ra_session_t session

    assert isinstance(ctx, svn_client_ctx_t)
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
        last_author = _svn._norm(last_author)
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
        object recurse, svn_client_ctx_t ctx,
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
            locks   = locks_trans.to_object()
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
        object with_props, svn_client_ctx_t ctx,
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


IF SVN_API_VER >= (1, 7):
    cdef _c_.svn_error_t * _cb_get_last_change_rev(
            void * _c_baton, const char * abspath_or_url,
            const _c_.svn_client_info2_t * info,
            _c_.apr_pool_t * scratch_pool) with gil:
        cdef object btn
        btn = <object>_c_baton
        btn.append(info.last_changed_rev)
        return NULL
ELSE:
    cdef _cb_get_last_change_rev(
            void * _c_baton, const char * path, const _c_.svn_info_t * info,
            _c_.apr_pool_t * pool) with gil:
        cdef object btn
        btn = <object>_c_baton
        btn.append(info.last_changed_rev)
        return NULL

def get_last_changed_rev(
        const char * url, _c_.svn_revnum_t rev, svn_client_ctx_t ctx,
        object scratch_pool=None):
    cdef _svn.Apr_Pool tmp_pool
    cdef _svn.svn_opt_revision_t opt_rev
    cdef list rev_list
    cdef _c_.svn_error_t * serr
    cdef _svn.Svn_error pyerr

    opt_rev = _svn.svn_opt_revision_t(_c_.svn_opt_revision_number, rev)
    if scratch_pool is not None:
        assert (<_svn.Apr_Pool?>scratch_pool)._c_pool is not NULL
        tmp_pool = _svn.Apr_Pool(scratch_pool)
    else:
        tmp_pool = _svn.Apr_Pool(_svn._scratch_pool)
    rev_list = []
    try:
        IF SVN_API_VER >= (1, 9):
            serr = _c_.svn_client_info4(
                        url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_.svn_depth_empty,
                        _c_.FALSE, _c_.TRUE, _c_.FALSE, NULL,
                        _cb_get_last_change_rev, <void *>rev_list,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELIF SVN_API_VER >= (1, 7):
            serr = _c_.svn_client_info3(
                        url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision), _c_.svn_depth_empty,
                        _c_.FALSE, _c_.TRUE, NULL,
                        _cb_get_last_change_rev, <void *>rev_list,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELIF SVN_API_VER >= (1, 5):
            serr = _c_.svn_client_info2(
                        url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision),
                        _cb_get_last_change_rev, <void *>rev_list,
                        _c_.svn_depth_empty, NULL,
                        ctx._c_ctx, tmp_pool._c_pool)
        ELSE:
            serr = _c_.svn_client_info(
                        url, &(opt_rev._c_opt_revision),
                        &(opt_rev._c_opt_revision),
                        _cb_get_last_change_rev, <void *>rev_list,
                        _c_.FALSE, ctx._c_ctx, tmp_pool._c_pool)
        if serr is not NULL:
            pyerr = _svn.Svn_error().seterror(serr)
            raise _svn.SVNerr(pyerr)
    finally:
        del tmp_pool
    return rev_list[0]
