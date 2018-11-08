vclib.altsvn --- alternative module to access Subversion repository for ViewVC

[Overview]
This is one of replacement of vclib.svn module, to support Python 3.x.
It doesn't use swig Python binding of Subversion API, which is not support
Python 3.x yet, but uses bridge module to access C API, written in Cython.


[Build Requirement]
* Python 2.6/2.7 or 3.x (for 3.x, tested with 3.6 and 3.7 only)
* Cython 0.28 or above (not tested in 0.27 and below, and it is obviously
  needed 0.24 or above for @property syntax)
* A C compiler
* Subversion (1.3 and above) with development library
* Apache Portable Runtime development library 1.x (may be installed
  by dependency of Subversion's development library)


[tested environment]
* Python 3.7.1  / Cython 0.29 / Subversion 1.11.0 / FreeBSD 11
* Python 2.7.15 / Cython 0.28 / Subversion 1.10.0 / FreeBSD 11
* Python 2.6.6  / Cython 0.29 / Subversion 1.9.7  / Scientific Linux 6
* Python 2.6.6  / Cython 0.29 / Subversion 1.8.14 / CentOS 6 (with
  ViewVC 1.1.26)


[How to build]
(1) Move to src/lib subdirectory (it will be this directory)
(2) Run "python setup.py config".
  It creates cfg.py, cython/capi/subversion_1/_svn_api_ver.pxi and
vclib/altsvn/_svn_api_ver.pxi to store build parameter.
Currently, semi-automatic config supports Unix like environment only,
and it may not work correctly.
If it is not work well, you must edit cfg.py and _svn_api_ver.pxi manually.

In cfg.py, some variables to hold include file directories and library
directory to build module are needed:

      apr_include_dir : path to include files for APR (string)
      svn_include_dir : path to include files for Subversion (string)
      apr_lib_dir     : path to library files for APR (string)
      svn_lib_dir     : path to library files for Subversion (string)
      include_dirs    : list of include directory paths of APR and
                        of Subversion (list of string)
      library_dirs    : list of library directory paths of APR and
                        of Subversion (list of string)

for example:

-- BEGIN --
apr_include_dir = "/usr/local/include/apr-1"
svn_include_dir = "/usr/local/include/subversion-1"
apr_lib_dir     = "/usr/local/lib"
svn_lib_dir     = "/usr/local/lib"
include_dirs    = ['/usr/local/include/apr-1',
                   '/usr/local/include/subversion-1']
library_dirs    = ['/usr/local/lib']
-- END --

  The file cython/capi/subversion_1/_svn_api_ver.pxi defines Cython macro
SVN_API_VER and SVN_USE_DOS_PATHS. The content of the file is like:

-- BEGIN --
DEF SVN_API_VER = (1, 10)
DEF SVN_USE_DOS_PATHS = 0
-- END --

  It is also needed to be exists lib/altsvn/_svn_api_ver.pxi, as just same
content as cython/capi/subversion_1/_svn_api_ver.pxi.  so symlink or copy
from cython/capi/subversion_1/_svn_api_ver.pxi.

(3) run "python setup.py build"


[How to use]
(1) run "python setup.py install" in this directory, before run
    install-viewvc script.
(2) edit your viewvc.conf to use altsvn as svn access module.
    In "[vclib]" section, set 'use_altsvn = 1' (default is "use_altsvn = 0")
(3) run ViewVC


[To do]
* more testing.
  - especially test for remote repos on Python 3
* improve build and install process
  - platforms other than Unix like environment
