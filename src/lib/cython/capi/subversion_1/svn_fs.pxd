include "_svn_api_ver.pxi"
from apr_1.apr_pools cimport apr_pool_t
from apr_1.apr_hash cimport apr_hash_t
from subversion_1.svn_types cimport * 
from subversion_1.svn_string cimport svn_string_t
from subversion_1.svn_io cimport svn_stream_t

cdef extern from "svn_fs.h" nogil:
    ctypedef struct svn_fs_t:
        pass
    ctypedef struct svn_fs_root_t:
        pass
    ctypedef struct svn_fs_id_t:
        pass
    int svn_fs_compare_ids(const svn_fs_id_t * a, const svn_fs_id_t * b)
    svn_error_t * svn_fs_revision_root(
            svn_fs_root_t ** root_p, svn_fs_t * fs, svn_revnum_t rev,
            apr_pool_t * pool)
    void svn_fs_close_root(svn_fs_root_t * root)
    svn_boolean_t svn_fs_is_revision_root(svn_fs_root_t * root)
    svn_revnum_t svn_fs_revision_root_revision(svn_fs_root_t * root)
    ctypedef enum svn_fs_path_change_kind_t:
        svn_fs_path_change_modify = 0
        svn_fs_path_change_add
        svn_fs_path_change_delete
        svn_fs_path_change_replace
        svn_fs_path_change_reset
    IF SVN_API_VER >= (1, 10):
        ctypedef struct svn_fs_path_change3_t:
            svn_string_t path
            svn_fs_path_change_kind_t change_kind
            svn_node_kind_t node_kind
            svn_boolean_t text_mod
            svn_boolean_t prop_mod
            svn_tristate_t mergeinfo_mod
            svn_boolean_t copyfrom_known
            const char * copyfrom_path
    IF SVN_API_VER >= (1, 9):
        ctypedef struct svn_fs_path_change2_t:
            const svn_fs_id_t * node_rev_id
            svn_fs_path_change_kind_t change_kind
            svn_boolean_t text_mod
            svn_boolean_t prop_mod
            svn_node_kind_t node_kind
            svn_boolean_t copyfrom_known
            svn_revnum_t copyfrom_rev
            const char * copyfrom_path
            svn_tristate_t mergeinfo_mod
    ELIF SVN_API_VER >= (1, 6):
        ctypedef struct svn_fs_path_change2_t:
            const svn_fs_id_t * node_rev_id
            svn_fs_path_change_kind_t change_kind
            svn_boolean_t text_mod
            svn_boolean_t prop_mod
            svn_node_kind_t node_kind
            svn_boolean_t copyfrom_known
            svn_revnum_t copyfrom_rev
            const char * copyfrom_path
    ctypedef struct svn_fs_path_change_t:
        const svn_fs_id_t * node_rev_id
        svn_fs_path_change_kind_t change_kind
        svn_boolean_t text_mod
        svn_boolean_t prop_mod
    IF SVN_API_VER >= (1, 10):
        ctypedef struct svn_fs_path_change_iterator_t:
            pass
        svn_error_t * svn_fs_path_change_get(
                svn_fs_path_change3_t ** change,
                svn_fs_path_change_iterator_t * iterator)
        svn_error_t * svn_fs_paths_changed3(
                svn_fs_path_change_iterator_t ** iterator,
                svn_fs_root_t * root,
                apr_pool_t * result_pool, apr_pool_t * scratch_pool)
    IF SVN_API_VER >= (1, 6):
        # deprecated (in 1.10.)
        svn_error_t * svn_fs_paths_changed2(
                apr_hash_t ** changed_paths2_p, svn_fs_root_t * root,
                apr_pool_t * pool)
    # deprecated (in 1.6.)
    svn_error_t * svn_fs_paths_changed(
                apr_hash_t ** changed_paths_p, svn_fs_root_t * root,
                apr_pool_t * pool)
    svn_error_t * svn_fs_check_path(
            svn_node_kind_t * kind_p, svn_fs_root_t * root,
            const char * path, apr_pool_t * pool)
    ctypedef struct svn_fs_history_t:
        pass
    IF SVN_API_VER >= (1, 10):
        svn_error_t * svn_fs_node_history2(
                svn_fs_history_t ** history_p, svn_fs_root_t * root,
                const char * path, apr_pool_t * result_pool,
                apr_pool_t * scratch_pool)
        svn_error_t * svn_fs_history_prev2(
                svn_fs_history_t ** prev_history_p, svn_fs_history_t * history,
                svn_boolean_t cross_copies, apr_pool_t *result_pool,
                apr_pool_t *scratch_pool)
    # deprecated (in 1.10.)
    svn_error_t * svn_fs_node_history(
            svn_fs_history_t ** history_p, svn_fs_root_t * root,
            const char * path, apr_pool_t * pool)
    # deprecated (in 1.10.)
    svn_error_t * svn_fs_history_prev(
            svn_fs_history_t ** prev_history_p, svn_fs_history_t * history,
            svn_boolean_t cross_copies, apr_pool_t *pool)
    svn_error_t * svn_fs_history_location(
            const char ** path, svn_revnum_t * revision,
            svn_fs_history_t * history, apr_pool_t * pool)
    svn_error_t * svn_fs_is_dir(
            svn_boolean_t * is_dir, svn_fs_root_t * root,
            const char * path, apr_pool_t * pool)
    svn_error_t * svn_fs_is_file(
            svn_boolean_t * is_file, svn_fs_root_t * root,
            const char * path, apr_pool_t * pool)
    svn_error_t * svn_fs_node_id(
            const svn_fs_id_t ** id_p, svn_fs_root_t * root,
            const char * path, apr_pool_t * pool)
    svn_error_t * svn_fs_node_created_rev(
            svn_revnum_t * revision, svn_fs_root_t * root,
            const char * path, apr_pool_t * pool);
    svn_error_t * svn_fs_node_proplist(
            apr_hash_t ** table_p, svn_fs_root_t * root,
            const char * path, apr_pool_t * pool);
    svn_error_t * svn_fs_copied_from(
            svn_revnum_t * rev_p, const char ** path_p, svn_fs_root_t * root,
            const char * path, apr_pool_t * pool)
    ctypedef struct svn_fs_dirent_t:
        const char * name
        const svn_fs_id_t * id
        svn_node_kind_t kind
    svn_error_t * svn_fs_dir_entries(
            apr_hash_t ** entries_p, svn_fs_root_t * root,
            const char * path, apr_pool_t *pool)
    svn_error_t * svn_fs_file_length(
            svn_filesize_t * length_p, svn_fs_root_t * root,
            const char * path, apr_pool_t *pool)
    svn_error_t * svn_fs_file_contents(
            svn_stream_t ** contents, svn_fs_root_t * root,
            const char * path, apr_pool_t *pool)
    svn_error_t * svn_fs_youngest_rev(
            svn_revnum_t * youngest_p, svn_fs_t * fs, apr_pool_t * pool)
    IF SVN_API_VER >= (1, 10):
        svn_error_t * svn_fs_revision_proplist2(
                apr_hash_t ** table_p, svn_fs_t * fs, svn_revnum_t rev,
                svn_boolean_t refresh, apr_pool_t * result_pool,
                apr_pool_t *scratch_pool)
    # deprecated (in 1.10.)
    svn_error_t * svn_fs_revision_proplist(
            apr_hash_t ** table_p, svn_fs_t * fs, svn_revnum_t rev,
            apr_pool_t * pool)
    svn_error_t * svn_fs_get_lock(
              svn_lock_t ** lock, svn_fs_t * fs, const char * path,
              apr_pool_t * pool)
