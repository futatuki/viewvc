include "_svn_api_ver.pxi"
cimport _svn_ra_capi as _c_
cimport _svn
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


cdef class svn_client_ctx_t(object):
    # cdef _c_.svn_client_ctx_t * _c_ctx 
    # cdef _svn.Apr_Pool pool
    cdef svn_client_ctx_t set_ctx(self, _c_.svn_client_ctx_t * _c_ctx, pool):
        assert pool is None or (<_svn.Apr_Pool?>pool)._c_pool is not NULL
        self.pool = pool
        assert _c_ctx is not NULL
        self._c_ctx = _c_ctx
        return self

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
            _c_.svn_auth_get_simple_provider(&provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_auth_get_username_provider(&provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_auth_get_ssl_server_trust_file_provider(
                            &provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_auth_get_ssl_client_cert_file_provider(
                            &provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_auth_get_ssl_client_cert_pw_file_provider(
                            &provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
        ELSE:
            _c_.svn_client_get_simple_provider(&provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_client_get_username_provider(&provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_client_get_ssl_server_trust_file_provider(
                            &provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_client_get_ssl_client_cert_file_provider(
                            &provider, r_pool._c_pool)
            (<void **>(_c_.apr_array_push(_c_providers)))[0] = (
                    <void *>_c_provider)
            _c_.svn_client_get_ssl_client_cert_pw_file_provider(
                            &provider, r_pool._c_pool)
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
    ELIF SVN_APR_VER >= (1, 3):
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


def list_directory(url, peg_rev, rev, flag, ctx):
    raise _svn.NotImplemented()
