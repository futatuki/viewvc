from apr_1.apr cimport apr_int32_t

cdef extern from "apr_file_info.h" nogil:
    ctypedef apr_int32_t apr_fileperms_t
