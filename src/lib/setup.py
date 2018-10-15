#!/usr/bin/env python
# $yfId$

import sys
import os
import os.path
import platform
from distutils.core import setup
from Cython.Distutils.extension import Extension
from Cython.Distutils import build_ext
from distutils import log
from distutils.command.build import build as _build
from distutils.command.clean import clean as _clean
from distutils.cmd import Command

# Get access to our library modules.
sys.path.insert(0, os.path.abspath(
        os.path.join(os.path.dirname(sys.argv[0]), '../../lib')))

class build(_build):
    sub_commands = [('pre_build', None)] + _build.sub_commands

class pre_build(Command):
    description = "run pre-build jobs"
    user_options = []
    boolean_options = []
    help_options = []
    def initialize_options(self):
        return
    def finalize_options(self):
        return
    def run(self):
        # put target python version into pxi file
        pxi_file='vclib/altsvn/_py_ver.pxi'
        if os.path.lexists(pxi_file):
            os.remove(pxi_file)
        f = open(pxi_file, 'w')
        f.write('DEF PY_VERSION = ' + str((sys.version_info[0],
                                           sys.version_info[1],
                                           sys.version_info[2]))
                                    + '\n')
        f.close()
        return

intermediates = ['vclib/altsvn/_py_ver.pxi',
                 'vclib/altsvn/_svn.c',
                 'vclib/altsvn/_svn_repos.c',
                 'vclib/altsvn/_svn_ra.c']

class clean(_clean):
    def run(self):
        _clean.run(self)
        for intf in intermediates:
            if os.path.lexists(intf):
                if os.path.islink(intf) or (not os.path.isdir(intf)):
                     log.info("removing '%s'", intf)
                if self.dry_run:
                    continue 
                os.remove(intf)
            else:
                log.warn("'%s' does not exist -- can't clean it", intf)

cython_include_dir = os.path.abspath(os.path.join(
                            os.path.dirname(sys.argv[0]), 'cython/capi'))

ext_modules = [
    Extension('vclib.altsvn._svn',
              ['vclib/altsvn/_svn.pyx'],
              cython_include_dirs=[cython_include_dir],
              cython_gdb=True,
              # Whmm.. compiler specific option ...
              #extra_compile_args=["-Wno-deprecated-declarations"],
              include_dirs=["/usr/local/include/apr-1",
                            "/usr/local/include/subversion-1"],
              library_dirs=["/usr/local/lib"],
              libraries=["apr-1", "svn_subr-1"]),
    Extension('vclib.altsvn._svn_repos',
              ['vclib/altsvn/_svn_repos.pyx'],
              cython_include_dirs=[cython_include_dir],
              cython_gdb=True,
              # Whmm.. compiler specific option ...
              #extra_compile_args=["-Wno-deprecated-declarations"],
              include_dirs=["/usr/local/include/apr-1",
                            "/usr/local/include/subversion-1"],
              library_dirs=["/usr/local/lib"],
              libraries=["apr-1", "svn_subr-1", "svn_fs-1", "svn_repos-1",
                         "svn_client-1"]),
    Extension('vclib.altsvn._svn_ra',
              ['vclib/altsvn/_svn_ra.pyx'],
              cython_include_dirs=[cython_include_dir],
              cython_gdb=True,
              # Whmm.. compiler specific option ...
              #extra_compile_args=["-Wno-deprecated-declarations"],
              include_dirs=["/usr/local/include/apr-1",
                            "/usr/local/include/subversion-1"],
              library_dirs=["/usr/local/lib"],
              libraries=["apr-1", "svn_subr-1", "svn_ra-1", "svn_client-1"]),
]

setup(name='vclib.altsvn',
    version='0.01.0',
    description= 'alternative implementation of vclib.svn, '
                 'impremented with Cython',
    author='Yasuhito FUTATSUKI',
    author_email='futatuki@yf.bsdclub.org',
    license="BSD 2 clause, Apache License Version 2",
    packages = ['vclib.altsvn'],
    ext_modules = ext_modules,
    cmdclass = {'pre_build' : pre_build,
                'build'     : build,
                'build_ext' : build_ext,
                'clean'     : clean}
)
