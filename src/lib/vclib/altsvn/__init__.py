# -*-python-*-
#
# Copyright (C) 1999-2018 The ViewCVS Group. All Rights Reserved.
#
# By using this file, you agree to the terms and conditions set forth in
# the LICENSE.html file which can be found at the top level of the ViewVC
# distribution or at http://viewvc.org/license-1.html.
#
# For more information, visit http://viewvc.org/
#
# -----------------------------------------------------------------------

"Version Control lib driver for Subversion repositories"

import os
import os.path
import re
import urllib
from ._svn import canonicalize_path as _canonicalize_path
from ._svn import canonicalize_rootpath as canonicalize_rootpath

_re_url = re.compile('^(http|https|file|svn|svn\+[^:]+)://')

def expand_root_parent(parent_path):
  roots = {}
  if re.search(_re_url, parent_path):
    pass
  else:
    # Any subdirectories of PARENT_PATH which themselves have a child
    # "format" are returned as roots.
    assert os.path.isabs(parent_path)
    subpaths = os.listdir(parent_path)
    for rootname in subpaths:
      rootpath = os.path.join(parent_path, rootname)
      if os.path.exists(os.path.join(rootpath, "format")):
        roots[rootname] = canonicalize_rootpath(rootpath)
  return roots


def find_root_in_parent(parent_path, rootname):
  """Search PARENT_PATH for a root named ROOTNAME, returning the
  canonicalized ROOTPATH of the root if found; return None if no such
  root is found."""
  
  if not re.search(_re_url, parent_path):
    assert os.path.isabs(parent_path)
    rootpath = os.path.join(parent_path, rootname)
    format_path = os.path.join(rootpath, "format")
    if os.path.exists(format_path):
      return canonicalize_rootpath(rootpath)
  return None


def SubversionRepository(name, rootpath, authorizer, utilities, config_dir):
  rootpath = canonicalize_rootpath(rootpath)
  if re.search(_re_url, rootpath):
    import svn_ra
    return svn_ra.RemoteSubversionRepository(name, rootpath, authorizer,
                                             utilities, config_dir)
  else:
    import svn_repos
    return svn_repos.LocalSubversionRepository(name, rootpath, authorizer,
                                               utilities, config_dir)
