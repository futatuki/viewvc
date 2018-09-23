include "_svn_api_ver.pxi"
from apr_1.apr_pools cimport apr_pool_t
from subversion_1.svn_types cimport svn_boolean_t

IF SVN_API_VER >= (1, 4):
    cdef extern from "svn_diff.h" nogil:
        ctypedef enum svn_diff_file_ignore_space_t:
            svn_diff_file_ignore_space_none
            svn_diff_file_ignore_space_change
            svn_diff_file_ignore_space_all
        IF SVN_API_VER >= (1, 9):
            ctypedef struct svn_diff_file_options_t:
                svn_diff_file_ignore_space_t ignore_space
                svn_boolean_t ignore_eol_style
                svn_boolean_t show_c_function
                int context_size
        ELIF SVN_API_VER >= (1, 5):
            ctypedef struct svn_diff_file_options_t:
                svn_diff_file_ignore_space_t ignore_space
                svn_boolean_t ignore_eol_style
                svn_boolean_t show_c_function
        ELIF SVN_API_VER >= (1, 4):
            ctypedef struct svn_diff_file_options_t:
                svn_diff_file_ignore_space_t ignore_space
                svn_boolean_t ignore_eol_style
        svn_diff_file_options_t * svn_diff_file_options_create(
                    apr_pool_t * pool)
