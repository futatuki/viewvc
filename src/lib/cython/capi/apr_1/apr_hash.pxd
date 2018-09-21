from apr_1.apr cimport *
from apr_1.apr_pools cimport *

cdef extern from "apr_hash.h" nogil:
    cdef apr_ssize_t APR_HASH_KEY_STRING
    ctypedef struct apr_hash_t:
        pass
    ctypedef struct apr_hash_index_t:
        pass
    ctypedef unsigned int (*apr_hashfunc_t)(const char *key, apr_ssize_t *klen)
    cdef apr_hashfunc_default(const char *key, apr_ssize_t *klen) with gil
    apr_hash_t * apr_hash_make(apr_pool_t *pool)
    apr_hash_t * apr_hash_make_custom(apr_pool_t *pool,
        apr_hashfunc_t hash_func) with gil
    void apr_hash_set(apr_hash_t *ht, const void *key,
        apr_ssize_t klen, const void *val)
    void * apr_hash_get(apr_hash_t *ht, const void *key, apr_ssize_t klen)
    apr_hash_index_t * apr_hash_first(apr_pool_t *p, apr_hash_t *ht)
    apr_hash_index_t * apr_hash_next(apr_hash_index_t *hi)
    void apr_hash_this(apr_hash_index_t *hi, const void **key,
        apr_ssize_t *klen, void **val)
    void apr_hash_clear(apr_hash_t *ht)
