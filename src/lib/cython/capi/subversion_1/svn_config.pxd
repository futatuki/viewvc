from apr_1.apr_hash cimport apr_hash_t
from apr_1.apr_pools cimport apr_pool_t
from subversion_1.svn_types cimport svn_error_t

cdef extern from "svn_string.h" nogil:
    svn_error_t * svn_config_get_config(
            apr_hash_t ** cfg_hash, const char * config_dir, apr_pool_t * pool)
    svn_error_t * svn_config_ensure(const char * config_dir, apr_pool_t * pool)
