include "_svn_api_ver.pxi"
cimport _svn_ra_capi as _c_
cimport _svn

cdef class svn_client_ctx_t(object):
    cdef _c_.svn_client_ctx_t * _c_ctx 
    cdef _svn.Apr_Pool pool
    cdef svn_client_ctx_t set_ctx(self, _c_.svn_client_ctx_t * ctx, pool)

cdef class svn_ra_session_t(object):
    cdef _c_.svn_ra_session_t * _c_session
    cdef _svn.Apr_Pool pool
    cdef svn_ra_session_t set_session(
            self, _c_.svn_ra_session_t * _c_session, pool)
