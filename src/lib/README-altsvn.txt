vclib.altsvn --- alternative module to access Subversion repository for ViewVC

[Overview]
This is one of replacement of vclib.svn module, to support Python 3.x.
It doesn't use swig Python binding of Subversion API, which is not support
Python 3.x yet, but uses bridge module to access C API, written in Cython.
(But it is not tested almost all on Python 3.x yet.)

[Build Requirement]
* Cython 0.28 or above (not tested in 0.27 and below, and it is obviously
  needed 0.24 or above for @property syntax)
* C compiler
* Subversion (1.3 and above) with development library (libsvn_*.a)
  (not tested 1.7 and below)
* Python 2.6/2.7 or 3.x (for 3.x, build test and few function test only
  with 3.6 and 3.7)


[tested environment]
* Python 2.1.15 / Cython 0.28 / Subversion 1.10.0 / FreeBSD 11
* Python 2.6.6  / Cython 0.29 / Subversion 1.9.7  / Scientific Linux 6
* Python 2.6.6  / Cython 0.29 / Subversion 1.8.14 / CentOS 6


[How to build]
(1) move to src/lib subdirectory
(2) edit setup.py to make Cython to be able to find Apache Portable Runtime and
   Subversion include file, and their libraries.
(3) create cython/capi/subversion_1/_svn_api_ver.pxi to set Cython macro
    SVN_API_VER and  SVN_USE_DOS_PATHS. The content of the file is like
-- BEGIN --
DEF SVN_API_VER = (1, 10)
DEF SVN_USE_DOS_PATHS = 0
-- END --
(4) create symlink lib/altsvn/_svn_api_ver.pxi point to
    cython/capi/subversion_1/_svn_api_ver.pxi
(5) run "python setup.py build"


[How to use]
(1) copy directory build/lib.(environment depended directory)/vclib/altsvn
    and its contents into lib/vclib subdirectry of viewvc install root
(2) replace all occurence of 'vclib.svn' into 'vclib.altsvn' in lib/viewvc.py
(3) enjoy :)


[To do]
* implement driver for bin/svnadmin.py
* maintain build process. at least configuration phase to configure
  build environment semi-automatically is needed.
* maintain install process
* create mechanism to switch module by configration file
