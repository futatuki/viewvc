include "_svn_api_ver.pxi"
from apr_1.apr_pools cimport apr_pool_t
from apr_1.apr_hash cimport apr_hash_t
from subversion_1.svn_types cimport svn_error_t, svn_boolean_t, svn_revnum_t
from subversion_1.svn_fs cimport svn_fs_t, svn_fs_root_t
from subversion_1.svn_delta cimport svn_delta_editor_t 

cdef extern from "svn_repos.h" nogil:
    ctypedef svn_error_t * (* svn_repos_authz_func_t)(
                svn_boolean_t * allowed, svn_fs_root_t * root,
                const char * path, void * baton, apr_pool_t * pool)
    ctypedef struct svn_repos_t:
        pass
    IF SVN_API_VER >= (1, 9):
        svn_error_t * svn_repos_open3(
                svn_repos_t ** repos_p, const char * path,
                apr_hash_t * fs_config, apr_pool_t * result_pool,
                apr_pool_t * scratch_pool)
    IF SVN_API_VER >= (1, 7):
        svn_error_t * svn_repos_open2(
                svn_repos_t ** repos_p, const char * path,
                apr_hash_t * fs_config, apr_pool_t * pool)
    svn_error_t * svn_repos_open(
                svn_repos_t ** repos_p, const char * path, apr_pool_t *)
    svn_fs_t * svn_repos_fs(svn_repos_t * repos)

    IF SVN_API_VER >= (1, 4):
        svn_error_t * svn_repos_replay2(
                svn_fs_root_t * root, const char * base_dir,
                svn_revnum_t low_water_mark, svn_boolean_t send_deltas,
                const svn_delta_editor_t * editor, void * edit_baton,
                svn_repos_authz_func_t authz_read_func,
                void * authz_read_baton, apr_pool_t * pool)
    svn_error_t * svn_repos_replay(
            svn_fs_root_t * root, const svn_delta_editor_t * editor,
            void * edit_baton, apr_pool_t * pool)
    ctypedef svn_error_t * (* svn_repos_history_func_t)(
            void *baton, const char *path, svn_revnum_t revision,
            apr_pool_t *pool)
    svn_error_t * svn_repos_history2( 
            svn_fs_t * fs, const char * path,
            svn_repos_history_func_t history_func, void * history_baton,
            svn_repos_authz_func_t authz_read_func, void * authz_read_baton,
            svn_revnum_t start, svn_revnum_t end, svn_boolean_t cross_copies,
            apr_pool_t * pool)
