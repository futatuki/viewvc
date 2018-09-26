include "_svn_api_ver.pxi"
from apr_1.apr cimport apr_int64_t
from apr_1.apr_hash cimport apr_hash_t
from apr_1.apr_pools cimport apr_pool_t
from subversion_1.svn_types cimport svn_error_t, svn_boolean_t, svn_revnum_t
from subversion_1.svn_opt cimport svn_opt_revision_t
from subversion_1.svn_auth cimport svn_auth_baton_t
IF SVN_API_VER >= (1, 4):
    from subversion_1.svn_diff cimport svn_diff_file_options_t

cdef extern from "svn_client.h" nogil:
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
