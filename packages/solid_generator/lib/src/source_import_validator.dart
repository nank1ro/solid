import 'package:analyzer/dart/ast/ast.dart';
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
void validateSourceImportsFromText(String source, String currentPackage) {
  // Dart import URIs may be wrapped in either quote style, and the text
  // scan has no parser — check both.
  final singleQuoted = "'package:$currentPackage/";
  final doubleQuoted = '"package:$currentPackage/';
  if (!source.contains(singleQuoted) && !source.contains(doubleQuoted)) return;
  _rejectSamePackageImport(currentPackage, null);
}

/// AST-precise re-check of the [validateSourceImportsFromText] rule. Walks
/// every `ImportDirective` in [unit] and throws on the first same-package
/// `package:` URI. Cheap (single `whereType` pass) and produces a precise
/// error message including the offending URI text.
void validateSourceImportsFromAst(CompilationUnit unit, String currentPackage) {
  final selfPrefix = 'package:$currentPackage/';
  for (final directive in unit.directives.whereType<ImportDirective>()) {
    final uri = directive.uri.stringValue;
    if (uri == null) continue;
    if (uri.startsWith(selfPrefix)) {
      _rejectSamePackageImport(currentPackage, uri);
    }
  }
}

/// Throws the canonical [CodeGenerationError] for a same-package import
/// violation. [offendingUri] is the exact URI when known (AST path) and
/// `null` when only the prefix was detected via text scan.
Never _rejectSamePackageImport(String currentPackage, String? offendingUri) {
  final detail = offendingUri != null ? ': $offendingUri' : '';
  throw CodeGenerationError(
    'Source-side same-package `package:` import is not allowed$detail. '
    'Use a relative path (e.g. `../controllers/foo.dart`) so source/ stays '
    'self-contained. See SPEC §2.',
    null,
    offendingUri ?? 'package:$currentPackage/',
  );
}
