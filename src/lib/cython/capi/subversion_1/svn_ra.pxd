include "_svn_api_ver.pxi"
from apr_1.apr cimport apr_off_t
from apr_1.apr_pools cimport apr_pool_t
from apr_1.apr_hash cimport apr_hash_t
from apr_1.apr_file_io cimport apr_file_t
from subversion_1.svn_types cimport *
from subversion_1.svn_auth cimport svn_auth_baton_t
from subversion_1.svn_string cimport svn_string_t
from subversion_1.svn_io cimport svn_stream_t
IF SVN_API_VER >= (1, 6):
    from subversion_1.svn_checksum cimport svn_checksum_t

cdef extern from "svn_ra.h" nogil:
    ctypedef svn_error_t * (* svn_ra_get_wc_prop_func_t)(
            void * baton, const char * path, const char * name,
            const svn_string_t ** value, apr_pool_t *pool)
    ctypedef svn_error_t * (* svn_ra_set_wc_prop_func_t)(
            void * baton, const char * path, const char * name,
            const svn_string_t * value, apr_pool_t * pool)
    ctypedef svn_error_t * (* svn_ra_push_wc_prop_func_t)(
            void * baton, const char  *path, const char * name,
            const svn_string_t * value, apr_pool_t * pool)
    ctypedef svn_error_t * (* svn_ra_invalidate_wc_props_func_t)(
            void * baton, const char * path, const char * name,
            apr_pool_t * pool)
    IF SVN_API_VER >= (1, 3):
        ctypedef void ( * svn_ra_progress_notify_func_t)(
                apr_off_t progress, apr_off_t total, void * baton,
                apr_pool_t * pool)
    IF SVN_API_VER >= (1, 8):
        ctypedef svn_error_t * (* svn_ra_get_wc_contents_func_t)(
            void * baton, svn_stream_t ** contents,
            const svn_checksum_t * checksum, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 5):
        ctypedef svn_error_t * ( * svn_ra_get_client_string_func_t)(
            void * baton, const char ** name, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 9):
        ctypedef svn_boolean_t ( * svn_ra_check_tunnel_func_t)(
                void * tunnel_baton, const char * tunnel_name)
        ctypedef void (* svn_ra_close_tunnel_func_t)(
                void * close_baton, void * tunnel_baton)
        ctypedef svn_error_t * ( * svn_ra_open_tunnel_func_t)(
                svn_stream_t ** request, svn_stream_t ** response,
                svn_ra_close_tunnel_func_t * close_func, void ** close_baton,
                void * tunnel_baton, const char * tunnel_name,
                const char * user, const char * hostname, int port,
                svn_cancel_func_t cancel_func, void * cancel_baton,
                apr_pool_t * pool)
        ctypedef struct svn_ra_callbacks2_t:
            svn_error_t * (* open_tmp_file)(
                    apr_file_t ** fp, void * callback_baton, apr_pool_t * pool)
            svn_auth_baton_t * auth_baton
            svn_ra_get_wc_prop_func_t get_wc_prop
            svn_ra_set_wc_prop_func_t set_wc_prop
            svn_ra_push_wc_prop_func_t push_wc_prop
            svn_ra_invalidate_wc_props_func_t invalidate_wc_props
            svn_ra_progress_notify_func_t progress_func
            svn_cancel_func_t cancel_func
            svn_ra_get_client_string_func_t get_client_string
            svn_ra_get_wc_contents_func_t get_wc_contents
            svn_ra_check_tunnel_func_t check_tunnel_func
            svn_ra_open_tunnel_func_t open_tunnel_func
            void * tunnel_baton
    ELIF SVN_API_VER == (1, 8):
        ctypedef struct svn_ra_callbacks2_t:
            svn_error_t * (* open_tmp_file)(
                    apr_file_t ** fp, void * callback_baton, apr_pool_t * pool)
            svn_auth_baton_t * auth_baton
            svn_ra_get_wc_prop_func_t get_wc_prop
            svn_ra_set_wc_prop_func_t set_wc_prop
            svn_ra_push_wc_prop_func_t push_wc_prop
            svn_ra_invalidate_wc_props_func_t invalidate_wc_props
            svn_ra_progress_notify_func_t progress_func
            svn_cancel_func_t cancel_func
            svn_ra_get_client_string_func_t get_client_string
            svn_ra_get_wc_contents_func_t get_wc_contents
    ELIF SVN_API_VER >= (1, 5):
        ctypedef struct svn_ra_callbacks2_t:
            svn_error_t * (* open_tmp_file)(
                    apr_file_t ** fp, void * callback_baton, apr_pool_t * pool)
            svn_auth_baton_t * auth_baton
            svn_ra_get_wc_prop_func_t get_wc_prop
            svn_ra_set_wc_prop_func_t set_wc_prop
            svn_ra_push_wc_prop_func_t push_wc_prop
            svn_ra_invalidate_wc_props_func_t invalidate_wc_props
            svn_ra_progress_notify_func_t progress_func
            svn_cancel_func_t cancel_func
            svn_ra_get_client_string_func_t get_client_string
    ELIF SVN_API_VER >= (1, 3):
        ctypedef struct svn_ra_callbacks2_t:
            svn_error_t * (* open_tmp_file)(
                    apr_file_t ** fp, void * callback_baton, apr_pool_t * pool)
            svn_auth_baton_t * auth_baton
            svn_ra_get_wc_prop_func_t get_wc_prop
            svn_ra_set_wc_prop_func_t set_wc_prop
            svn_ra_push_wc_prop_func_t push_wc_prop
            svn_ra_invalidate_wc_props_func_t invalidate_wc_props
            svn_ra_progress_notify_func_t progress_func

    svn_error_t * svn_ra_initialize(apr_pool_t * pool)
    IF SVN_API_VER >= (1, 3):
        svn_error_t * svn_ra_create_callbacks(
                svn_ra_callbacks2_t ** callbacks, apr_pool_t * pool)
    ctypedef struct svn_ra_session_t:
        pass
    IF SVN_API_VER >= (1, 7):
        svn_error_t * svn_ra_open4(
                svn_ra_session_t ** session_p, const char ** corrected_url,
                const char * repos_URL, const char * uuid,
                const svn_ra_callbacks2_t * callbacks,
                void * callback_baton, apr_hash_t * config, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 5):
        svn_error_t * svn_ra_open3(
                svn_ra_session_t ** session_p, const char * repos_URL,
                const char * uuid, const svn_ra_callbacks2_t * callbacks,
                void * callback_baton, apr_hash_t * config, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 3):
        svn_error_t * svn_ra_open2(
                svn_ra_session_t ** session_p, const char * repos_URL,
                const svn_ra_callbacks2_t * callbacks, void * callback_baton,
                apr_hash_t * config, apr_pool_t *pool)
