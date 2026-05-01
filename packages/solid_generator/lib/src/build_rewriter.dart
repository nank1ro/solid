import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/placement_visitor.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// A single edit to apply to the build-method source text.
///
/// Edits are offset-based (relative to the full file source) and applied
/// in reverse-offset order by [rewriteBuildMethod] so earlier offsets stay
/// stable. An [end] equal to [offset] denotes a pure insertion (e.g. the
/// `.value` append for a reactive read).
class SourceEdit {
  /// Creates an edit that replaces `[offset, end)` with [replacement].
  const SourceEdit(this.offset, this.end, this.replacement);

  /// Inclusive start offset in the source string.
  final int offset;

  /// Exclusive end offset in the source string. Equal to [offset] for an
  /// insertion.
  final int end;

  /// Replacement text to splice in for the range `[offset, end)`.
  final String replacement;
}

/// Rewrites the `build()` method source text by applying SPEC M1 rules.
///
/// The rewrite comprises four passes composed in the order they are visible
/// in the returned string:
///
///   1. SPEC Section 5.1 — bare `SimpleIdentifier` reads of a reactive field
///      receive `.value`.
///   2. SPEC Section 5.2 — `$name` interpolation shorthand for a reactive
///      field expands to `${name.value}`.
///   3. SPEC Section 5.3 — assignment / compound / `++` / `--` writes
///      receive `.value` (single textual occurrence per SPEC rule).
///   4. SPEC Section 7.2 — tracked reads cause their smallest enclosing
///      widget expression to be wrapped in `SignalBuilder`. Untracked-
///      context rules from Section 6.2 / 6.4 suppress tracking.
///
/// [reactiveFields] is the set of field names declared `@SolidState` on the
/// enclosing class. The match is name-based; SPEC 5.4's type-driven rule
/// upgrades to resolved-element analysis at M3-05, at which point the call
/// site swaps to a resolved predicate without restructuring this file.
///
/// [queryNames] is the set of `@SolidQuery` method names declared on the
/// enclosing class (M5-01). Their zero-arg call sites in the build body are
/// recorded as tracked reads for SignalBuilder placement (SPEC §4.8 rule 3)
/// without mutating the call expression itself.
///
/// [classRegistry] is the cross-class reactivity map (class name → reactive
/// field/getter names). Threaded through to the value-rewrite visitor so
/// SPEC §5.1's single-level `<param>.<reactiveField>` cross-class rewrite
/// fires (M6-02). Empty map → no-op for the cross-class branch.
///
/// [environmentFields] is the host class's `@SolidEnvironment` field map
/// (`fieldName -> typeText`). Threaded through to the value-rewrite visitor
/// so SPEC §5.1's M6-04 sibling slice fires for `<envField>.<reactiveField>`
/// shapes when the env field's declared type names a class in
/// [classRegistry]. Empty map → no-op for the env-field branch.
///
/// [source] is the full source text of the input file. The returned string
/// is the rewritten build method (from `@override` through the closing `}`),
/// ready for the caller to embed into the emitted `State` class.
String rewriteBuildMethod(
  MethodDeclaration buildMethod,
  Set<String> reactiveFields,
  String source, {
  Set<String> queryNames = const {},
  Map<String, Set<String>> classRegistry = const {},
  Map<String, String> environmentFields = const {},
}) {
  final methodStart = buildMethod.offset;
  final methodEnd = buildMethod.end;
  final methodText = source.substring(methodStart, methodEnd);

  final valueResult = collectValueEdits(
    buildMethod,
    reactiveFields,
    source,
    queryNames: queryNames,
    classRegistry: classRegistry,
    environmentFields: environmentFields,
  );
  final wrapNodes = computeWrapSet(
    buildMethod,
    valueResult.trackedReadOffsets,
    queryNames: queryNames,
  );

  final edits = <SourceEdit>[];

  // Wrap edits supersede any value edits inside their node's source range
  // because the wrap's replacement string already embeds the rewritten
  // inner text.
  for (final node in wrapNodes) {
    final innerStart = node.offset - methodStart;
    final innerEnd = node.end - methodStart;
    final innerOriginal = methodText.substring(innerStart, innerEnd);
    final innerValueEdits = valueResult.edits
        .where((e) => e.offset >= node.offset && e.end <= node.end)
        .toList();
    final rewrittenInner = applyEditsToRange(
      innerOriginal,
      innerValueEdits,
      node.offset,
    );
    final wrap = _signalBuilderWrap(rewrittenInner);
    edits.add(SourceEdit(innerStart, innerEnd, wrap));
  }

  // Value edits NOT covered by a wrap land as standalone source edits. The
  // `onPressed: () => counter++` case is typical — its `.value` edit lives
  // outside every wrapped subtree.
  for (final edit in valueResult.edits) {
    final inside = wrapNodes.any(
      (n) => edit.offset >= n.offset && edit.end <= n.end,
    );
    if (inside) continue;
    edits.add(
      SourceEdit(
        edit.offset - methodStart,
        edit.end - methodStart,
        edit.replacement,
      ),
    );
  }

  edits.sort((a, b) => b.offset.compareTo(a.offset));
  var result = methodText;
  for (final edit in edits) {
    result =
        result.substring(0, edit.offset) +
        edit.replacement +
        result.substring(edit.end);
  }
  return result;
}

/// Emits the SPEC Section 7 `SignalBuilder` wrapper around [inner] using a
/// block-body `builder:` callback. The `child` parameter of the callback is
/// accepted but not consumed — M1-05 does not pass through a static child.
String _signalBuilderWrap(String inner) {
  return 'SignalBuilder(\n'
      '  builder: (context, child) {\n'
      '    return $inner;\n'
      '  },\n'
      ')';
}
