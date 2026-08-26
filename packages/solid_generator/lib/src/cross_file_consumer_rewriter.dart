import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/ast_compat.dart';
import 'package:solid_generator/src/build_rewriter.dart';
import 'package:solid_generator/src/class_kind.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// Combined result of [lowerPureConsumers]: the fully-lowered `text` and
/// whether the widget pass actually placed a `SignalBuilder` wrap anywhere
/// in the file.
///
/// `emittedSignalBuilder` is sourced from [rewriteBuildMethod]'s own
/// `emittedWrap` flag — never re-derived by scanning `text` for the
/// substring `SignalBuilder(`, which would misfire on a source comment or
/// string literal that happens to contain that text. `builder.dart` uses
/// this flag to decide whether the `flutter_solidart` import needs
/// splicing in (or repairing) — see `_ensureSignalBuilderResolves`.
typedef PureConsumerLowering = ({String text, bool emittedSignalBuilder});

/// Lowers BOTH pure-consumer shapes — a plain-class consumer (issue #106)
/// and a `StatelessWidget`/`State<X>` consumer (issue #106 residual gap
/// survey, GAP 1) — in a single text transformation.
///
/// [classRegistry]/[classCollectionFields] already contain the cross-file
/// entries `builder.dart::_populateCrossFileTypes` seeds by the time this
/// runs.
///
/// STRUCTURAL NOTE (why this is one function, not two run in sequence):
/// an earlier version ran [collectPureConsumerWidgetEdits] first against
/// [text] and [unit], applied its edits to produce a new string, then ran
/// [collectPureConsumerCrossFileEdits] against THAT string — forcing it
/// onto a fresh, UNRESOLVED re-parse (`unit: null`) whenever the widget
/// pass had made any change at all. That silently degraded any tier-1-ONLY
/// read (a static-holder receiver like `Holder.instance.session`, a for-in
/// loop variable, `.first`) belonging to a DIFFERENT class in the same
/// file: such reads need `Expression.staticType` from a genuinely resolved
/// unit, which the AST-only fallback tiers of an unresolved re-parse cannot
/// supply — the read stayed un-lowered with no error, exactly the shape of
/// the original #106 bug, just reproduced whenever a file happened to ALSO
/// contain a widget pure consumer.
///
/// The fix is to never let either pass observe a text mutation from the
/// other before deciding what to rewrite: both [collectPureConsumerWidgetEdits]
/// and [collectPureConsumerCrossFileEdits] collect their edits against the
/// SAME pristine [text] and the SAME resolved [unit], and this function
/// merges the two edit lists and applies them together in one
/// [applyEditsToRange] call. This is safe because the two passes visit
/// disjoint class-kind sets — [ClassKind.plainClass] vs
/// [ClassKind.statelessWidget]/[ClassKind.stateClass] — so their edit
/// ranges can never overlap; there is no ordering dependency left to get
/// wrong.
///
/// Returns `text` unchanged (by reference) when neither pass has anything
/// to rewrite — callers rely on that identity to skip re-formatting an
/// untouched file.
PureConsumerLowering lowerPureConsumers(
  String text,
  CompilationUnit unit, {
  required Map<String, Set<String>> classRegistry,
  required Map<String, Set<String>> classCollectionFields,
  Map<String, Map<String, Set<String>>> classRegistryOrigins = const {},
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins = const {},
  Set<String> classRegistryShadowedNames = const {},
}) {
  final widgetResult = collectPureConsumerWidgetEdits(
    unit,
    text,
    classRegistry: classRegistry,
    classCollectionFields: classCollectionFields,
    classRegistryOrigins: classRegistryOrigins,
    classCollectionFieldsOrigins: classCollectionFieldsOrigins,
    classRegistryShadowedNames: classRegistryShadowedNames,
  );
  final crossFileEdits = collectPureConsumerCrossFileEdits(
    unit,
    text,
    classRegistry: classRegistry,
    classCollectionFields: classCollectionFields,
    classRegistryOrigins: classRegistryOrigins,
    classCollectionFieldsOrigins: classCollectionFieldsOrigins,
    classRegistryShadowedNames: classRegistryShadowedNames,
  );
  if (widgetResult.edits.isEmpty && crossFileEdits.isEmpty) {
    return (text: text, emittedSignalBuilder: false);
  }
  final mergedEdits = <ValueEdit>[...widgetResult.edits, ...crossFileEdits];
  final rewritten = applyEditsToRange(text, mergedEdits, 0);
  return (
    text: rewritten,
    emittedSignalBuilder: widgetResult.emittedSignalBuilder,
  );
}

/// Collects `.value`-lowering edits for a PURE CONSUMER plain class — one
/// that reaches a cross-file `@SolidState`-bearing class only through
/// constructor injection or a plain instance field, while declaring NO
/// `@Solid*` annotation of its own (issue #106).
///
/// Such a class never reaches `rewritePlainClass` / `rewriteStateClass` /
/// `rewriteStatelessWidget` — those only run for a class with at least one
/// reactive member of its OWN, because they unconditionally add `implements
/// Disposable` and synthesize a `dispose()`, which would be wrong here: a
/// pure consumer owns no reactive member and disposes nothing of its own.
/// Instead, this applies the exact same name-based `.value` rewrite
/// `rewriteUserMethod` applies to a NON-annotated member of an
/// already-annotated class — using an EMPTY same-class reactive-name set
/// (there is none) and [classRegistry] (already merged with the cross-file
/// entries `builder.dart::_populateCrossFileTypes` seeds) for the
/// cross-class branch.
///
/// Scope, matched to parity with the annotated-class pipeline:
///  * Only [ClassKind.plainClass] declarations are visited here. A
///    pure-consumer `StatelessWidget`/`State<X>` whose `build()` reads a
///    cross-file signal needs a `SignalBuilder` wrap around the tracked
///    subtree to rebuild reactively, not just a bare `.value` read with no
///    subscription (which would look fixed while staying silently
///    non-reactive) — see [collectPureConsumerWidgetEdits] for that shape
///    (issue #106 residual gap survey, GAP 1).
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
/// Returns an empty edit list when [classRegistry] AND
/// [classRegistryShadowedNames] are both empty (issue #110 — a name flagged
/// as ambiguous is stripped from [classRegistry] but still needs a visit:
/// see `builder.dart::_populateCrossFileTypes`'s finalize pass) or no
/// visited member contains a rewrite.
List<ValueEdit> collectPureConsumerCrossFileEdits(
  CompilationUnit unit,
  String text, {
  required Map<String, Set<String>> classRegistry,
  required Map<String, Set<String>> classCollectionFields,
  Map<String, Map<String, Set<String>>> classRegistryOrigins = const {},
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins = const {},
  Set<String> classRegistryShadowedNames = const {},
}) {
  if (classRegistry.isEmpty && classRegistryShadowedNames.isEmpty) {
    return const <ValueEdit>[];
  }
  final edits = <ValueEdit>[];
  for (final decl in unit.declarations) {
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
        classRegistryOrigins: classRegistryOrigins,
        classCollectionFieldsOrigins: classCollectionFieldsOrigins,
        classRegistryShadowedNames: classRegistryShadowedNames,
      );
      edits.addAll(result.edits);
    }
  }
  return edits;
}

/// Collects `.value`-lowering edits AND `SignalBuilder`-wrap placement for a
/// PURE CONSUMER `StatelessWidget`/`State<X>` class — the widget-class
/// sibling of [collectPureConsumerCrossFileEdits] (issue #106 residual gap
/// survey, GAP 1).
///
/// A pure-consumer widget's `build()` needs BOTH the `.value` lowering AND
/// reactive rebuild, exactly like an `@SolidEnvironment`-consuming widget's
/// `build()` — but with none of the state-ownership machinery: the injected
/// dependency arrives through plain constructor injection (a field, not
/// `context.read<T>()`), so no `BuildContext` is needed and no
/// `StatelessWidget`→`StatefulWidget` split is required. The exact same
/// `rewriteBuildMethod` used by `stateless_rewriter.dart` /
/// `state_class_rewriter.dart` for an ANNOTATED widget's `build()` is reused
/// verbatim here — it already resolves `.value` lowering, tracked-read
/// collection, and `SignalBuilder` wrap placement (SPEC §7) from a bare
/// [MethodDeclaration] plus a `classRegistry`, with no dependency on the
/// class owning any reactive member of its own.
///
/// Scope, matched to parity with [collectPureConsumerCrossFileEdits]:
///  * Only [ClassKind.statelessWidget] and [ClassKind.stateClass]
///    declarations are visited — a bare [ClassKind.statefulWidget] shell has
///    no `build()` of its own (that lives on its `State<X>` sibling), and
///    [ClassKind.plainClass] is the sibling function's scope.
///  * The `build()` method is rewritten through [rewriteBuildMethod] (which
///    internally applies the wrap-placement rules and reports whether it
///    placed one via its `emittedWrap` flag); every other constructor /
///    method is rewritten through the same per-identifier [collectValueEdits]
///    path [collectPureConsumerCrossFileEdits] uses, since only `build()`'s
///    return value is a widget subtree that can host a `SignalBuilder`.
///  * `reactiveFields`/`environmentFields`/`widgetBoundFields` are all empty
///    — a pure consumer owns no reactive member of its own, no
///    `@SolidEnvironment` field, and (unlike the Stateless→Stateful LIFT
///    rewriters) never moves its body to a different class scope, so no
///    `widget.`-prefixing is needed.
///
/// Returns `(edits: const [], emittedSignalBuilder: false)` when
/// [classRegistry] AND [classRegistryShadowedNames] are both empty (issue
/// #110 — see [collectPureConsumerCrossFileEdits]'s doc comment) or no
/// visited member contains a rewrite.
({List<ValueEdit> edits, bool emittedSignalBuilder})
collectPureConsumerWidgetEdits(
  CompilationUnit unit,
  String text, {
  required Map<String, Set<String>> classRegistry,
  required Map<String, Set<String>> classCollectionFields,
  Map<String, Map<String, Set<String>>> classRegistryOrigins = const {},
  Map<String, Map<String, Set<String>>> classCollectionFieldsOrigins = const {},
  Set<String> classRegistryShadowedNames = const {},
}) {
  if (classRegistry.isEmpty && classRegistryShadowedNames.isEmpty) {
    return (edits: const <ValueEdit>[], emittedSignalBuilder: false);
  }
  final edits = <ValueEdit>[];
  var emittedSignalBuilder = false;
  for (final decl in unit.declarations) {
    if (decl is! ClassDeclaration) continue;
    final kind = classKindOf(decl);
    if (kind != ClassKind.statelessWidget && kind != ClassKind.stateClass) {
      continue;
    }
    for (final member in decl.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'build') {
        final original = text.substring(member.offset, member.end);
        final rewritten = rewriteBuildMethod(
          member,
          const <String>{},
          text,
          classRegistry: classRegistry,
          classCollectionFields: classCollectionFields,
          classRegistryOrigins: classRegistryOrigins,
          classCollectionFieldsOrigins: classCollectionFieldsOrigins,
          classRegistryShadowedNames: classRegistryShadowedNames,
        );
        if (rewritten.emittedWrap) emittedSignalBuilder = true;
        if (rewritten.text != original) {
          edits.add(ValueEdit(member.offset, member.end, rewritten.text));
        }
        continue;
      }
      if (member is ConstructorDeclaration) {
        if (member.factoryKeyword != null) continue;
        final result = collectValueEdits(
          member,
          const <String>{},
          text,
          classRegistry: classRegistry,
          classCollectionFields: classCollectionFields,
          classRegistryOrigins: classRegistryOrigins,
          classCollectionFieldsOrigins: classCollectionFieldsOrigins,
          classRegistryShadowedNames: classRegistryShadowedNames,
        );
        edits.addAll(result.edits);
        continue;
      }
      if (member is! MethodDeclaration) continue;
      final result = collectValueEdits(
        member,
        const <String>{},
        text,
        classRegistry: classRegistry,
        classCollectionFields: classCollectionFields,
        classRegistryOrigins: classRegistryOrigins,
        classCollectionFieldsOrigins: classCollectionFieldsOrigins,
        classRegistryShadowedNames: classRegistryShadowedNames,
      );
      edits.addAll(result.edits);
    }
  }
  return (edits: edits, emittedSignalBuilder: emittedSignalBuilder);
}
