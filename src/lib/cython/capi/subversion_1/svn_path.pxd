from apr_1.apr_pools cimport apr_pool_t
from subversion_1.svn_types cimport svn_boolean_t

cdef extern from "svn_path.h" nogil: 
    const char * svn_path_canonicalize(const char * path, apr_pool_t * pool)
    svn_boolean_t svn_path_is_url(const char *path) 
    const char * svn_path_uri_encode(const char * path, apr_pool_t * pool)

