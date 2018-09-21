include "_svn_api_ver.pxi"

cdef extern from "svn_error_codes.h":
    enum: SVN_NO_ERROR
    enum: SVN_ERR_BASE
    enum: SVN_ERR_FS_NOT_FOUND
    enum: SVN_ERR_CLIENT_IS_BINARY_FILE
    enum: SVN_ERR_CANCELLED
    enum: SVN_ERR_ASSERTION_FAIL
    IF SVN_API_VER >= (1, 5):
        enum: SVN_ERR_CEASE_INVOCATION
