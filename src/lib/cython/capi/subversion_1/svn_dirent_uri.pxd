from apr_1.apr_pools cimport apr_pool_t
from subversion_1.svn_types cimport svn_error_t

include "_svn_api_ver.pxi"

cdef extern from "svn_dirent_uri.h" nogil:
    IF SVN_API_VER >= (1, 6):
        const char * svn_dirent_canonicalize(
                const char *dirent, apr_pool_t *result_pool)
    IF SVN_API_VER >= (1, 7):
        const char * svn_uri_canonicalize(
                const char *uri, apr_pool_t *result_pool)
        svn_error_t * svn_uri_get_dirent_from_file_url(
                const char **dirent, const char *url, apr_pool_t *result_pool)
        svn_error_t * svn_uri_get_file_url_from_dirent(
                const char **url, const char *dirent, apr_pool_t *result_pool)
