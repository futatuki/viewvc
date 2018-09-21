from libc.stddef cimport size_t
from libc.stdint cimport int16_t,uint16_t,int32_t,uint32_t,int64_t,uint64_t
from posix.types cimport off_t

cdef extern from "apr.h" nogil:
    ctypedef unsigned char apr_byte_t
    ctypedef int16_t apr_int16_t
    ctypedef uint16_t apr_uint16_t
    ctypedef int32_t apr_int32_t
    ctypedef uint32_t apr_uint32_t
    ctypedef int64_t apr_int64_t
    ctypedef uint64_t apr_uint64_t
    ctypedef size_t apr_size_t
    ctypedef Py_ssize_t apr_ssize_t
    ctypedef off_t apr_off_t
    ctypedef uint64_t apr_uintptr_t
    const char * APR_EOL_STR

