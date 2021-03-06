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

"Version Control lib driver for remotely accessible Subversion repositories."

import vclib
import sys
import os
import io
import re
import tempfile

if sys.version_info[0] >= 3:
  PY3 = True
  import functools
  from urllib.parse import quote as _quote
else:
  PY3 = False
  from urllib import quote as _quote

from . import _svn, _svn_ra, _path_parts, _cleanup_path,\
              _compare_paths, _split_revprops, Revision, SVNChangedPath
#from svn import client


### Require Subversion 1.3.1 or better. (for svn_ra_get_locations support)
# foolproof. because _svn cannot build with API version below 1.4
if (_svn.SVN_VER_MAJOR, _svn.SVN_VER_MINOR, _svn.SVN_VER_PATCH) < (1, 3, 1):
  raise vclib.Error("Version requirement not met (needs 1.3.1 or better)")


class LogCollector:

  def __init__(self, path, show_all_logs, lockinfo, access_check_func):
    # This class uses leading slashes for paths internally
    if not path:
      self.path = '/'
    else:
      self.path = path[0] == '/' and path or '/' + path
    self.logs = []
    self.show_all_logs = show_all_logs
    self.lockinfo = lockinfo
    self.access_check_func = access_check_func
    self.done = False

  @staticmethod
  def add_log(self, log_entry, pool):
    if self.done:
      return
    paths = log_entry.changed_paths
    revision = log_entry.revision
    msg, author, date, revprops = _split_revprops(log_entry.revprops)

    # Changed paths have leading slashes
    if PY3:
      changed_paths = list(paths.keys())
      changed_paths.sort(key=functools.cmp_to_key(
                                           lambda a, b: _compare_paths(a, b)))
    else:
      changed_paths = paths.keys()
      changed_paths.sort(lambda a, b: _compare_paths(a, b))
    this_path = None
    if self.path in changed_paths:
      this_path = self.path
      change = paths[self.path]
      if change.copyfrom_path:
        this_path = change.copyfrom_path
    for changed_path in changed_paths:
      if changed_path != self.path:
        # If a parent of our path was copied, our "next previous"
        # (huh?) path will exist elsewhere (under the copy source).
        if (self.path.rfind(changed_path) == 0) and \
               self.path[len(changed_path)] == '/':
          change = paths[changed_path]
          if change.copyfrom_path:
            this_path = change.copyfrom_path + self.path[len(changed_path):]
    if self.show_all_logs or this_path:
      if self.access_check_func is None \
         or self.access_check_func(self.path[1:], revision):
        entry = Revision(revision, date, author, msg, None, self.lockinfo,
                         self.path[1:], None, None)
        self.logs.append(entry)
      else:
        self.done = True
    if this_path:
      self.path = this_path

def cat_to_tempfile(svnrepos, path, rev, scratch_pool):
  """Check out file revision to temporary file"""
  fd, temp = tempfile.mkstemp()
  fp = io.open(fd, 'wb')
  stream = _svn.py_io_stream(fp, scratch_pool)
  url = svnrepos._geturl(path)
  _svn_ra.svn_client_cat(stream, url, rev, rev, False, False,
                         svnrepos.ctx, scratch_pool)
  _svn.svn_stream_close(stream)
  return temp

class SelfCleanFP:
  def __init__(self, path):
    self._fp = open(path, 'rb')
    self._path = path
    self._eof = 0

  def read(self, len=None):
    if len:
      chunk = self._fp.read(len)
    else:
      chunk = self._fp.read()
    if chunk == b'':
      self._eof = 1
    return chunk

  def readline(self):
    chunk = self._fp.readline()
    if chunk == b'':
      self._eof = 1
    return chunk

  def readlines(self):
    lines = self._fp.readlines()
    self._eof = 1
    return lines

  def close(self):
    self._fp.close()
    if self._path:
      try:
        os.remove(self._path)
        self._path = None
      except OSError:
        pass

  def __del__(self):
    self.close()

  def eof(self):
    return self._eof


class RemoteSubversionRepository(vclib.Repository):
  def __init__(self, name, rootpath, authorizer, utilities, config_dir):
    self.name = name
    self.rootpath = rootpath
    self.auth = authorizer
    self.diff_cmd = utilities.diff or 'diff'
    self.config_dir = config_dir or None
    self.result_pool = _svn.Apr_Pool()
    self.scratch_pool = _svn.Apr_Pool()

    # See if this repository is even viewable, authz-wise.
    if not vclib.check_root_access(self):
      raise vclib.ReposNotFound(name)

  def open(self):
    # Setup the client context baton, complete with non-prompting authstuffs.
    self.ctx = _svn.setup_client_ctx(self.config_dir, self.result_pool)
    self.ra_session = _svn_ra.open_session_with_ctx(self.rootpath, self.ctx)

    self.youngest = _svn_ra.svn_ra_get_latest_revnum(
                                    self.ra_session, self.scratch_pool)
    self._dirent_cache = { }
    self._revinfo_cache = { }

    # See if a universal read access determination can be made.
    if self.auth and self.auth.check_universal_access(self.name) == 1:
      self.auth = None
    self.scratch_pool.clear()

  def rootname(self):
    return self.name

  def rootpath(self):
    return self.rootpath

  def roottype(self):
    return vclib.SVN

  def authorizer(self):
    return self.auth

  def itemtype(self, path_parts, rev):
    pathtype = None
    if not len(path_parts):
      pathtype = vclib.DIR
    else:
      path = self._getpath(path_parts)
      rev = self._getrev(rev)
      try:
        kind = _svn_ra.svn_ra_check_path(
                                self.ra_session, path, rev, self.scratch_pool)
        if kind == _svn.svn_node_file:
          pathtype = vclib.FILE
        elif kind == _svn.svn_node_dir:
          pathtype = vclib.DIR
      except:
        pass
    if pathtype is None:
      raise vclib.ItemNotFound(path_parts)
    if not vclib.check_path_access(self, path_parts, pathtype, rev):
      raise vclib.ItemNotFound(path_parts)
    return pathtype

  def openfile(self, path_parts, rev, options):
    path = self._getpath(path_parts)
    if self.itemtype(path_parts, rev) != vclib.FILE:  # does auth-check
      raise vclib.Error("Path '%s' is not a file." % _svn._norm(path))
    rev = self._getrev(rev)
    url = self._geturl(path)
    ### rev here should be the last history revision of the URL
    fp = SelfCleanFP(cat_to_tempfile(self, path, rev, self.scratch_pool))
    lh_rev, c_rev = self._get_last_history_rev(path_parts, rev)
    return fp, lh_rev

  def listdir(self, path_parts, rev, options):
    path = self._getpath(path_parts)
    if self.itemtype(path_parts, rev) != vclib.DIR:  # does auth-check
      raise vclib.Error("Path '%s' is not a directory." % _svn._norm(path))
    rev = self._getrev(rev)
    entries = []
    dirents, locks = self._get_dirents(path, rev)
    for name in dirents.keys():
      entry = dirents[name]
      if entry.kind == _svn.svn_node_dir:
        kind = vclib.DIR
      elif entry.kind == _svn.svn_node_file:
        kind = vclib.FILE
      else:
        kind = None
      entries.append(vclib.DirEntry(name, kind))
    return entries

  def dirlogs(self, path_parts, rev, entries, options):
    path = self._getpath(path_parts)
    if self.itemtype(path_parts, rev) != vclib.DIR:  # does auth-check
      raise vclib.Error("Path '%s' is not a directory." % _svn._norm(path))
    rev = self._getrev(rev)
    dirents, locks = self._get_dirents(path, rev)
    for entry in entries:
      dirent = dirents.get(entry.name, None)
      # dirents is authz-sanitized, so ensure the entry is found therein.
      if dirent is None:
        continue
      # Get authz-sanitized revision metadata.
      entry.date, entry.author, entry.log, revprops, changes = \
                  self._revinfo(dirent.created_rev)
      entry.rev = str(dirent.created_rev)
      entry.size = dirent.size
      entry.lockinfo = None
      if entry.name in locks:
        entry.lockinfo = locks[entry.name].owner

  def itemlog(self, path_parts, rev, sortby, first, limit, options):
    assert sortby == vclib.SORTBY_DEFAULT or sortby == vclib.SORTBY_REV
    path_type = self.itemtype(path_parts, rev) # does auth-check
    path = self._getpath(path_parts)
    rev = self._getrev(rev)
    url = self._geturl(path)

    # If this is a file, fetch the lock status and size (as of REV)
    # for this item.
    lockinfo = size_in_rev = None
    if path_type == vclib.FILE:
      basename = path_parts[-1]
      if not isinstance(basename, bytes):
          basename = basename.encode('utf-8', 'surrogateescape')
      list_url = self._geturl(self._getpath(path_parts[:-1]))
      dirents, locks = _svn_ra.list_directory(
                            list_url, rev, rev, 0, self.ctx, self.scratch_pool)
      if basename in locks:
        lockinfo = locks[basename].owner
      if basename in dirents:
        size_in_rev = dirents[basename].size

    # Special handling for the 'svn_latest_log' scenario.
    ### FIXME: Don't like this hack.  We should just introduce
    ### something more direct in the vclib API.
    if options.get('svn_latest_log', 0):
      dir_lh_rev, dir_c_rev = self._get_last_history_rev(path_parts, rev)
      date, author, log, revprops, changes = self._revinfo(dir_lh_rev)
      return [vclib.Revision(dir_lh_rev, str(dir_lh_rev), date, author,
                             None, log, size_in_rev, lockinfo)]

    def _access_checker(check_path, check_rev):
      return vclib.check_path_access(self, _path_parts(check_path),
                                     path_type, check_rev)

    # It's okay if we're told to not show all logs on a file -- all
    # the revisions should match correctly anyway.
    lc = LogCollector(path, options.get('svn_show_all_dir_logs', 0),
                      lockinfo, _access_checker)

    cross_copies = options.get('svn_cross_copies', 0)
    log_limit = 0
    if limit:
      log_limit = first + limit
    _svn_ra.client_log(url, rev, 1, log_limit, 1,
                       cross_copies, lc.add_log, lc, self.ctx,
                       self.scratch_pool)
    revs = lc.logs
    revs.sort()
    prev = None
    for rev in revs:
      # Swap out revision info with stuff from the cache (which is
      # authz-sanitized).
      rev.date, rev.author, rev.log, revprops, changes \
                = self._revinfo(rev.number)
      rev.prev = prev
      prev = rev
    revs.reverse()

    if len(revs) < first:
      return []
    if limit:
      return revs[first:first+limit]
    return revs

  def itemprops(self, path_parts, rev):
    path = self._getpath(path_parts)
    path_type = self.itemtype(path_parts, rev) # does auth-check
    rev = self._getrev(rev)
    url = self._geturl(path)
    return _svn_ra.simple_proplist(url, rev, self.ctx, self.scratch_pool)

  def annotate(self, path_parts, rev, include_text=False):
    def _blame_cb(btn, line_no, revision, author, date,
                  line):
      prev_rev = None
      if revision > 1:
        prev_rev = revision - 1

      # If we have an invalid revision, clear the date and author
      # values.  Otherwise, if we have authz filtering to do, use the
      # revinfo cache to do so.
      if revision < 0:
        date = author = None
      elif self.auth:
        date, author, msg, revprops, changes = self._revinfo(revision)

      # Strip text if the caller doesn't want it.
      if not btn.include_text:
        line = None
      btn.btn.append(vclib.Annotation(line, line_no + 1, revision, prev_rev,
                                         author, date))
    # annotate() body
    path = self._getpath(path_parts)
    if self.itemtype(path_parts, rev) != vclib.FILE:  # does auth-check
      raise vclib.Error("Path '%s' is not a file." % path)
    rev = self._getrev(rev)
    url = self._geturl(path)

    # Examine logs for the file to determine the oldest revision we are
    # permitted to see.
    log_options = {
      'svn_cross_copies' : 1,
      'svn_show_all_dir_logs' : 1,
      }
    revs = self.itemlog(path_parts, rev, vclib.SORTBY_REV, 0, 0, log_options)
    oldest_rev = revs[-1].number

    # Now calculate the annotation data.  Note that we'll not
    # inherently trust the provided author and date, because authz
    # rules might necessitate that we strip that information out.
    blame_data = _svn._get_annotated_source(
                        url, rev, oldest_rev, _blame_cb, self.ctx,
                        include_text, self.scratch_pool)
    self.scratch_pool.clear()
    return blame_data, rev

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
      temp1 = cat_to_tempfile(self, p1, r1, self.scratch_pool)
      temp2 = cat_to_tempfile(self, p2, r2, self.scratch_pool)
      info1 = p1, _date_from_rev(r1), r1
      info2 = p2, _date_from_rev(r2), r2
      return vclib._diff_fp(temp1, temp2, info1, info2, self.diff_cmd, args)
    except _svn.SVNerr as  e:
      if e.get_code() == _svn.SVN_ERR_FS_NOT_FOUND:
        raise vclib.InvalidRevision
      raise

  def isexecutable(self, path_parts, rev):
    props = self.itemprops(path_parts, rev) # does authz-check
    return _svn.SVN_PROP_EXECUTABLE in props

  def filesize(self, path_parts, rev):
    path = self._getpath(path_parts)
    if self.itemtype(path_parts, rev) != vclib.FILE:  # does auth-check
      raise vclib.Error("Path '%s' is not a file." % path)
    rev = self._getrev(rev)
    dirents, locks = self._get_dirents(self._getpath(path_parts[:-1]), rev)
    dirent = dirents.get(path_parts[-1], None)
    return dirent.size

  def _getpath(self, path_parts):
    return '/'.join(path_parts)

  def _getrev(self, rev):
    if PY3 and isinstance(rev, bytes):
      rev = rev.decode('utf-8')
    if rev is None or rev == 'HEAD':
      return self.youngest
    try:
      if isinstance(rev, str):
        while rev[0] == 'r':
          rev = rev[1:]
      rev = int(rev)
    except:
      raise vclib.InvalidRevision(rev)
    if (rev < 0) or (rev > self.youngest):
      raise vclib.InvalidRevision(rev)
    return rev

  def _geturl(self, path=None):
    if not path:
      return self.rootpath
    path = self.rootpath + '/' + _quote(path)
    return _svn.canonicalize_path(path)

  def _get_dirents(self, path, rev):
    """Return a 2-type of dirents and locks, possibly reading/writing
    from a local cache of that information.  This functions performs
    authz checks, stripping out unreadable dirents."""

    dir_url = self._geturl(path)
    path_parts = _path_parts(path)
    if path:
      key = str(rev) + '/' + path
    else:
      key = str(rev)

    # Ensure that the cache gets filled...
    dirents_locks = self._dirent_cache.get(key)
    if not dirents_locks:
      tmp_dirents, locks = _svn_ra.list_directory(dir_url, rev, rev, 0,
                                                  self.ctx, self.scratch_pool)
      dirents = {}
      for name, dirent in tmp_dirents.items():
        dirent_parts = path_parts + [_svn._norm(name)]
        kind = dirent.kind
        if (kind == _svn.svn_node_dir or kind == _svn.svn_node_file) \
           and vclib.check_path_access(self, dirent_parts,
                                       kind == _svn.svn_node_dir \
                                         and vclib.DIR or vclib.FILE, rev):
          lh_rev, c_rev = self._get_last_history_rev(dirent_parts, rev)
          dirent.created_rev = lh_rev
          dirents[name] = dirent
      dirents_locks = [dirents, locks]
      self._dirent_cache[key] = dirents_locks

    # ...then return the goodies from the cache.
    return dirents_locks[0], dirents_locks[1]

  def _get_last_history_rev(self, path_parts, rev):
    """Return the a 2-tuple which contains:
         - the last interesting revision equal to or older than REV in
           the history of PATH_PARTS.
         - the created_rev of of PATH_PARTS as of REV."""

    path = self._getpath(path_parts)
    url = self._geturl(self._getpath(path_parts))

    # Get the last-changed-rev.
    return _svn_ra.get_last_history_rev(
                                url, rev, self.ctx, self.scratch_pool)

  def _revinfo_fetch(self, rev, include_changed_paths=0):
    need_changes = include_changed_paths or self.auth
    revs = []

    def _log_cb(retval, log_entry, pool):
      # If Subversion happens to call us more than once, we choose not
      # to care.
      if retval:
        return

      revision = log_entry.revision
      msg, author, date, revprops = _split_revprops(log_entry.revprops)
      action_map = { 'D' : vclib.DELETED,
                     'A' : vclib.ADDED,
                     'R' : vclib.REPLACED,
                     'M' : vclib.MODIFIED,
                     }

      # Easy out: if we won't use the changed-path info, just return a
      # changes-less tuple.
      if not need_changes:
        return retval.append([date, author, msg, revprops, None])

      # Subversion 1.5 and earlier didn't offer the 'changed_paths2'
      # hash, and in Subversion 1.6, it's offered but broken.
      try:
        changed_paths = log_entry.changed_paths2
        paths = list((changed_paths or {}).keys())
      except:
        changed_paths = log_entry.changed_paths
        paths = list((changed_paths or {}).keys())
      if PY3:
        paths.sort(key=functools.cmp_to_key(lambda a, b: _compare_paths(a, b)))
      else:
        paths.sort(lambda a, b: _compare_paths(a, b))

      # If we get this far, our caller needs changed-paths, or we need
      # them for authz-related sanitization.
      changes = []
      found_readable = found_unreadable = 0
      for path in paths:
        change = changed_paths[path]

        # svn_log_changed_path_t (which we might get instead of the
        # svn_log_changed_path2_t we'd prefer) doesn't have the
        # 'node_kind' member.
        pathtype = None
        if hasattr(change, 'node_kind'):
          if change.node_kind == _svn.svn_node_dir:
            pathtype = vclib.DIR
          elif change.node_kind == _svn.svn_node_file:
            pathtype = vclib.FILE

        # svn_log_changed_path2_t only has the 'text_modified' and
        # 'props_modified' bits in Subversion 1.7 and beyond.  And
        # svn_log_changed_path_t is without.
        text_modified = props_modified = 0
        if hasattr(change, 'text_modified'):
          if change.text_modified == _svn.svn_tristate_true:
            text_modified = 1
        if hasattr(change, 'props_modified'):
          if change.props_modified == _svn.svn_tristate_true:
            props_modified = 1

        # Wrong, diddily wrong wrong wrong.  Can you say,
        # "Manufacturing data left and right because it hurts to
        # figure out the right stuff?"
        action = action_map.get(change.action, vclib.MODIFIED)
        if change.copyfrom_path and change.copyfrom_rev:
          is_copy = 1
          base_path = change.copyfrom_path
          base_rev = change.copyfrom_rev
        elif action == vclib.ADDED or action == vclib.REPLACED:
          is_copy = 0
          base_path = base_rev = None
        else:
          is_copy = 0
          base_path = path
          base_rev = revision - 1

        # Check authz rules (sadly, we have to lie about the path type)
        parts = _path_parts(path)
        if vclib.check_path_access(self, parts, vclib.FILE, revision):
          if is_copy and base_path and (base_path != path):
            parts = _path_parts(base_path)
            if not vclib.check_path_access(self, parts, vclib.FILE, base_rev):
              is_copy = 0
              base_path = None
              base_rev = None
              found_unreadable = 1
          changes.append(SVNChangedPath(path, revision, pathtype, base_path,
                                        base_rev, action, is_copy,
                                        text_modified, props_modified))
          found_readable = 1
        else:
          found_unreadable = 1

        # If our caller doesn't want changed-path stuff, and we have
        # the info we need to make an authz determination already,
        # quit this loop and get on with it.
        if (not include_changed_paths) and found_unreadable and found_readable:
          break

      # Filter unreadable information.
      if found_unreadable:
        msg = None
        if not found_readable:
          author = None
          date = None

      # Drop unrequested changes.
      if not include_changed_paths:
        changes = None

      # Add this revision information to the "return" array.
      retval.append([date, author, msg, revprops, changes])

    _svn_ra.client_log(self.rootpath, rev, rev, 1, need_changes, 0,
               _log_cb, revs, self.ctx, self.scratch_pool)
    return tuple(revs[0])

  def _revinfo(self, rev, include_changed_paths=0):
    """Internal-use, cache-friendly revision information harvester."""

    # Consult the revinfo cache first.  If we don't have cached info,
    # or our caller wants changed paths and we don't have those for
    # this revision, go do the real work.
    rev = self._getrev(rev)
    cached_info = self._revinfo_cache.get(rev)
    if not cached_info \
       or (include_changed_paths and cached_info[4] is None):
      cached_info = self._revinfo_fetch(rev, include_changed_paths)
      self._revinfo_cache[rev] = cached_info
    return cached_info

  ##--- custom --##

  def get_youngest_revision(self):
    return self.youngest

  def get_location(self, path, rev, old_rev):
    if not isinstance(path, bytes):
      path = path.encode('utf-8', 'surrogateescape')
    try:
      results = _svn_ra.svn_ra_get_locations(
                      self.ra_session, path, rev, [old_rev], self.scratch_pool)
    except _svn.SVNerr as e:
      if e.get_code() == _svn.SVN_ERR_FS_NOT_FOUND:
        raise vclib.ItemNotFound(path)
      raise
    try:
      old_path = results[old_rev]
    except KeyError:
      raise vclib.ItemNotFound(path)
    old_path = _cleanup_path(old_path)
    old_path_parts = _path_parts(old_path)
    # Check access (lying about path types)
    if not vclib.check_path_access(self, old_path_parts, vclib.FILE, old_rev):
      raise vclib.ItemNotFound(path)
    return old_path

  def created_rev(self, path, rev):
    if PY3 and isinstance(path, bytes):
      path = _svn._norm(path)
    lh_rev, c_rev = self._get_last_history_rev(_path_parts(path), rev)
    return lh_rev

  def last_rev(self, path, peg_revision, limit_revision=None):
    """Given PATH, known to exist in PEG_REVISION, find the youngest
    revision older than, or equal to, LIMIT_REVISION in which path
    exists.  Return that revision, and the path at which PATH exists in
    that revision."""

    if not isinstance(path, bytes):
        path = path.encode('utf-8', 'surrogateescape')

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
    if peg_revision == limit_revision:
      return peg_revision, path
    elif peg_revision > limit_revision:
      path = self.get_location(path, peg_revision, limit_revision)
      return limit_revision, path
    else:
      direction = 1
      while peg_revision != limit_revision:
        mid = (peg_revision + 1 + limit_revision) // 2
        try:
          path = self.get_location(path, peg_revision, mid)
        except vclib.ItemNotFound:
          limit_revision = mid - 1
        else:
          peg_revision = mid
      return peg_revision, path

  def get_symlink_target(self, path_parts, rev):
    """Return the target of the symbolic link versioned at PATH_PARTS
    in REV, or None if that object is not a symlink."""

    path = self._getpath(path_parts)
    path_type = self.itemtype(path_parts, rev) # does auth-check
    rev = self._getrev(rev)
    url = self._geturl(path)

    # Symlinks must be files with the svn:special property set on them
    # and with file contents which read "link SOME_PATH".
    if path_type != vclib.FILE:
      return None
    props = _svn_ra.simple_proplist(url, rev, self.ctx, self.scratch_pool)
    if _svn.SVN_PROP_SPECIAL not in props:
      return None
    pathspec = ''
    ### FIXME: We're being a touch sloppy here, first by grabbing the
    ### whole file and then by checking only the first line
    ### of it.
    fp = SelfCleanFP(cat_to_tempfile(self, path, rev))
    pathspec = fp.readline()
    fp.close()
    if pathspec[:5] != 'link ':
      return None
    return pathspec[5:]

