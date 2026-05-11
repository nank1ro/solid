import 'dart:io';

/// Walks [libRoot] bottom-up and removes every orphan output: a file under
/// `<libRoot>/X/Y/file.ext` whose `<sourceRoot>/X/Y/file.ext` counterpart
/// no longer exists, and every directory `<libRoot>/X/Y/Z` that becomes
/// empty after orphan-file removal AND whose `<sourceRoot>/X/Y/Z`
/// counterpart no longer exists either.
///
/// The directory rule preserves user-managed structure: if `source/X/`
/// exists (even as an empty directory the user keeps for layout), `lib/X/`
/// is left in place so the lib tree mirrors the source tree.
///
/// Does NOT delete [libRoot] itself, even when its last subtree is pruned —
/// the package's `lib/` is a fixed point. Returns the total number of
/// filesystem entries removed (files + directories) for assertion in unit
/// tests.
///
/// Symbolic links are not followed and not deleted: any symlinked content
/// under `lib/` is user-owned and out of scope.
///
/// `FileSystemException` from `listSync` / `deleteSync` is swallowed: in a
/// concurrent build, two builders can race on the same directory (one
/// writes a new file just as the other tries to delete it, or one deletes
/// the dir just before the other reaches it). The state we want — orphans
/// removed, populated dirs preserved — is reached either way.
///
/// Empty-directory pruning. The build extension `^source/{{}} -> lib/{{}}`
/// defines the pairing rule that determines which lib outputs are orphans.
///
/// Safety guard: when [sourceRoot] does NOT exist on disk, the pruner
/// returns 0 immediately without touching anything. A missing `source/`
/// directory means the current working directory is not a consumer
/// package using the `^source/{{}} -> lib/{{}}` build extension (e.g., the
/// `solid_generator` package itself, or a test runner whose
/// `Directory.current` is not a consumer root) — treating every `lib/`
/// entry as an orphan in that case would erase legitimate code.
int pruneOrphanedSubtree(Directory libRoot, Directory sourceRoot) {
  if (!libRoot.existsSync()) return 0;
  if (!sourceRoot.existsSync()) return 0;
  return _pruneInto(libRoot, libRoot, sourceRoot).removed;
}

/// Bottom-up walk: recurses into each `Directory` child first, then for
/// each child decides whether to delete it. Returns the entries removed in
/// the subtree rooted at [current], and whether [current] is empty after
/// the pass — the caller uses `isEmpty` to decide whether [current] itself
/// is a delete candidate. The top-level call uses [libRoot] as `current`
/// and discards `isEmpty` so the root is never deleted.
({int removed, bool isEmpty}) _pruneInto(
  Directory libRoot,
  Directory current,
  Directory sourceRoot,
) {
  var removed = 0;
  var remaining = 0;
  final List<FileSystemEntity> children;
  try {
    children = current.listSync(followLinks: false);
  } on FileSystemException {
    return (removed: 0, isEmpty: false);
  }
  for (final entity in children) {
    if (entity is Link) {
      remaining++;
      continue;
    }
    if (entity is Directory) {
      final result = _pruneInto(libRoot, entity, sourceRoot);
      removed += result.removed;
      if (result.isEmpty && !_counterpartExists(libRoot, entity, sourceRoot)) {
        if (_tryDelete(entity)) {
          removed++;
        } else {
          remaining++;
        }
      } else {
        remaining++;
      }
    } else if (entity is File) {
      if (!_counterpartExists(libRoot, entity, sourceRoot)) {
        if (_tryDelete(entity)) {
          removed++;
        } else {
          remaining++;
        }
      } else {
        remaining++;
      }
    } else {
      remaining++;
    }
  }
  return (removed: removed, isEmpty: remaining == 0);
}

/// True iff [entity]'s `<sourceRoot>/<relative>` counterpart exists. Used
/// for both files (`File(counterpath).existsSync()`) and directories
/// (`Directory(counterpath).existsSync()`). The lib root itself is treated
/// as always-present so the caller's recursion never deletes it.
bool _counterpartExists(
  Directory libRoot,
  FileSystemEntity entity,
  Directory sourceRoot,
) {
  final relative = _relativeUnder(libRoot, entity.path);
  if (relative.isEmpty) return true;
  final counterpath = '${sourceRoot.path}/$relative';
  return entity is Directory
      ? Directory(counterpath).existsSync()
      : File(counterpath).existsSync();
}

bool _tryDelete(FileSystemEntity entity) {
  try {
    entity.deleteSync();
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Returns [childPath]'s path relative to [root], using `/` separators.
/// Empty when [childPath] is [root] itself.
String _relativeUnder(Directory root, String childPath) {
  final rootPath = root.path.replaceAll(r'\', '/');
  final normalized = childPath.replaceAll(r'\', '/');
  if (normalized == rootPath) return '';
  final prefix = rootPath.endsWith('/') ? rootPath : '$rootPath/';
  return normalized.startsWith(prefix)
      ? normalized.substring(prefix.length)
      : normalized;
}
