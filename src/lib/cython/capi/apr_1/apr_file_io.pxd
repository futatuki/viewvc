cdef extern from "apr_file_io.h" nogil:
    ctypedef struct apr_file_t:
        pass
    # flags -- backcompat
    enum: APR_READ
    enum: APR_WRITE
    enum: APR_CREATE
    enum: APR_APPEND
    enum: APR_TRUNCATE
    enum: APR_BINARY
    enum: APR_EXCL
    enum: APR_BUFFERED
    enum: APR_DELONCLOSE
    enum: APR_XTHREAD
    enum: APR_SHARELOCK
    enum: APR_FILE_NOCLEANUP
    enum: APR_SENDFILE_ENABLED
    enum: APR_LARGEFILE
    # permission -- backcompat
    enum: APR_OS_DEFAULT

