import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/ast_compat.dart';
import 'package:solid_generator/src/class_kind.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// Lowers `.value` reads on a PURE CONSUMER plain class — one that reaches a
/// cross-file `@SolidState`-bearing class only through constructor injection
/// or a plain instance field, while declaring NO `@Solid*` annotation of its
/// own (issue #106).
///
/// Such a class never reaches `rewritePlainClass` / `rewriteStateClass` /
/// `rewriteStatelessWidget` — those only run for a class with at least one
/// reactive member of its OWN, because they unconditionally add `implements
/// Disposable` and synthesize a `dispose()`, which would be wrong here: a
/// pure consumer owns no reactive member and disposes nothing of its own.
/// Instead, this function applies the exact same name-based `.value` rewrite
/// `rewriteUserMethod` applies to a NON-annotated member of an
/// already-annotated class — using an EMPTY same-class reactive-name set
/// (there is none) and [classRegistry] (already merged with the cross-file
/// entries `builder.dart::_populateCrossFileTypes` seeds) for the
/// cross-class branch.
///
/// Scope, matched to parity with the annotated-class pipeline:
///  * Only [ClassKind.plainClass] declarations are visited. A pure-consumer
///    `StatelessWidget`/`State<X>` whose `build()` reads a cross-file signal
///    needs SignalBuilder-wrap placement to rebuild reactively — a
///    structurally different, larger change this function does not attempt.
///    Skipping those class kinds here avoids emitting a `.value` read with
///    no subscription, which would look fixed while staying silently
///    non-reactive.
///  * Only constructors and methods (including getters/setters) are visited.
///    Field initializers are left verbatim — `rewritePlainClass` applies the
///    same rule to non-annotated fields on an already-annotated class.
///  * Factory constructors are skipped — `rewritePlainClass` round-trips
///    them verbatim for the same reason (a factory body is a delegating
///    return, not an instance-scoped body).
///  * Bare top-level functions reading a cross-file signal outside any class
///    are a known, accepted gap: the reproduced issue and every reported
///    real-world shape are DI-shaped (a class holding another class).
///
/// Returns [text] unchanged (by reference) when no visited member contains a
/// rewrite — callers rely on that identity to skip re-formatting an
/// untouched file.
String lowerPureConsumerCrossFileReads(
  String text, {
  CompilationUnit? unit,
  required Map<String, Set<String>> classRegistry,
  required Map<String, Set<String>> classCollectionFields,
}) {
  if (classRegistry.isEmpty) return text;
  final ast =
      unit ??
      parseString(
        content: text,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      ).unit;
  final edits = <ValueEdit>[];
  for (final decl in ast.declarations) {
    if (decl is! ClassDeclaration) continue;
    if (classKindOf(decl) != ClassKind.plainClass) continue;
    for (final member in decl.members) {
      if (member is ConstructorDeclaration) {
        if (member.factoryKeyword != null) continue;
      } else if (member is! MethodDeclaration) {
        continue;
      }
      final result = collectValueEdits(
        member,
        const <String>{},
        text,
        classRegistry: classRegistry,
        classCollectionFields: classCollectionFields,
      );
      edits.addAll(result.edits);
    }
  }
  if (edits.isEmpty) return text;
  return applyEditsToRange(text, edits, 0);
}
