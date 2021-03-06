from apr_1.apr cimport apr_int64_t
from apr_1.apr_errno cimport apr_status_t
from apr_1.apr_pools cimport apr_pool_t
from apr_1.apr_hash cimport apr_hash_t
from apr_1.apr_time cimport apr_time_t

include "_svn_api_ver.pxi"

cdef extern from "svn_types.h" nogil:
    ctypedef int svn_boolean_t
    enum: TRUE
    enum: FALSE
    ctypedef struct svn_error_t:
        apr_status_t apr_err
        const char *message
        svn_error_t *child
        apr_pool_t *pool
        const char *file
        long line
    ctypedef struct svn_version_t:
        pass

    IF SVN_API_VER >= (1, 8):
        ctypedef enum svn_node_kind_t:
            svn_node_none, svn_node_file, svn_node_dir,
            svn_node_unknown, svn_node_symlink
    ELSE:
        ctypedef enum svn_node_kind_t:
            svn_node_none, svn_node_file, svn_node_dir,
            svn_node_unknown
    IF SVN_API_VER >= (1, 6):
        const char * svn_node_kind_to_word(svn_node_kind_t kind)
        svn_node_kind_t svn_node_kind_from_word(const char *word)
    IF SVN_API_VER >= (1, 7):
        ctypedef enum svn_tristate_t:
            svn_tristate_false =2, svn_tristate_true, svn_tristate_unknown
        const char * svn_tristate__to_word(svn_tristate_t tristate)
        svn_tristate_t svn_tristate__from_word(const char *word)
    ctypedef long int svn_revnum_t
    enum: SVN_INVALID_REVNUM
    enum: SVN_IGNORED_REVNUM
    IF SVN_API_VER >= (1, 5):
        svn_error_t * svn_revnum_parse(svn_revnum_t *rev,
                                       const char *str,
                                       const char **endptr)
    ctypedef apr_int64_t svn_filesize_t
    enum: SVN_INVALID_FILESIZE
    ctypedef enum svn_recurse_kind:
        svn_nonrecursive = 1, svn_recursive
    IF SVN_API_VER >= (1, 5):
        ctypedef enum svn_depth_t:
            svn_depth_unknown = -2
            svn_depth_exclude = -1
            svn_depth_empty = 0
            svn_depth_files = 1
            svn_depth_immediates = 2
            svn_depth_infinity = 3
        const char * svn_depth_to_word(svn_depth_t depth)
        svn_depth_t svn_depth_from_word(const char *word)
    IF SVN_API_VER >= (1, 3):
        ctypedef struct svn_dirent_t:
            svn_node_kind_t kind
            svn_filesize_t size
            svn_boolean_t has_props
            svn_revnum_t created_rev
            apr_time_t time
            const char *last_author
    enum: SVN_DIRENT_KIND
    enum: SVN_DIRENT_SIZE
    enum: SVN_DIRENT_HAS_PROPS
    enum: SVN_DIRENT_CREATED_REV
    enum: SVN_DIRENT_TIME
    enum: SVN_DIRENT_LAST_AUTHOR
    enum: SVN_DIRENT_ALL
    enum: SVN_STREAM_CHUNK_SIZE
    ctypedef struct svn_log_changed_path_t:
        char action
        const char * copyfrom_path
        svn_revnum_t copyfrom_rev
    IF SVN_API_VER >= (1, 7):
        ctypedef struct svn_log_changed_path2_t:
            char action
            const char * copyfrom_path
            svn_revnum_t copyfrom_rev
            svn_node_kind_t node_kind
            svn_tristate_t text_modified
            svn_tristate_t props_modified
    ELIF SVN_API_VER >= (1, 6):
        ctypedef struct svn_log_changed_path2_t:
            char action
            const char * copy_from_path
            svn_revnum_t copyfrom_rev
            svn_node_kind_t node_kind
    IF SVN_API_VER >= (1, 7):
        ctypedef struct svn_log_entry_t:
            apr_hash_t * changed_paths
            svn_revnum_t revision
            apr_hash_t * revprops
            svn_boolean_t has_children
            apr_hash_t * changed_paths2
            svn_boolean_t non_inheritable
            svn_boolean_t subtractive_merge
    ELIF SVN_API_VER >= (1, 6):
        ctypedef struct svn_log_entry_t:
            apr_hash_t * changed_paths
            svn_revnum_t revision
            apr_hash_t * revprops
            svn_boolean_t has_children
            apr_hash_t * changed_paths2
    ELIF SVN_API_VER >= (1, 5):
        ctypedef struct svn_log_entry_t:
            apr_hash_t * changed_paths
            svn_revnum_t revision
            apr_hash_t * revprops
            svn_boolean_t has_children
    IF SVN_API_VER >= (1, 5):
        ctypedef svn_error_t * (* svn_log_entry_receiver_t)(
                void * baton, svn_log_entry_t * log_entry, apr_pool_t * pool)
    ctypedef svn_error_t * (* svn_log_message_receiver_t)(
            void * baton, apr_hash_t * changed_paths, svn_revnum_t revision,
            const char * author, const char * date, const char * message,
            apr_pool_t * pool)

    ctypedef svn_error_t * (* svn_cancel_func_t)(void * cancel_baton)
    IF SVN_API_VER >= (1, 2):
        ctypedef struct svn_lock_t:
            const char *path
            const char *token
            const char *owner
            const char *comment
            svn_boolean_t is_dav_comment
            apr_time_t creation_date
            apr_time_t expiration_date
