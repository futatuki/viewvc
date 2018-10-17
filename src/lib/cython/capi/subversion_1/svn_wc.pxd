include "_svn_api_ver.pxi"
from apr_1.apr cimport apr_int64_t, apr_uint32_t
from apr_1.apr_pools cimport apr_pool_t
from apr_1.apr_tables cimport apr_array_header_t
from apr_1.apr_time cimport apr_time_t
from subversion_1.svn_types cimport *
from subversion_1.svn_checksum cimport svn_checksum_t

cdef extern from "svn_wc.h" nogil:
    ctypedef enum svn_wc_schedule_t:
        svn_wc_schedule_normal
        svn_wc_schedule_add
        svn_wc_schedule_delete
        svn_wc_schedule_replace
    IF SVN_API_VER >= (1, 8):
        ctypedef struct svn_wc_info_t:
            svn_wc_schedule_t schedule
            const char * copyfrom_url
            svn_revnum_t copyfrom_rev
            const svn_checksum_t *checksum
            const char * changelist
            svn_depth_t depth
            svn_filesize_t recorded_size
            apr_time_t recorded_time
            const apr_array_header_t * conflicts
            const char * wcroot_abspath
            const char * moved_from_abspath
            const char * moved_to_abspath
    ELSE:
        ctypedef struct svn_wc_info_t:
            svn_wc_schedule_t schedule
            const char * copyfrom_url
            svn_revnum_t copyfrom_rev
            const svn_checksum_t *checksum
            const char * changelist
            svn_depth_t depth
            svn_filesize_t recorded_size
            apr_time_t recorded_time
            const apr_array_header_t * conflicts
            const char * wcroot_abspath
