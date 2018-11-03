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

import os.path
import re
import vclib
from ._svn import canonicalize_path as _canonicalize_path
from ._svn import canonicalize_rootpath as canonicalize_rootpath

def _path_parts(path):
  return [pp for pp in path.split(b'/') if pp]


def _cleanup_path(path):
  """Return a cleaned-up Subversion filesystem path"""
  return b'/'.join(_path_parts(path))


def _compare_paths(path1, path2):
  path1_len = len (path1);
  path2_len = len (path2);
  min_len = min(path1_len, path2_len)
  i = 0

  # Are the paths exactly the same?
  if path1 == path2:
    return 0

  # Skip past common prefix
  while (i < min_len) and (path1[i] == path2[i]):
    i = i + 1

  # Children of paths are greater than their parents, but less than
  # greater siblings of their parents
  char1 = b'\0'
  char2 = b'\0'
  if (i < path1_len):
    char1 = path1[i:i+1]
  if (i < path2_len):
    char2 = path2[i:i+1]

  if (char1 == b'/') and (i == path2_len):
    return 1
  if (char2 == b'/') and (i == path1_len):
    return -1
  if (i < path1_len) and (char1 == b'/'):
    return -1
  if (i < path2_len) and (char2 == b'/'):
    return 1

  # Common prefix was skipped above, next character is compared to
  # determine order
  return cmp(char1, char2)


# Given a dictionary REVPROPS of revision properties, pull special
# ones out of them and return a 4-tuple containing the log message,
# the author, the date (converted from the date string property), and
# a dictionary of any/all other revprops.
def _split_revprops(revprops, scratch_pool=None):
  if not revprops:
    return None, None, None, {}
  special_props = []
  for prop in _svn.SVN_PROP_REVISION_LOG, \
              _svn.SVN_PROP_REVISION_AUTHOR, \
              _svn.SVN_PROP_REVISION_DATE:
    if prop in revprops:
      special_props.append(revprops[prop])
      del(revprops[prop])
    else:
      special_props.append(None)
  msg, author, datestr = tuple(special_props)
  date = _svn.datestr_to_date(datestr, scratch_pool)
  return msg, author, date, revprops


_re_url = re.compile(b'^(http|https|file|svn|svn\+[^:]+)://')

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


class Revision(vclib.Revision):
  "Hold state for each revision's log entry."
  def __init__(self, rev, date, author, msg, size, lockinfo,
               filename, copy_path, copy_rev):
    vclib.Revision.__init__(self, rev, str(rev), date, author, None,
                            msg, size, lockinfo)
    self.filename = filename
    self.copy_path = copy_path
    self.copy_rev = copy_rev


class SVNChangedPath(vclib.ChangedPath):
  """Wrapper around vclib.ChangedPath which handles path splitting."""

  def __init__(self, path, rev, pathtype, base_path, base_rev,
               action, copied, text_changed, props_changed):
    path_parts = _path_parts(path or b'')
    base_path_parts = _path_parts(base_path or b'')
    vclib.ChangedPath.__init__(self, path_parts, rev, pathtype,
                               base_path_parts, base_rev, action,
                               copied, text_changed, props_changed)


def SubversionRepository(name, rootpath, authorizer, utilities, config_dir):
  rootpath = canonicalize_rootpath(rootpath)
  if re.search(_re_url, rootpath):
    from . import svn_ra
    return svn_ra.RemoteSubversionRepository(name, rootpath, authorizer,
                                             utilities, config_dir)
  else:
    from . import svn_repos
    return svn_repos.LocalSubversionRepository(name, rootpath, authorizer,
                                               utilities, config_dir)
