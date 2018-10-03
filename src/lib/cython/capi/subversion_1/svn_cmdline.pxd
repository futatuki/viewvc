include "_svn_api_ver.pxi"
from apr_1.apr_pools cimport apr_pool_t
from subversion_1.svn_types cimport svn_error_t, svn_boolean_t, \
                                    svn_cancel_func_t
from subversion_1.svn_config cimport svn_config_t
from subversion_1.svn_auth cimport svn_auth_baton_t

cdef extern from "svn_cmdline.h" nogil:
    IF SVN_API_VER >= (1, 8):
        svn_error_t *  svn_cmdline_create_auth_baton2(
                svn_auth_baton_t ** ab, svn_boolean_t non_interactive,
                const char * username, const char * password,
                const char * config_dir, svn_boolean_t no_auth_cache,
                svn_boolean_t trust_server_cert_unknown_ca,
                svn_boolean_t trust_server_cert_cn_mismatch,
                svn_boolean_t trust_server_cert_expired,
                svn_boolean_t trust_server_cert_not_yet_valid,
                svn_boolean_t trust_server_cert_other_failure,
                svn_config_t * cfg, svn_cancel_func_t cancel_func,
                void * cancel_baton, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 6):
        svn_error_t * svn_cmdline_create_auth_baton(
                svn_auth_baton_t ** ab, svn_boolean_t non_interactive,
                const char * username, const char * password,
                const char * config_dir, svn_boolean_t no_auth_cache,
                svn_boolean_t trust_server_cert, svn_config_t * cfg,
                svn_cancel_func_t cancel_func, void * cancel_baton,
                apr_pool_t * pool)
    ELSE:
        pass
