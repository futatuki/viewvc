include "_svn_api_ver.pxi"
from apr_1.apr_pools cimport apr_pool_t
from apr_1.apr_hash cimport apr_hash_t
from apr_1.apr_tables cimport apr_array_header_t
from subversion_1.svn_types cimport svn_error_t, svn_boolean_t

cdef extern from "svn_auth.h" nogil:
    ctypedef struct svn_auth_baton_t:
        pass
    ctypedef struct svn_auth_provider_t:
        const char * cred_kind
        svn_error_t * (* first_credentials)(
                void ** credentials, void ** iter_baton, void * provider_baton,
                apr_hash_t * parameters, const char * realmstring,
                apr_pool_t * pool)
        svn_error_t * (* next_credentials)(
                void ** credentials, void * iter_baton, void * provider_baton,
                apr_hash_t * parameters, const char * realmstring,
                apr_pool_t * pool)
        svn_error_t * (* save_credentials)(
                svn_boolean_t saved, void * credentials, void * provider_baton,
                apr_hash_t * parameters, const char * realmstring,
                apr_pool_t * pool)
    ctypedef struct svn_auth_provider_object_t:
        const svn_auth_provider_t * vtable
        void * provider_baton
    void svn_auth_open(
            svn_auth_baton_t ** auth_baton,
            const apr_array_header_t * providers, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 4) and SVN_API_VER < (1, 6):
        # Of course, these are also provided for API version 1.6 and above,
        # we don't use them directory, use svn_cmdline_create_auth_baton()
        # to set them.
        void svn_auth_get_simple_provider(
                svn_auth_provider_object_t ** provider, apr_pool_t * pool)
        void svn_auth_get_username_provider(
                svn_auth_provider_object_t ** provider, apr_pool_t * pool)
        void svn_auth_get_ssl_server_trust_file_provider(
                svn_auth_provider_object_t ** provider, apr_pool_t * pool)
        void svn_auth_get_ssl_client_cert_file_provider(
                svn_auth_provider_object_t ** provider, apr_pool_t * pool)
        void svn_auth_get_ssl_client_cert_pw_file_provider(
                svn_auth_provider_object_t ** provider, apr_pool_t * pool)
