// Unit tests for `pruneOrphanedSubtree` — the empty-directory pruning
// helper that powers the embedded prune in `_SolidBuilder.build()`.
//
// Each test sets up parallel `lib/` and `source/` trees inside a freshly
// created temp directory and asserts which entries (files + dirs) survive.

import 'dart:io';

import 'package:solid_generator/src/empty_dir_pruner.dart';
import 'package:test/test.dart';

void main() {
  group('pruneOrphanedSubtree', () {
    late Directory temp;
    late Directory libRoot;
    late Directory sourceRoot;

    setUp(() {
      temp = Directory.systemTemp.createTempSync('solid_pruner_');
      libRoot = Directory('${temp.path}/lib');
      sourceRoot = Directory('${temp.path}/source');
    });

    tearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });

    test('orphan file deleted, then ascending empty dirs pruned', () {
      Directory('${libRoot.path}/test/ui').createSync(recursive: true);
      File('${libRoot.path}/test/ui/widget.dart').writeAsStringSync('');
      // No counterpart in source/ at all.
      sourceRoot.createSync();

      final removed = pruneOrphanedSubtree(libRoot, sourceRoot);

      expect(removed, 3, reason: 'widget.dart + ui/ + test/ all removed');
      expect(File('${libRoot.path}/test/ui/widget.dart').existsSync(), isFalse);
      expect(Directory('${libRoot.path}/test').existsSync(), isFalse);
      expect(libRoot.existsSync(), isTrue);
    });

    test('source counterpart still exists -> keep file and dirs', () {
      Directory('${libRoot.path}/test/ui').createSync(recursive: true);
      File('${libRoot.path}/test/ui/widget.dart').writeAsStringSync('');
      Directory('${sourceRoot.path}/test/ui').createSync(recursive: true);
      File('${sourceRoot.path}/test/ui/widget.dart').writeAsStringSync('');

      final removed = pruneOrphanedSubtree(libRoot, sourceRoot);

      expect(removed, 0);
      expect(File('${libRoot.path}/test/ui/widget.dart').existsSync(), isTrue);
    });

    test('empty subtree with missing source -> all dirs pruned', () {
      Directory('${libRoot.path}/a/b/c').createSync(recursive: true);
      sourceRoot.createSync();

      final removed = pruneOrphanedSubtree(libRoot, sourceRoot);

      expect(removed, 3);
      expect(Directory('${libRoot.path}/a').existsSync(), isFalse);
    });

    test('mixed: orphan file siblings stay when other file lives', () {
      // lib/a/orphan.dart is an orphan; lib/a/keep.dart has a counterpart.
      Directory(libRoot.path).createSync(recursive: true);
      Directory('${libRoot.path}/a').createSync();
      File('${libRoot.path}/a/orphan.dart').writeAsStringSync('');
      File('${libRoot.path}/a/keep.dart').writeAsStringSync('');
      Directory('${sourceRoot.path}/a').createSync(recursive: true);
      File('${sourceRoot.path}/a/keep.dart').writeAsStringSync('');

      final removed = pruneOrphanedSubtree(libRoot, sourceRoot);

      expect(
        removed,
        1,
        reason: 'orphan.dart removed; a/ kept (has keep.dart)',
      );
      expect(File('${libRoot.path}/a/orphan.dart').existsSync(), isFalse);
      expect(File('${libRoot.path}/a/keep.dart').existsSync(), isTrue);
      expect(Directory('${libRoot.path}/a').existsSync(), isTrue);
    });

    test('mid-tree source still present -> stop ascending', () {
      Directory('${libRoot.path}/a/b/c').createSync(recursive: true);
      // source/a/b exists, but source/a/b/c does not.
      Directory('${sourceRoot.path}/a/b').createSync(recursive: true);

      final removed = pruneOrphanedSubtree(libRoot, sourceRoot);

      expect(removed, 1, reason: 'only c is orphaned');
      expect(Directory('${libRoot.path}/a/b/c').existsSync(), isFalse);
      expect(Directory('${libRoot.path}/a/b').existsSync(), isTrue);
    });

    test('empty source counterpart -> empty lib dir is preserved', () {
      // The lib tree mirrors the source tree, so an empty `source/test/`
      // (whether the user kept it intentionally or just hasn't removed it
      // yet) keeps `lib/test/` in place.
      Directory('${libRoot.path}/test').createSync(recursive: true);
      Directory('${sourceRoot.path}/test').createSync(recursive: true);

      final removed = pruneOrphanedSubtree(libRoot, sourceRoot);

      expect(removed, 0);
      expect(Directory('${libRoot.path}/test').existsSync(), isTrue);
    });

    test('libRoot itself empty -> never deleted', () {
      libRoot.createSync(recursive: true);
      sourceRoot.createSync();

      final removed = pruneOrphanedSubtree(libRoot, sourceRoot);

      expect(removed, 0);
      expect(libRoot.existsSync(), isTrue);
    });

    test('symlinks under lib are left alone', () {
      final external = Directory('${temp.path}/external')..createSync();
      File('${external.path}/keep.txt').writeAsStringSync('hi');
      libRoot.createSync(recursive: true);
      Link('${libRoot.path}/linked').createSync(external.path);
      sourceRoot.createSync();

      final removed = pruneOrphanedSubtree(libRoot, sourceRoot);

      expect(removed, 0);
      expect(
        FileSystemEntity.isLinkSync('${libRoot.path}/linked'),
        isTrue,
      );
    });

    test('lib/ does not exist -> no-op, no error', () {
      sourceRoot.createSync();

      final removed = pruneOrphanedSubtree(libRoot, sourceRoot);

      expect(removed, 0);
      expect(libRoot.existsSync(), isFalse);
    });

    test('source/ does not exist -> safety guard: no-op', () {
      // A missing source/ root is a strong signal we are not in a consumer
      // package (e.g., the generator's own package, or a test runner whose
      // CWD is not a consumer root). Treat as no-op to avoid erasing
      // legitimate code.
      Directory('${libRoot.path}/x/y').createSync(recursive: true);
      File('${libRoot.path}/x/y/file.dart').writeAsStringSync('');

      final removed = pruneOrphanedSubtree(libRoot, sourceRoot);

      expect(removed, 0);
      expect(File('${libRoot.path}/x/y/file.dart').existsSync(), isTrue);
      expect(Directory('${libRoot.path}/x/y').existsSync(), isTrue);
    });
  });
}
