include "_svn_api_ver.pxi"
from subversion_1 cimport svn_delta
from subversion_1 cimport svn_repos

cdef class svn_repos_t(object):
    cdef svn_repos.svn_repos_t * _c_ptr
    cdef svn_repos_t set_repos(
            svn_repos_t self, svn_repos.svn_repos_t * repos)

