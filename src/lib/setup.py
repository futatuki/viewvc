#!/usr/bin/env python
# $yfId$

import sys
import os
import os.path
import shutil
import platform
import re
import subprocess
from distutils.core import setup
from Cython.Distutils.extension import Extension
from Cython.Distutils import build_ext
from distutils import log
from distutils.command.build import build as _build
from distutils.command.install import install as _install
from distutils.command.clean import clean as _clean
from distutils.cmd import Command

build_base = os.path.abspath(os.path.dirname(sys.argv[0]))
config_py = os.path.join(build_base, 'config.py')

# Get access to our library modules.
sys.path.insert(0, os.path.abspath(
        os.path.join(build_base, '../../lib')))

# make sure import config module from build_base
sys.path.insert(0, build_base)

try:
    from config import apr_include_dir, svn_include_dir, apr_lib_dir,\
                       svn_lib_dir, include_dirs, library_dirs
    config_done = True
except:
    apr_include_dir = None
    svn_include_dir = None
    apr_lib_dir = None
    svn_lib_dir = None
    include_dirs = []
    library_dirs = []
    config_done = False


def create_config_files(params=None):
    # Fix me: library check may work only in Unix like platforms....
    def check_dir(dir, path_parts, exts):
        for path in map((lambda x:os.path.join(dir, *x)), path_parts):
            for ext in exts:
                if os.path.isfile(path + ext):
                    return os.path.dirname(path)
        return None

    def check_apr_include(dir):
        return check_dir(dir, [['apr'], ['apr-1','apr']], ['.h'])

    def check_svn_include(dir):
        return check_dir(dir,
                         [['svn_version'], ['subversion-1','svn_version']],
                         ['.h'])

    def check_apr_lib(dir):
        return check_dir(dir,
                         [['libapr-1'], ['apr-1','libapr-1']],
                         ['.a','.la'])

    def check_svn_lib(dir):
        return check_dir(dir,
                         [['libsvn_subr-1'], ['subversion-1','libsvn_subr-1']],
                         ['.a', '.la'])


    include_path_candidate = ['/usr/include', '/usr/local/include']
    if (    os.path.lexists('/usr/lib64')
        and re.match('.*64.*', platform.machine())):
        lib_path_candidate = ['/usr/lib64', '/usr/local/lib64',
                              '/usr/lib', '/usr/local/lib']
    elif (    os.path.lexists('/usr/lib32')
          and re.match('.*32.*', platform.machine())):
        lib_path_candidate = ['/usr/lib32', '/usr/local/lib32',
                              '/usr/lib', '/usr/local/lib']
    else:
        lib_path_candidate = ['/usr/lib', '/usr/local/lib']

    if params and params.apr_include:
        apr_include_path = check_apr_include(self.apr_include)
    else:
        for dir in include_path_candidate:
            apr_include_dir = check_apr_include(dir)
            if apr_include_dir:
                break
    if not apr_include_dir:
        log.warn(
"""cannot determine APR include path. please (re)run 'python setup.py config'
with --apr-include=<apr-include-path> option
""")
        sys.exit(1)
    if params and params.svn_include:
        svn_include_dir = check_svn_include(self.svn_include)
    else:
        for dir in include_path_candidate:
            svn_include_dir = check_svn_include(dir)
            if svn_include_dir:
                break
    if not svn_include_dir:
        log.warn(
"""cannot determine Subversion include path. please (re)run
'python setup.py config' with --svn-include=<svn-include-path> option
""")
        sys.exit(1)
    if apr_include_dir == svn_include_dir:
        include_dirs = [apr_include_dir]
    else:
        include_dirs = [apr_include_dir, svn_include_dir]

    if params and params.apr_lib:
        apr_lib_dir = check_apr_lib(self.apr_lib)
    else:
        for dir in lib_path_candidate:
            apr_lib_dir = check_apr_lib(dir)
            if apr_lib_dir:
                break
    if not apr_lib_dir:
        log.warn(
"""cannot determine APR library path. please (re)run 'python setup.py config'
with --apr-lib=<apr-library-path> option
""")
        sys.exit(1)
    if params and params.svn_lib:
        svn_lib_dir = check_svn_lib(self.svn_lib)
    else:
        for dir in lib_path_candidate:
            svn_lib_dir = check_svn_lib(dir)
            if svn_lib_dir:
                break
    if not svn_lib_dir:
        log.warn(
"""cannot determine Subversion library path. please (re)run
'python setup.py config' with --svn-lib=<subversion-library-path> option
""")
        sys.exit(1)
    if apr_lib_dir == svn_lib_dir:
        library_dirs = [apr_lib_dir]
    else:
        library_dirs = [apr_lib_dir, svn_lib_dir]

    fp = open(config_py, "wt")
    fp.write('apr_include_dir = "{0}"\n'.format(apr_include_dir))
    fp.write('svn_include_dir = "{0}"\n'.format(svn_include_dir))
    fp.write('apr_lib_dir     = "{0}"\n'.format(apr_lib_dir))
    fp.write('svn_lib_dir     = "{0}"\n'.format(svn_lib_dir))
    fp.write('include_dirs    = {0}\n'.format(repr(include_dirs)))
    fp.write('library_dirs    = {0}\n'.format(repr(library_dirs)))
    fp.close

    # build make_svn_api_version_pxi
    proc = subprocess.Popen(
            ['cc',  '-I' + apr_include_dir,
             '-I' + svn_include_dir, '-o', 'make_svn_api_version_pxi',
             'make_svn_api_version_pxi.c'],
            cwd=os.path.join(build_base, 'vclib/altsvn'),
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, close_fds=True)
    output = proc.stdout.read()
    proc.stdout.close()
    ret = proc.poll()
    if ret is None:
        proc.terminate()
        ret = proc.wait()
    if ret:
        log.warn("C compiler exit code with {0!s}.".format(ret))
        log.warn("its output:\n{0}".format(output))
        sys.exit(1)

    # generate _svn_api_ver.pxi
    pxi_file=os.path.join(build_base,
                          'cython/capi/subversion_1/_svn_api_ver.pxi')
    if os.path.lexists(pxi_file):
        os.remove(pxi_file)
    pxi_file=os.path.join(build_base, 'vclib/altsvn/_svn_api_ver.pxi')
    if os.path.lexists(pxi_file):
        os.remove(pxi_file)
    proc = subprocess.Popen(
            [os.path.join(build_base,
                          'vclib/altsvn/make_svn_api_version_pxi')],
            cwd=os.path.join(build_base, 'cython/capi/subversion_1'),
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, close_fds=True)
    output = proc.stdout.read()
    proc.stdout.close()
    ret = proc.poll()
    if ret is None:
        proc.terminate()
        ret = proc.wait()
    if ret:
        log.warn("C compiler exit code with {0!s}.".format(ret))
        log.warn("its output:\n{0}".format(output))
        sys.exit(1)
    try:
        os.symlink('../../cython/capi/subversion_1/_svn_api_ver.pxi',
                   os.path.join(build_base, 'vclib/altsvn/_svn_api_ver.pxi'))
    except:
        shutil.copy2(os.path.join(build_base, 'cython/capi/_svn_api_ver.pxi'),
                     os.path.join(build_base, 'vclib/altsvn/_svn_api_ver.pxi'))
    return

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
        if not config_done:
            self.warn(
"""fail to import module 'config': Please (re)run

    $ python setup.py config

with appropriate options.""")
            sys.exit(1)
        # put target python version into pxi file
        pxi_file=os.path.join(build_base, 'vclib/altsvn/_py_ver.pxi')
        if os.path.lexists(pxi_file):
            os.remove(pxi_file)
        f = open(pxi_file, 'w')
        f.write('DEF PY_VERSION = ' + str((sys.version_info[0],
                                           sys.version_info[1],
                                           sys.version_info[2]))
                                    + '\n')
        f.close()


cython_include_dir = os.path.join(build_base, 'cython', 'capi')

class config(Command):
    description = "configure build envirionment"
    user_options = [
            ('apr-include=', None,
                    "specify C include header path for apr-1"),
            ('apr-lib=', None,
                    "specify C library path for apr-1"),
            ('svn-include=', None,
                    "specify C include header path for Subversion"),
            ('svn-lib=', None,
                    "C library path for Subversion")]
    boolean_options = []
    help_options = []
    def initialize_options(self):
        self.apr_include=None
        self.apr_lib=None
        self.svn_include=None
        self.svn_lib=None
    def finalize_options(self):
        return
    def run(self):
        create_config_files(self)
        return

class install(_install):
    # skip all except install_lib
    sub_commands = [('install_lib', lambda self:True)]

class clean(_clean):
    intermediates = ['vclib/altsvn/_py_ver.pxi',
                     'vclib/altsvn/_svn.c',
                     'vclib/altsvn/_svn_repos.c',
                     'vclib/altsvn/_svn_ra.c',
                     'vclib/altsvn/make_svn_api_version_pxi']
    all_targets = ['config.py', 'config.pyc', 'config.pyo', '__pycache__',
                   'cython/capi/subversion_1/_svn_api_ver.pxi',
                   'vclib/altsvn/_svn_api_ver.pxi',
                   '../../lib/cython_debug',
                   '../../lib/vclib/altsvn']
    def run(self):
        _clean.run(self)
        def do_remove(path):
            if os.path.lexists(path):
                if os.path.islink(path) or os.path.isfile(path):
                    log.info("removing '%s'", path)
                    if not self.dry_run:
                        os.remove(path)
                else:
                    assert os.path.isdir(path)
                    log.info("removing directory '%s'", path)
                    if not self.dry_run:
                        shutil.rmtree(path)
            else:
                log.warn("'%s' does not exist -- can't clean it", path)

        for intf in self.intermediates:
            do_remove(intf)
        if self.all:
            for path in self.all_targets:
                do_remove(path)

ext_modules = [
    Extension('vclib.altsvn._svn',
              ['vclib/altsvn/_svn.pyx'],
              cython_include_dirs=[cython_include_dir],
              cython_gdb=True,
              # Whmm.. compiler specific option ...
              #extra_compile_args=["-Wno-deprecated-declarations"],
              include_dirs=include_dirs,
              library_dirs=library_dirs,
              libraries=["apr-1", "svn_subr-1", "svn_client-1"]),
    Extension('vclib.altsvn._svn_repos',
              ['vclib/altsvn/_svn_repos.pyx'],
              cython_include_dirs=[cython_include_dir],
              cython_gdb=True,
              # Whmm.. compiler specific option ...
              #extra_compile_args=["-Wno-deprecated-declarations"],
              include_dirs=include_dirs,
              library_dirs=library_dirs,
              libraries=["apr-1", "svn_subr-1", "svn_fs-1", "svn_repos-1"]),
    Extension('vclib.altsvn._svn_ra',
              ['vclib/altsvn/_svn_ra.pyx'],
              cython_include_dirs=[cython_include_dir],
              cython_gdb=True,
              # Whmm.. compiler specific option ...
              #extra_compile_args=["-Wno-deprecated-declarations"],
              include_dirs=include_dirs,
              library_dirs=library_dirs,
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
                'install'   : install,
                'clean'     : clean,
                'config'    : config}
)
