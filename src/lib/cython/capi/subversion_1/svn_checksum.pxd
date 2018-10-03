include "_svn_api_ver.pxi"


cdef extern from "svn_checksum.h" nogil:
    IF SVN_API_VER >= (1, 9):
        ctypedef enum svn_checksum_kind_t:
            svn_checksum_md5
            svn_checksum_sha1
            svn_checksum_fnv1a_32
            svn_checksum_fnv1a_32x4
    ELIF SVN_API_VER >= (1, 6):
        ctypedef enum svn_checksum_kind_t:
            svn_checksum_md5
            svn_checksum_sha1
    IF SVN_API_VER >= (1, 6):
        ctypedef struct svn_checksum_t:
            const unsigned char *digest
            svn_checksum_kind_t kind
    ELSE:
        pass
