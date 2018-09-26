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

"Version Control lib driver for locally accessible Subversion repositories"

import vclib
import sys
import os
import os.path
import io
import time
import tempfile
import popen
import re
import urllib
from . import _svn
from . import _svn_repos

### Require Subversion 1.3.1 or better.
if (_svn.SVN_VER_MAJOR, _svn.SVN_VER_MINOR, _svn.SVN_VER_PATCH) < (1, 3, 1):
  raise Exception, "Version requirement not met (needs 1.3.1 or better)"

# for compatibility between Python 2 and Python 3
_default_encoding = sys.getdefaultencoding()

def setdefaultencoding(enc):
    codecs.lookup(enc)
    _default_encoding = enc
    return

def _norm(s, encoding=_default_encoding, errors='strict'):
    return (s.decode(encoding, errors)
                if not isinstance(s, str) and isinstance(s, bytes) else s)

def _allow_all(root, path, pool):
  """Generic authz_read_func that permits access to all paths"""
  return 1


def _path_parts(path):
  return filter(None, path.split(b'/'))


def _cleanup_path(path):
  """Return a cleaned-up Subversion filesystem path"""
  return b'/'.join(_path_parts(path))


def _fs_path_join(base, relative):
  return _cleanup_path(base + b'/' + relative)


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
def _split_revprops(revprops):
  if not revprops:
    return None, None, None, {}
  special_props = []
  for prop in _svn.SVN_PROP_REVISION_LOG, \
              _svn.SVN_PROP_REVISION_AUTHOR, \
              _svn.SVN_PROP_REVISION_DATE:
    if revprops.has_key(prop):
      special_props.append(revprops[prop])
      del(revprops[prop])
    else:
      special_props.append(None)
  msg, author, datestr = tuple(special_props)
  date = _svn.datestr_to_date(datestr)
  return msg, author, date, revprops


class Revision(vclib.Revision):
  "Hold state for each revision's log entry."
  def __init__(self, rev, date, author, msg, size, lockinfo,
               filename, copy_path, copy_rev):
    vclib.Revision.__init__(self, rev, str(rev), date, author, None,
                            msg, size, lockinfo)
    self.filename = filename
    self.copy_path = copy_path
    self.copy_rev = copy_rev


def _get_last_history_rev(fsroot, path):
  history = _svn_repos.svn_fs_node_history(fsroot, path)
  history = _svn_repos.svn_fs_history_prev(history, 0)
  history_path, history_rev = _svn_repos.svn_fs_history_location(history)
  return history_rev

def temp_checkout(svnrepos, path, rev):
  """Check out file revision to temporary file"""
  temp = tempfile.mktemp()
  fp = open(temp, 'wb')
  try:
    root = svnrepos._getroot(rev)
    stream = _svn_repos.svn_fs_file_contents(root, path)
    try:
      while 1:
        chunk = _svn.svn_stream_read(stream, _svn.SVN_STREAM_CHUNK_SIZE)
        if not chunk:
          break
        fp.write(chunk)
    finally:
      _svn.svn_stream_close(stream)
  finally:
    fp.close()
  return temp

class FileContentsPipe:
  def __init__(self, root, path):
    self._stream = _svn_repos.svn_fs_file_contents(root, path)
    self._eof = 0

  def read(self, len=None):
    chunk = None
    if not self._eof:
      if len is None:
        buffer = io.BytesIO()
        try:
          while 1:
            hunk = _svn.svn_stream_read(self._stream, 8192)
            if not hunk:
              break
            buffer.write(hunk)
          chunk = buffer.getvalue()
        finally:
          buffer.close()

      else:
        chunk = _svn.svn_stream_read(self._stream, len)
    if not chunk:
      self._eof = 1
    return chunk

  def readline(self):
    chunk = None
    if not self._eof:
      chunk, self._eof = _svn.svn_stream_readline(self._stream, b'\n')
      if not self._eof:
        chunk = chunk + b'\n'
    if not chunk:
      self._eof = 1
    return chunk

  def readlines(self):
    lines = []
    while True:
      line = self.readline()
      if not line:
        break
      lines.append(line)
    return lines

  def close(self):
    return _svn.svn_stream_close(self._stream)

  def eof(self):
    return self._eof


class SVNChangedPath(vclib.ChangedPath):
  """Wrapper around vclib.ChangedPath which handles path splitting."""

  def __init__(self, path, rev, pathtype, base_path, base_rev,
               action, copied, text_changed, props_changed):
    path_parts = _path_parts(path or b'')
    base_path_parts = _path_parts(base_path or b'')
    vclib.ChangedPath.__init__(self, path_parts, rev, pathtype,
                               base_path_parts, base_rev, action,
                               copied, text_changed, props_changed)


class LocalSubversionRepository(vclib.Repository):
  def __init__(self, name, rootpath, authorizer, utilities, config_dir):
    if not (os.path.isdir(rootpath) \
            and os.path.isfile(os.path.join(rootpath, b'format'))):
      raise vclib.ReposNotFound(name)

    # Initialize some stuff.
    self.rootpath = rootpath
    self.name = name
    self.auth = authorizer
    self.diff_cmd = utilities.diff or 'diff'
    self.config_dir = config_dir or None

    # See if this repository is even viewable, authz-wise.
    if not vclib.check_root_access(self):
      raise vclib.ReposNotFound(name)

  def open(self):
    # Open the repository and init some other variables.
    self.repos = _svn_repos.svn_repos_open(self.rootpath)
    self.fs_ptr = _svn_repos.svn_repos_fs(self.repos)
    self.youngest = _svn_repos.svn_fs_youngest_rev(self.fs_ptr)
    self._fsroots = {}
    self._revinfo_cache = {}

    # See if a universal read access determination can be made.
    if self.auth and self.auth.check_universal_access(self.name) == 1:
      self.auth = None

  def rootname(self):
    return self.name

  def rootpath(self):
    return self.rootpath

  def roottype(self):
    return vclib.SVN

  def authorizer(self):
    return self.auth

  def itemtype(self, path_parts, rev):
    rev = self._getrev(rev)
    basepath = self._getpath(path_parts)
    pathtype = self._gettype(basepath, rev)
    if pathtype is None:
      raise vclib.ItemNotFound(path_parts)
    if not vclib.check_path_access(self, path_parts, pathtype, rev):
      raise vclib.ItemNotFound(path_parts)
    return pathtype

  def openfile(self, path_parts, rev, options):
    path = self._getpath(path_parts)
    if self.itemtype(path_parts, rev) != vclib.FILE:  # does auth-check
      raise vclib.Error("Path '%s' is not a file." % _norm(path))
    rev = self._getrev(rev)
    fsroot = self._getroot(rev)
    revision = str(_get_last_history_rev(fsroot, path))
    fp = FileContentsPipe(fsroot, path)
    return fp, revision

  def listdir(self, path_parts, rev, options):
    path = self._getpath(path_parts)
    if self.itemtype(path_parts, rev) != vclib.DIR:  # does auth-check
      raise vclib.Error("Path '%s' is not a directory." % _norm(path))
    rev = self._getrev(rev)
    fsroot = self._getroot(rev)
    dirents = _svn_repos.svn_fs_dir_entries(fsroot, path)
    entries = [ ]
    for entry in dirents.values():
      if entry.kind == _svn.svn_node_dir:
        kind = vclib.DIR
      elif entry.kind == _svn.svn_node_file:
        kind = vclib.FILE
      if vclib.check_path_access(self, path_parts + [entry.name], kind, rev):
        entries.append(vclib.DirEntry(entry.name, kind))
    return entries

  def dirlogs(self, path_parts, rev, entries, options):
    path = self._getpath(path_parts)
    if self.itemtype(path_parts, rev) != vclib.DIR:  # does auth-check
      raise vclib.Error("Path '%s' is not a directory." % _norm(path))
    fsroot = self._getroot(self._getrev(rev))
    rev = self._getrev(rev)
    for entry in entries:
      entry_path_parts = path_parts + [entry.name]
      if not vclib.check_path_access(self, entry_path_parts, entry.kind, rev):
        continue
      path = self._getpath(entry_path_parts)
      entry_rev = _get_last_history_rev(fsroot, path)
      date, author, msg, revprops, changes = self._revinfo(entry_rev)
      entry.rev = str(entry_rev)
      entry.date = date
      entry.author = author
      entry.log = msg
      if entry.kind == vclib.FILE:
        entry.size = _svn_repos.svn_fs_file_length(fsroot, path)
      lock = _svn_repos.svn_fs_get_lock(self.fs_ptr, path)
      entry.lockinfo = lock and lock.owner or None

  def itemlog(self, path_parts, rev, sortby, first, limit, options):
    """see vclib.Repository.itemlog docstring

    Option values recognized by this implementation

      svn_show_all_dir_logs
        boolean, default false. if set for a directory path, will include
        revisions where files underneath the directory have changed

      svn_cross_copies
        boolean, default false. if set for a path created by a copy, will
        include revisions from before the copy

      svn_latest_log
        boolean, default false. if set will return only newest single log
        entry
    """
    assert sortby == vclib.SORTBY_DEFAULT or sortby == vclib.SORTBY_REV

    path = self._getpath(path_parts)
    path_type = self.itemtype(path_parts, rev)  # does auth-check
    rev = self._getrev(rev)
    revs = []
    lockinfo = None

    # See if this path is locked.
    try:
      lock = _svn_repos.svn_fs_get_lock(self.fs_ptr, path)
      if lock:
        lockinfo = lock.owner
    except NameError:
      pass

    # If our caller only wants the latest log, we'll invoke
    # _log_helper for just the one revision.  Otherwise, we go off
    # into history-fetching mode.  ### TODO: we could stand to have a
    # 'limit' parameter here as numeric cut-off for the depth of our
    # history search.
    if options.get('svn_latest_log', 0):
      revision = self._log_helper(path, rev, lockinfo)
      if revision:
        revision.prev = None
        revs.append(revision)
    else:
      history = self._get_history(path, rev, path_type, first + limit, options)
      if len(history) < first:
        history = []
      if limit:
        history = history[first:first+limit]

      for hist_rev, hist_path in history:
        revision = self._log_helper(hist_path, hist_rev, lockinfo)
        if revision:
          # If we have unreadable copyfrom data, obscure it.
          if revision.copy_path is not None:
            cp_parts = _path_parts(revision.copy_path)
            if not vclib.check_path_access(self, cp_parts, path_type,
                                           revision.copy_rev):
              revision.copy_path = revision.copy_rev = None
          revision.prev = None
          if len(revs):
            revs[-1].prev = revision
          revs.append(revision)
    return revs

  def itemprops(self, path_parts, rev):
    path = self._getpath(path_parts)
    path_type = self.itemtype(path_parts, rev)  # does auth-check
    rev = self._getrev(rev)
    fsroot = self._getroot(rev)
    return _svn_repos.svn_fs_node_proplist(fsroot, path)

  def annotate(self, path_parts, rev, include_text=False):
    def _blame_cb(btn, line_no, rev, author, date, text):
      prev_rev = None
      if rev > btn.first_rev:
        prev_rev = rev - 1
      if not btn.include_text:
        text = None
      btn.btn.append(vclib.Annotation(text, line_no + 1, rev,
                                              prev_rev, author, date))
    # annotate() body
    path = self._getpath(path_parts)
    path_type = self.itemtype(path_parts, rev)  # does auth-check
    if path_type != vclib.FILE:
      raise vclib.Error("Path '%s' is not a file." % _norm(path))
    rev = self._getrev(rev)
    fsroot = self._getroot(rev)
    history = self._get_history(path, rev, path_type, 0,
                                {'svn_cross_copies': 1})
    youngest_rev, youngest_path = history[0]
    oldest_rev, oldest_path = history[-1]
    source = _svn_repos._get_annotated_source(
                    _svn.rootpath2url(self.rootpath, path), youngest_rev,
                    oldest_rev, _blame_cb, self.config_dir, include_text)
    return source, youngest_rev

  def revinfo(self, rev):
    return self._revinfo(rev, 1)

  def rawdiff(self, path_parts1, rev1, path_parts2, rev2, type, options={}):
    p1 = self._getpath(path_parts1)
    p2 = self._getpath(path_parts2)
    r1 = self._getrev(rev1)
    r2 = self._getrev(rev2)
    if not vclib.check_path_access(self, path_parts1, vclib.FILE, rev1):
      raise vclib.ItemNotFound(path_parts1)
    if not vclib.check_path_access(self, path_parts2, vclib.FILE, rev2):
      raise vclib.ItemNotFound(path_parts2)

    args = vclib._diff_args(type, options)

    def _date_from_rev(rev):
      date, author, msg, revprops, changes = self._revinfo(rev)
      return date

    try:
      temp1 = temp_checkout(self, p1, r1)
      temp2 = temp_checkout(self, p2, r2)
      info1 = p1, _date_from_rev(r1), r1
      info2 = p2, _date_from_rev(r2), r2
      return vclib._diff_fp(temp1, temp2, info1, info2, self.diff_cmd, args)
    except _svn.SVNerr, e:
      if e.get_code() == _svn.SVN_ERR_FS_NOT_FOUND:
        raise vclib.InvalidRevision
      raise

  def isexecutable(self, path_parts, rev):
    props = self.itemprops(path_parts, rev) # does authz-check
    return props.has_key(_svn.SVN_PROP_EXECUTABLE)

  def filesize(self, path_parts, rev):
    path = self._getpath(path_parts)
    if self.itemtype(path_parts, rev) != vclib.FILE:  # does auth-check
      raise vclib.Error("Path '%s' is not a file." % _norm(path))
    fsroot = self._getroot(self._getrev(rev))
    return _svn_repos.svn_fs_file_length(fsroot, path)

  ##--- helpers ---##

  def _revinfo(self, rev, include_changed_paths=0):
    """Internal-use, cache-friendly revision information harvester."""

    def _get_changed_paths(fsroot):
      """Return a 3-tuple: found_readable, found_unreadable, changed_paths."""
      changedpaths = {}
      changes = _svn_repos._get_changed_paths_helper(self.fs_ptr, fsroot)

      # Copy the Subversion changes into a new hash, checking
      # authorization and converting them into ChangedPath objects.
      found_readable = found_unreadable = 0
      for path in changes.keys():
        change = changes[path]
        if change.path:
          change.path = _cleanup_path(change.path)
        if change.base_path:
          change.base_path = _cleanup_path(change.base_path)
        is_copy = 0
        if change.action == _svn_repos.svn_fs_path_change_add:
          action = vclib.ADDED
        elif change.action == _svn_repos.svn_fs_path_change_delete:
          action = vclib.DELETED
        elif change.action == _svn_repos.svn_fs_path_change_replace:
          action = vclib.REPLACED
        else:
            action = vclib.MODIFIED
        if (action == vclib.ADDED or action == vclib.REPLACED) \
           and change.base_path \
           and change.base_rev:
          is_copy = 1
        if change.item_kind == _svn.svn_node_dir:
          pathtype = vclib.DIR
        elif change.item_kind == _svn.svn_node_file:
          pathtype = vclib.FILE
        else:
          pathtype = None

        parts = _path_parts(path)
        if vclib.check_path_access(self, parts, pathtype, rev):
          if is_copy and change.base_path and (change.base_path != path):
            parts = _path_parts(change.base_path)
            if not vclib.check_path_access(self, parts, pathtype,
                                           change.base_rev):
              is_copy = 0
              change.base_path = None
              change.base_rev = None
              found_unreadable = 1
          changedpaths[path] = SVNChangedPath(path, rev, pathtype,
                                              change.base_path,
                                              change.base_rev, action,
                                              is_copy, change.text_changed,
                                              change.prop_changes)
          found_readable = 1
        else:
          found_unreadable = 1
      return found_readable, found_unreadable, changedpaths.values()

    def _get_change_copyinfo(fsroot, path, change):
      # If we know the copyfrom info, return it...
      if hasattr(change, 'copyfrom_known') and change.copyfrom_known:
        copyfrom_path = change.copyfrom_path
        copyfrom_rev = change.copyfrom_rev
      # ...otherwise, if this change could be a copy (that is, it
      # contains an add action), query the copyfrom info ...
      elif (change.change_kind == _svn_repos.svn_fs_path_change_add or
            change.change_kind == _svn_repos.svn_fs_path_change_replace):
        copyfrom_rev, copyfrom_path = _svn_repos.svn_fs_copied_from(fsroot, path)
      # ...else, there's no copyfrom info.
      else:
        copyfrom_rev = _svn.SVN_INVALID_REVNUM
        copyfrom_path = None
      return copyfrom_path, copyfrom_rev

    def _simple_auth_check(fsroot):
      """Return a 2-tuple: found_readable, found_unreadable."""
      found_unreadable = found_readable = 0
      changes = _svn_repos.svn_fs_paths_changed(fsroot)
      paths = changes.keys()
      for path in paths:
        change = changes[path]
        pathtype = None
        if hasattr(change, 'node_kind'):
          if change.node_kind == _svn.svn_node_file:
            pathtype = vclib.FILE
          elif change.node_kind == _svn.svn_node_dir:
            pathtype = vclib.DIR
        parts = _path_parts(path)
        if pathtype is None:
          # Figure out the pathtype so we can query the authz subsystem.
          if change.change_kind == _svn_repos.svn_fs_path_change_delete:
            # Deletions are annoying, because they might be underneath
            # copies (make their previous location non-trivial).
            prev_parts = parts
            prev_rev = rev - 1
            parent_parts = parts[:-1]
            while parent_parts:
              parent_path = b'/' + self._getpath(parent_parts)
              parent_change = changes.get(parent_path)
              if not (parent_change and \
                      (parent_change.change_kind in
                       (_svn_repos.svn_fs_path_change_add,
                        _svn_repos.svn_fs_path_change_replace))):
                del(parent_parts[-1])
                continue
              copyfrom_path, copyfrom_rev = \
                _get_change_copyinfo(fsroot, parent_path, parent_change)
              if copyfrom_path:
                prev_rev = copyfrom_rev
                prev_parts = _path_parts(copyfrom_path) + \
                             parts[len(parent_parts):]
                break
              del(parent_parts[-1])
            pathtype = self._gettype(self._getpath(prev_parts), prev_rev)
          else:
            pathtype = self._gettype(self._getpath(parts), rev)
        if vclib.check_path_access(self, parts, pathtype, rev):
          found_readable = 1
          copyfrom_path, copyfrom_rev = \
            _get_change_copyinfo(fsroot, path, change)
          if copyfrom_path and copyfrom_path != path:
            parts = _path_parts(copyfrom_path)
            if not vclib.check_path_access(self, parts, pathtype,
                                           copyfrom_rev):
              found_unreadable = 1
        else:
          found_unreadable = 1
        if found_readable and found_unreadable:
          break
      return found_readable, found_unreadable

    def _revinfo_helper(rev, include_changed_paths):
      # Get the revision property info.  (Would use
      # editor.get_root_props(), but something is broken there...)
      revprops = _svn_repos.svn_fs_revision_proplist(self.fs_ptr, rev)
      msg, author, date, revprops = _split_revprops(revprops)

      # Optimization: If our caller doesn't care about the changed
      # paths, and we don't need them to do authz determinations, let's
      # get outta here.
      if self.auth is None and not include_changed_paths:
        return date, author, msg, revprops, None

      # If we get here, then we either need the changed paths because we
      # were asked for them, or we need them to do authorization checks.
      #
      # If we only need them for authorization checks, though, we
      # won't bother generating fully populated ChangedPath items (the
      # cost is too great).
      fsroot = self._getroot(rev)
      if include_changed_paths:
        found_readable, found_unreadable, changedpaths = \
          _get_changed_paths(fsroot)
      else:
        changedpaths = None
        found_readable, found_unreadable = _simple_auth_check(fsroot)

      # Filter our metadata where necessary, and return the requested data.
      if found_unreadable:
        msg = None
        if not found_readable:
          author = None
          date = None
      return date, author, msg, revprops, changedpaths

    # Consult the revinfo cache first.  If we don't have cached info,
    # or our caller wants changed paths and we don't have those for
    # this revision, go do the real work.
    rev = self._getrev(rev)
    cached_info = self._revinfo_cache.get(rev)
    if not cached_info \
       or (include_changed_paths and cached_info[4] is None):
      cached_info = _revinfo_helper(rev, include_changed_paths)
      self._revinfo_cache[rev] = cached_info
    return tuple(cached_info)

  def _log_helper(self, path, rev, lockinfo):
    rev_root = _svn_repos.svn_fs_revision_root(self.fs_ptr, rev)
    copyfrom_rev, copyfrom_path = _svn_repos.svn_fs_copied_from(rev_root, path)
    date, author, msg, revprops, changes = self._revinfo(rev)
    if _svn_repos.svn_fs_is_file(rev_root, path):
      size = _svn_repos.svn_fs_file_length(rev_root, path)
    else:
      size = None
    return Revision(rev, date, author, msg, size, lockinfo, path,
                    copyfrom_path and _cleanup_path(copyfrom_path),
                    copyfrom_rev)

  def _get_history(self, path, rev, path_type, limit=0, options={}):
    if self.youngest == 0:
      return []

    rev_paths = []
    fsroot = self._getroot(rev)
    show_all_logs = options.get('svn_show_all_dir_logs', 0)
    if not show_all_logs:
      # See if the path is a file or directory.
      kind = _svn_repos.svn_fs_check_path(fsroot, path)
      if kind is _svn.svn_node_file:
        show_all_logs = 1

    # Instantiate a NodeHistory collector object, and use it to collect
    # history items for PATH@REV.
    try:
      history = _svn_repos._get_history_helper(
                      self.fs_ptr, path, rev,
                      options.get('svn_cross_copies', 0),
                      show_all_logs, limit)
    except _svn.SVNerr, e:
      if e.get_code() != _svn.SVN_ERR_CEASE_INVOCATION:
        raise

    # Now, iterate over those history items, checking for changes of
    # location, pruning as necessitated by authz rules.
    for hist_rev, hist_path in history:
      path_parts = _path_parts(hist_path)
      if not vclib.check_path_access(self, path_parts, path_type, hist_rev):
        break
      rev_paths.append([hist_rev, hist_path])
    return rev_paths

  def _getpath(self, path_parts):
    return b'/'.join(path_parts)

  def _getrev(self, rev):
    if rev is None or rev == 'HEAD':
      return self.youngest
    try:
      if type(rev) == type(''):
        while rev[0:1] == 'r':
          rev = rev[1:]
      rev = int(rev)
    except:
      raise vclib.InvalidRevision(rev)
    if (rev < 0) or (rev > self.youngest):
      raise vclib.InvalidRevision(rev)
    return rev

  def _getroot(self, rev):
    return self.fs_ptr._getroot(rev)

  def _gettype(self, path, rev):
    # Similar to itemtype(), but without the authz check.  Returns
    # None for missing paths.
    try:
      kind = _svn_repos.svn_fs_check_path(self._getroot(rev), path)
    except:
      return None
    if kind == _svn.svn_node_dir:
      return vclib.DIR
    if kind == _svn.svn_node_file:
      return vclib.FILE
    return None

  ##--- custom ---##

  def get_youngest_revision(self):
    return self.youngest

  def get_location(self, path, rev, old_rev):
    try:
      results = repos.svn_repos_trace_node_locations(self.fs_ptr, path,
                                                     rev, [old_rev], _allow_all)
    except _svn.SVNerr, e:
      if e.get_code() == _svn.SVN_ERR_FS_NOT_FOUND:
        raise vclib.ItemNotFound(path)
      raise
    try:
      old_path = results[old_rev]
    except KeyError:
      raise vclib.ItemNotFound(path)

    return _cleanup_path(old_path)

  def created_rev(self, full_name, rev):
    return _svn_repos.svn_fs_node_created_rev(self._getroot(rev), full_name)

  def last_rev(self, path, peg_revision, limit_revision=None):
    """Given PATH, known to exist in PEG_REVISION, find the youngest
    revision older than, or equal to, LIMIT_REVISION in which path
    exists.  Return that revision, and the path at which PATH exists in
    that revision."""

    # Here's the plan, man.  In the trivial case (where PEG_REVISION is
    # the same as LIMIT_REVISION), this is a no-brainer.  If
    # LIMIT_REVISION is older than PEG_REVISION, we can use Subversion's
    # history tracing code to find the right location.  If, however,
    # LIMIT_REVISION is younger than PEG_REVISION, we suffer from
    # Subversion's lack of forward history searching.  Our workaround,
    # ugly as it may be, involves a binary search through the revisions
    # between PEG_REVISION and LIMIT_REVISION to find our last live
    # revision.
    peg_revision = self._getrev(peg_revision)
    limit_revision = self._getrev(limit_revision)
    try:
      if peg_revision == limit_revision:
        return peg_revision, path
      elif peg_revision > limit_revision:
        fsroot = self._getroot(peg_revision)
        history = _svn_repos.svn_fs_node_history(fsroot, path)
        while history:
          path, peg_revision = _svn_repos.svn_fs_history_location(history)
          if peg_revision <= limit_revision:
            return max(peg_revision, limit_revision), _cleanup_path(path)
          history = _svn_repos.svn_fs_history_prev(history, 1)
        return peg_revision, _cleanup_path(path)
      else:
        orig_id = _svn_repos.svn_fs_node_id(self._getroot(peg_revision), path)
        while peg_revision != limit_revision:
          mid = (peg_revision + 1 + limit_revision) / 2
          try:
            mid_id = _svn_repos.svn_fs_node_id(self._getroot(mid), path)
          except _svn.SVNerr, e:
            if e.get_code() == _svn.SVN_ERR_FS_NOT_FOUND:
              cmp = -1
            else:
              raise
          else:
            ### Not quite right.  Need a comparison function that only returns
            ### true when the two nodes are the same copy, not just related.
            cmp = _svn_repos.svn_fs_compare_ids(orig_id, mid_id)

          if cmp in (0, 1):
            peg_revision = mid
          else:
            limit_revision = mid - 1

        return peg_revision, path
    finally:
      pass

  def get_symlink_target(self, path_parts, rev):
    """Return the target of the symbolic link versioned at PATH_PARTS
    in REV, or None if that object is not a symlink."""

    path = self._getpath(path_parts)
    rev = self._getrev(rev)
    path_type = self.itemtype(path_parts, rev)  # does auth-check
    fsroot = self._getroot(rev)

    # Symlinks must be files with the svn:special property set on them
    # and with file contents which read "link SOME_PATH".
    if path_type != vclib.FILE:
      return None
    props = _svn_repos.svn_fs_node_proplist(fsroot, path)
    if not props.has_key(_svn.SVN_PROP_SPECIAL):
      return None
    pathspec = b''
    ### FIXME: We're being a touch sloppy here, only checking the first line
    ### of the file.
    stream = _svn_repos.svn_fs_file_contents(fsroot, path)
    try:
      pathspec, eof = _svn.svn_stream_readline(stream, b'\n')
    finally:
      _svn.svn_stream_close(stream)
    if pathspec[:5] != b'link ':
      return None
    return pathspec[5:]

