import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Rejects same-package `package:<currentPackage>/...` URIs in source files.
/// Source is the authored realm; `lib/` is the generated-artifact realm.
/// The two must never cross — a same-package `package:` URI resolves to
/// `lib/`, which would point a source file at the lowered output of one of
/// its siblings. Use a relative URI instead (e.g. `../controllers/foo.dart`).
///
/// Two entry points keep the rule universal:
///   * [validateSourceImportsFromText] — cheap pre-parse scan that catches
///     the violation in any source file, including unannotated ones that
///     would otherwise bypass parsing entirely.
///   * [validateSourceImportsFromAst] — precise post-parse pass on files
///     the builder already parses; redundant but cheaper to keep correct
///     than to skip (one extra `whereType` walk per parsed file).
///
/// Both pass [sourcePath] (the input file's source-side path) so the error
/// pinpoints the line in `source/` — `lib/` is the generated realm and
/// never appears in this error chain.
void validateSourceImportsFromText(
  String source,
  String currentPackage,
  String sourcePath,
) {
  // Dart import URIs may be wrapped in either quote style, and the text
  // scan has no parser — check both.
  final singleQuoted = "'package:$currentPackage/";
  final doubleQuoted = '"package:$currentPackage/';
  final offset = _firstOffset(source, [singleQuoted, doubleQuoted]);
  if (offset == null) return;
  _rejectSamePackageImport(
    currentPackage: currentPackage,
    sourcePath: sourcePath,
    source: source,
    offset: offset,
    offendingUri: null,
  );
}

/// AST-precise re-check of the [validateSourceImportsFromText] rule. Walks
/// every `ImportDirective` in [unit] and throws on the first same-package
/// `package:` URI. Cheap (single `whereType` pass) and produces a precise
/// error message including the offending URI text.
void validateSourceImportsFromAst(
  CompilationUnit unit,
  String currentPackage,
  String sourcePath,
  String source,
) {
  final selfPrefix = 'package:$currentPackage/';
  for (final directive in unit.directives.whereType<ImportDirective>()) {
    final uri = directive.uri.stringValue;
    if (uri == null) continue;
    if (uri.startsWith(selfPrefix)) {
      _rejectSamePackageImport(
        currentPackage: currentPackage,
        sourcePath: sourcePath,
        source: source,
        offset: directive.offset,
        offendingUri: uri,
      );
    }
  }
}

/// Smallest offset in [text] at which any [needles] entry appears, or `null`
/// if none match. The returned offset points at the opening quote.
int? _firstOffset(String text, List<String> needles) {
  int? best;
  for (final needle in needles) {
    final i = text.indexOf(needle);
    if (i < 0) continue;
    if (best == null || i < best) best = i;
  }
  return best;
}

/// Extracts the URI from a Dart `'package:...'` / `"package:..."` literal at
/// [offset]. Returns `null` for a malformed literal at that position.
String? _extractUri(String source, int offset) {
  if (offset < 0 || offset >= source.length) return null;
  final quote = source[offset];
  if (quote != "'" && quote != '"') return null;
  final close = source.indexOf(quote, offset + 1);
  if (close < 0) return null;
  return source.substring(offset + 1, close);
}

/// Computes the relative URI a source file at [sourcePath] should use to
/// reach the target identified by `package:<currentPackage>/<rest>`. The
/// source tree mirrors `lib/` 1:1, so `<rest>` is also the path under
/// `source/`; the relative path is `../` × (sourcePath's depth) plus that
/// rest. Returns `null` if [offendingUri] is not a same-package URI.
String? _suggestedRelative(
  String sourcePath,
  String currentPackage,
  String offendingUri,
) {
  final pkgPrefix = 'package:$currentPackage/';
  if (!offendingUri.startsWith(pkgPrefix)) return null;
  final rest = offendingUri.substring(pkgPrefix.length);
  const srcPrefix = 'source/';
  final stripped = sourcePath.startsWith(srcPrefix)
      ? sourcePath.substring(srcPrefix.length)
      : sourcePath;
  final lastSlash = stripped.lastIndexOf('/');
  final depth = lastSlash < 0
      ? 0
      : stripped.substring(0, lastSlash).split('/').length;
  return '${'../' * depth}$rest';
}

/// Throws the canonical [CodeGenerationError] for a same-package import
/// violation, locating the offending import to a `source/...dart:line`
/// reference plus a one-line excerpt of the source.
Never _rejectSamePackageImport({
  required String currentPackage,
  required String sourcePath,
  required String source,
  required int offset,
  required String? offendingUri,
}) {
  final lineInfo = LineInfo.fromContent(source);
  final loc = lineInfo.getLocation(offset);
  final lines = source.split('\n');
  final lineText = (loc.lineNumber - 1) < lines.length
      ? lines[loc.lineNumber - 1].trimRight()
      : '';
  final uri = offendingUri ?? _extractUri(source, offset);
  final detail = uri != null ? ': $uri' : '';
  final suggestion = uri != null
      ? _suggestedRelative(sourcePath, currentPackage, uri)
      : null;
  final example = suggestion != null ? '`$suggestion`' : 'a relative path';
  throw CodeGenerationError(
    'Source-side same-package `package:` import is not allowed$detail.\n'
        '  $sourcePath:${loc.lineNumber}\n'
        '  $lineText\n'
        'Use $example so source/ stays self-contained.',
    '$sourcePath:${loc.lineNumber}',
    uri ?? 'package:$currentPackage/',
  );
}
