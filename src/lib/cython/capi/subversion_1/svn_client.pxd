include "_svn_api_ver.pxi"
from apr_1.apr cimport apr_int64_t, apr_uint32_t, apr_size_t
from apr_1.apr_pools cimport apr_pool_t
from apr_1.apr_hash cimport apr_hash_t
from apr_1.apr_tables cimport apr_array_header_t
from subversion_1.svn_types cimport *
from subversion_1.svn_opt cimport svn_opt_revision_t
from subversion_1.svn_auth cimport *
from subversion_1.svn_io cimport svn_stream_t
from subversion_1.svn_wc cimport svn_wc_info_t, svn_wc_schedule_t
IF SVN_API_VER >= (1, 4):
    from subversion_1.svn_diff cimport svn_diff_file_options_t

cdef extern from "svn_client.h" nogil:
    IF SVN_API_VER < (1, 4):
        # of course, these functions are provided for API version 1.4 and
        # above for compatibility, but in those case, we use newer API instead
        void svn_client_get_simple_provider(
                svn_auth_provider_object_t ** provider, apr_pool_t * pool)
        void svn_client_get_username_provider(
                svn_auth_provider_object_t ** provider, apr_pool_t * pool)
        void svn_client_get_ssl_server_trust_file_provider(
                svn_auth_provider_object_t ** provider, apr_pool_t * pool)
        void svn_client_get_ssl_client_cert_file_provider(
                svn_auth_provider_object_t ** provider, apr_pool_t * pool)
        void svn_client_get_ssl_client_cert_pw_file_provider(
                svn_auth_provider_object_t ** provider, apr_pool_t * pool)
    # we don't use full feature of structure svn_client_ctx_t,
    # and Cython allowes partial declaration of members ...
    ctypedef struct svn_client_ctx_t:
        svn_auth_baton_t * auth_baton
        # svn_wc_notify_func_t notify_func
        # void * notify_baton
        # svn_client_get_commit_log_t log_msg_func
        # void * log_msg_baton
        apr_hash_t * config
        # svn_cancel_func_t cancel_func
        # void * cancel_baton
        # svn_wc_notify_func2_t notify_func2
        # void * notify_baton2
        # svn_client_get_commit_log2_t log_msg_func2
        # void * log_msg_baton2
        # svn_ra_progress_notify_func_t progress_func
        # void * progress_baton
        # svn_client_get_commit_log3_t log_msg_func3
        # void * log_msg_baton3
        # apr_hash_t mimetype_map
        # svn_wc_conflict_resolver_func_t conflict_func
        # void * conflict_baton
        const char * client_name
        # svn_wc_conflict_resolver_func2_t conflict_func2
        # void *conflict_baton2
        # svn_wc_context_t * wc_ctx
        # svn_ra_check_tunnel_func_t check_tunnel_func
        # svn_ra_open_tunnel_func_t open_tunnel_func
        # void * tunnel_baton
    IF SVN_API_VER >= (1, 8):
        svn_error_t * svn_client_create_context2(
                svn_client_ctx_t ** ctx, apr_hash_t *cfg_hash,
                apr_pool_t *pool)
    svn_error_t * svn_client_create_context(
            svn_client_ctx_t ** ctx, apr_pool_t *pool)

    # for client_blame*()
    IF SVN_API_VER >= (1, 7):
        ctypedef svn_error_t * (* svn_client_blame_receiver3_t)(
                void * baton,
                svn_revnum_t start_revnum, svn_revnum_t end_revnum,
                apr_int64_t line_no,
                svn_revnum_t revision, apr_hash_t * rev_props,
                svn_revnum_t merged_revision, apr_hash_t * merged_rev_props,
                const char * merged_path,
                const char * line, svn_boolean_t local_change,
                apr_pool_t * pool)
        svn_error_t * svn_client_blame5(
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * start,
                const svn_opt_revision_t * end,
                const svn_diff_file_options_t * diff_options,
                svn_boolean_t ignore_mime_type,
                svn_boolean_t include_merged_revisions,
                svn_client_blame_receiver3_t receiver,
                void * receiver_baton, svn_client_ctx_t * ctx,
                apr_pool_t * pool)
    IF SVN_API_VER >= (1, 5):
        ctypedef svn_error_t * (* svn_client_blame_receiver2_t)(
                void * baton, apr_int64_t line_no, svn_revnum_t revision,
                const char * author, const char * date,
                svn_revnum_t merged_revision, const char * merged_author,
                const char * merged_date, const char * merged_path,
                const char * line, apr_pool_t * pool)
        svn_error_t * svn_client_blame4(
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * start,
                const svn_opt_revision_t * end,
                const svn_diff_file_options_t * diff_options,
                svn_boolean_t ignore_mime_type,
                svn_boolean_t include_merged_revisions,
                svn_client_blame_receiver2_t receiver, void * receiver_baton,
                svn_client_ctx_t * ctx, apr_pool_t * pool)
    ctypedef svn_error_t * (* svn_client_blame_receiver_t)(
            void * baton, apr_int64_t line_no, svn_revnum_t revision,
            const char * author, const char * date, const char * line,
            apr_pool_t * pool)
    IF SVN_API_VER >= (1, 4):
        svn_error_t * svn_client_blame3(
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * start,
                const svn_opt_revision_t * end,
                const svn_diff_file_options_t * diff_options,
                svn_boolean_t ignore_mime_type,
                svn_client_blame_receiver_t receiver, void * receiver_baton,
                svn_client_ctx_t * ctx, apr_pool_t * pool)
    svn_error_t * svn_client_blame2(
            const char * path_or_url, const svn_opt_revision_t * peg_revision,
            const svn_opt_revision_t * start, const svn_opt_revision_t * end,
            svn_client_blame_receiver_t receiver, void * receiver_baton,
            svn_client_ctx_t * ctx, apr_pool_t * pool)

    IF SVN_API_VER >= (1, 8):
        ctypedef svn_error_t * (* svn_client_list_func2_t)(
                void * baton, const char * path, const svn_dirent_t * dirent,
                const svn_lock_t * lock, const char * abs_path,
                const char * external_parent_url, const char * external_target,
                apr_pool_t * scratch_pool)
    IF SVN_API_VER >= (1, 4):
        ctypedef svn_error_t  *(* svn_client_list_func_t)(
                void * baton, const char * path, const svn_dirent_t * dirent,
                const svn_lock_t * lock, const char * abs_path,
                apr_pool_t * pool)
    IF SVN_API_VER >= (1, 10):
        svn_error_t * svn_client_list4(
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * revision,
                const apr_array_header_t *patterns,
                svn_depth_t depth, apr_uint32_t dirent_fields,
                svn_boolean_t fetch_locks, svn_boolean_t include_externals,
                svn_client_list_func2_t list_func, void * baton,
                svn_client_ctx_t * ctx, apr_pool_t * scratch_pool)
    IF SVN_API_VER >= (1, 8):
        svn_error_t * svn_client_list3(
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * revision,
                svn_depth_t depth, apr_uint32_t dirent_fields,
                svn_boolean_t fetch_locks, svn_boolean_t include_externals,
                svn_client_list_func2_t list_func, void * baton,
                svn_client_ctx_t * ctx, apr_pool_t * scratch_pool)
    IF SVN_API_VER >= (1, 5):
        svn_error_t * svn_client_list2(
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * revision,
                svn_depth_t depth, apr_uint32_t dirent_fields,
                svn_boolean_t fetch_locks, svn_client_list_func_t list_func,
                void * baton, svn_client_ctx_t * ctx, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 4):
        svn_error_t * svn_client_list(
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * revision,
                svn_boolean_t recurse, apr_uint32_t dirent_fields,
                svn_boolean_t fetch_locks, svn_client_list_func_t list_func,
                void * baton, svn_client_ctx_t * ctx, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 3):
        svn_error_t * svn_client_ls3(
                apr_hash_t ** dirents, apr_hash_t ** locks,
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * revision,
                svn_boolean_t recurse, svn_client_ctx_t * ctx,
                apr_pool_t * pool)
    IF SVN_API_VER >= (1, 8):
        svn_error_t * svn_client_cat3(
                apr_hash_t ** props, svn_stream_t * out,
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * revision,
                svn_boolean_t expand_keywords, svn_client_ctx_t * ctx,
                apr_pool_t * result_pool, apr_pool_t * scratch_pool)
    IF SVN_API_VER >= (1, 2):
        svn_error_t * svn_client_cat2(
                svn_stream_t * out, const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * revision,
                svn_client_ctx_t * ctx, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 7):
        ctypedef struct svn_client_info2_t:
            const char *URL
            svn_revnum_t rev
            const char *repos_root_URL
            const char *repos_UUID
            svn_node_kind_t kind
            svn_filesize_t size
            svn_revnum_t last_changed_rev
            apr_time_t last_changed_date
            const char *last_changed_author
            const svn_lock_t *lock
            const svn_wc_info_t *wc_info
        ctypedef svn_error_t * (*svn_client_info_receiver2_t)(
                void *baton, const char *abspath_or_url,
                const svn_client_info2_t *info, apr_pool_t *scratch_pool)
    IF SVN_API_VER >= (1, 9):
        svn_error_t * svn_client_info4(
                const char *abspath_or_url,
                const svn_opt_revision_t *peg_revision,
                const svn_opt_revision_t *revision, svn_depth_t depth,
                svn_boolean_t fetch_excluded, svn_boolean_t fetch_actual_only,
                svn_boolean_t include_externals,
                const apr_array_header_t *changelists,
                svn_client_info_receiver2_t receiver, void *receiver_baton,
                svn_client_ctx_t *ctx, apr_pool_t *scratch_pool)
    IF SVN_API_VER >= (1, 7):
        svn_error_t * svn_client_info3(
                const char *abspath_or_url,
                const svn_opt_revision_t *peg_revision,
                const svn_opt_revision_t *revision,
                svn_depth_t depth,
                svn_boolean_t fetch_excluded,
                svn_boolean_t fetch_actual_only,
                const apr_array_header_t *changelists,
                svn_client_info_receiver2_t receiver,
                void *receiver_batton,
                svn_client_ctx_t *ctx,
                apr_pool_t *scratch_pool)
    IF SVN_API_VER >= (1, 5):
        ctypedef struct svn_info_t:
            const char * URL
            svn_revnum_t rev
            svn_node_kind_t kind
            const char * repos_root_URL
            const char * repos_UUID
            svn_revnum_t last_changed_rev
            apr_time_t last_changed_date
            const char * last_changed_author
            svn_lock_t * lock
            svn_boolean_t has_wc_info
            svn_wc_schedule_t schedule
            const char * copyfrom_url
            svn_revnum_t copyfrom_rev
            apr_time_t text_time
            apr_time_t prop_time
            const char * checksum
            const char * conflict_old
            const char * conflict_new
            const char * conflict_wrk
            const char * prejfile
            const char * changelist
            svn_depth_t depth
            apr_size_t working_size
    ELSE:
        ctypedef struct svn_info_t:
            const char * URL
            svn_revnum_t rev
            svn_node_kind_t kind
            const char * repos_root_URL
            const char * repos_UUID
            svn_revnum_t last_changed_rev
            apr_time_t last_changed_date
            const char * last_changed_author
            svn_locK_t * lock
            svn_boolean_t has_wc_info
            svn_wc_schedule_t schedule
            const char * copyfrom_url
            svn_revnum_t copyfrom_rev
            apr_time_t text_time
            apr_time_t prop_time
            const char * checksum
            const char * conflict_old
            const char * conflict_new
            const char * conflict_wrk
            const char * prejfile
    IF SVN_API_VER >= (1, 2):
        ctypedef svn_error_t * (* svn_info_receiver_t)(
                void * baton, const char * path, const svn_info_t * info,
                apr_pool_t * pool)
    IF SVN_API_VER >= (1, 5):
        svn_error_t * svn_client_info2(
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * revision,
                svn_info_receiver_t receiver, void * receiver_baton,
                svn_depth_t depth, const apr_array_header_t * changelists,
                svn_client_ctx_t * ctx, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 2):
        svn_error_t * svn_client_info(
                const char * path_or_url,
                const svn_opt_revision_t * peg_revision,
                const svn_opt_revision_t * revision,
                svn_info_receiver_t receiver, void * receiver_baton,
                svn_boolean_t recurse, svn_client_ctx_t * ctx,
                apr_pool_t * pool)
