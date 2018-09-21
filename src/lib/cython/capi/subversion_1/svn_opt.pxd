from subversion_1.svn_types cimport svn_revnum_t
from apr_1.apr_time cimport apr_time_t

cdef extern from "svn_opt.h":
    cdef enum svn_opt_revision_kind:
        svn_opt_revision_unspecified
        svn_opt_revision_number
        svn_opt_revision_date
        svn_opt_revision_committed
        svn_opt_revision_previous
        svn_opt_revision_base
        svn_opt_revision_working
        svn_opt_revision_head
    ctypedef union svn_opt_revision_value_t:
        svn_revnum_t number
        apr_time_t date
    ctypedef struct svn_opt_revision_t:
        svn_opt_revision_kind kind
        svn_opt_revision_value_t value
    ctypedef struct svn_opt_revision_range_t:
        svn_opt_revision_t start
        svn_opt_revision_t end
