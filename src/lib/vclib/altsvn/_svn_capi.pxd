include "_svn_api_ver.pxi"
from apr_1.apr cimport *
from apr_1.apr_errno cimport *
from apr_1.apr_general cimport *
from apr_1.apr_pools cimport *
from apr_1.apr_time cimport *
from apr_1.apr_hash cimport *
from apr_1.apr_tables cimport *
IF SVN_API_VER < (1, 6):
    from apr_1.apr_file_io cimport *
from subversion_1.svn_types cimport *
from subversion_1.svn_error cimport *
from subversion_1.svn_error_codes cimport *
from subversion_1.svn_props cimport *
from subversion_1.svn_version cimport *
from subversion_1.svn_opt cimport *
from subversion_1.svn_path cimport *
from subversion_1.svn_time cimport *
from subversion_1.svn_string cimport *
from subversion_1.svn_io cimport *
IF SVN_API_VER >= (1, 6):
    from subversion_1.svn_dirent_uri cimport *
    from subversion_1.svn_cmdline cimport *
from subversion_1.svn_diff cimport *
from subversion_1.svn_config cimport *
from subversion_1.svn_client cimport *
