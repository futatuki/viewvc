include "_svn_api_ver.pxi"
from apr_1.apr cimport *
from apr_1.apr_errno cimport *
from apr_1.apr_pools cimport *
from apr_1.apr_hash cimport *
from apr_1.apr_tables cimport *
from subversion_1.svn_types cimport *
from subversion_1.svn_error cimport *
from subversion_1.svn_config cimport *
from subversion_1.svn_auth cimport *
from subversion_1.svn_opt cimport *
from subversion_1.svn_client cimport *
from subversion_1.svn_ra cimport *
IF SVN_API_VER >= (1, 6):
    from subversion_1.svn_cmdline cimport *
