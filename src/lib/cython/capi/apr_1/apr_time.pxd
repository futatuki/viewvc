from apr_1.apr cimport *

cdef extern from "apr_time.h" nogil:
    ctypedef apr_int64_t apr_time_t
    ctypedef struct apr_time_exp_t:
        apr_int32_t tm_usec
        apr_int32_t tm_sec
        apr_int32_t tm_min
        apr_int32_t tm_hour
        apr_int32_t tm_mday
        apr_int32_t tm_mon
        apr_int32_t tm_year
        apr_int32_t tm_wday
        apr_int32_t tm_yday
        apr_int32_t tm_isdst
        apr_int32_t tm_gmtoff
    apr_time_t apr_time_now()
