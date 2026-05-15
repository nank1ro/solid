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

/// Rewrites the `build()` method source text by applying reactive-read rules.
///
/// The rewrite comprises four passes composed in the order they are visible
/// in the returned string:
///
///   1. Bare `SimpleIdentifier` reads of a reactive field receive `.value`.
///   2. `$name` interpolation shorthand for a reactive field expands to
///      `${name.value}`.
///   3. Assignment / compound / `++` / `--` writes receive `.value` (single
///      textual occurrence per rule).
///   4. Tracked reads cause their smallest enclosing widget expression to be
///      wrapped in `SignalBuilder`. Untracked-context rules suppress tracking.
///
/// [reactiveFields] is the set of field names declared `@SolidState` on the
/// enclosing class. Matching is name-based; cross-class receiver resolution
/// uses `staticType` in
/// `value_rewriter._resolveReceiverTypeName` and falls back to AST
/// parameter inspection when the resolver hasn't run.
///
/// [queryNames] is the set of `@SolidQuery` method names declared on the
/// enclosing class. Their zero-arg call sites in the build body are recorded
/// as tracked reads for SignalBuilder placement without mutating the call
/// expression itself.
///
/// [classRegistry] is the cross-class reactivity map (class name → reactive
/// field/getter names). Threaded through to the value-rewrite visitor so the
/// single-level `<param>.<reactiveField>` cross-class rewrite fires. Empty
/// map → no-op for the cross-class branch.
///
/// [environmentFields] is the host class's `@SolidEnvironment` field map
/// (`fieldName -> typeText`). Threaded through to the value-rewrite visitor
/// so the sibling slice fires for `<envField>.<reactiveField>` shapes when
/// the env field's declared type names a class in [classRegistry]. Empty map
/// → no-op for the env-field branch.
///
/// [widgetBoundFields] is the set of widget-bound non-`@SolidState` field
/// names on the enclosing class (only populated by the StatelessWidget→
/// StatefulWidget rewriter). Bare references in `build` are prefixed with
/// `widget.` so the lowered State class resolves them through the widget
/// config object. Empty set → no-op for callers whose `build` body does not
/// change scope (state-class / plain-class).
///
/// [collectionFields] is the subset of [reactiveFields] whose emitted ctor
/// is a collection signal (`ListSignal<T>` / `SetSignal<T>` /
/// `MapSignal<K, V>`). Threaded through to the value-rewrite visitor so
/// chain accesses and bare reads on these fields skip the `.value` append
/// (they resolve through the collection-signal mixin directly). Writes
/// still rewrite to `.value =`.
///
/// [classCollectionFields] is the cross-class collection-field map (class
/// name → collection field names). Mirrors [classRegistry] for the
/// collection-signal slice: `<envField>.<collectionField>` shapes skip
/// `.value` and resolve through the mixin on the receiver chain directly.
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
  Set<String> widgetBoundFields = const {},
  Set<String> collectionFields = const {},
  Map<String, Set<String>> classCollectionFields = const {},
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
    widgetBoundFields: widgetBoundFields,
    collectionFields: collectionFields,
    classCollectionFields: classCollectionFields,
  );
  final wrapNodes = computeWrapSet(
    buildMethod,
    valueResult.trackedReadNamesByOffset,
    queryNames: queryNames,
  );

  final edits = <SourceEdit>[];

  // Process wraps deepest-first so an outer wrap's replacement embeds the
  // already-rewritten inner wraps verbatim — overlapping edits would
  // otherwise corrupt each other when applied to the same source range.
  final orderedWraps = wrapNodes.toList()
    ..sort((a, b) {
      final byOffset = b.offset.compareTo(a.offset);
      if (byOffset != 0) return byOffset;
      return a.end.compareTo(b.end);
    });

  // Wrap tree: each wrap's IMMEDIATE parent (smallest strictly-containing
  // wrap) plus the inverse children map. Value edits pin to the smallest
  // wrap that contains them (or `null` for edits outside every wrap).
  // Together these route every value edit and every nested wrap to exactly
  // one outer wrap's replacement.
  final wrapParent = <Expression, Expression?>{
    for (final wrap in orderedWraps)
      wrap: _smallestContaining(
        orderedWraps,
        wrap.offset,
        wrap.end,
        strict: true,
      ),
  };
  final wrapChildren = <Expression, List<Expression>>{};
  for (final entry in wrapParent.entries) {
    final parent = entry.value;
    if (parent == null) continue;
    wrapChildren.putIfAbsent(parent, () => []).add(entry.key);
  }
  final valueEditOwner = <ValueEdit, Expression?>{
    for (final e in valueResult.edits)
      e: _smallestContaining(orderedWraps, e.offset, e.end),
  };

  final wrapReplacements = <Expression, String>{};
  for (final node in orderedWraps) {
    final innerStart = node.offset - methodStart;
    final innerEnd = node.end - methodStart;
    final innerOriginal = methodText.substring(innerStart, innerEnd);
    final innerEdits = <ValueEdit>[
      for (final e in valueResult.edits)
        if (identical(valueEditOwner[e], node)) e,
      for (final child in wrapChildren[node] ?? const <Expression>[])
        ValueEdit(child.offset, child.end, wrapReplacements[child]!),
    ];
    final rewrittenInner = applyEditsToRange(
      innerOriginal,
      innerEdits,
      node.offset,
    );
    wrapReplacements[node] = _signalBuilderWrap(rewrittenInner);
  }

  // Only emit edits for OUTERMOST wraps; inner wraps are already inlined
  // into their containing outer wrap's replacement above.
  for (final node in orderedWraps) {
    if (wrapParent[node] != null) continue;
    edits.add(
      SourceEdit(
        node.offset - methodStart,
        node.end - methodStart,
        wrapReplacements[node]!,
      ),
    );
  }

  // Value edits NOT owned by any wrap land as standalone source edits. The
  // `onPressed: () => counter++` case is typical — its `.value` edit lives
  // outside every wrapped subtree.
  for (final edit in valueResult.edits) {
    if (valueEditOwner[edit] != null) continue;
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

/// Emits the `SignalBuilder` wrapper around [inner] using a block-body
/// `builder:` callback. The `child` parameter of the callback is accepted
/// but not consumed — the rewriter does not pass through a static child.
String _signalBuilderWrap(String inner) {
  return 'SignalBuilder(\n'
      '  builder: (context, child) {\n'
      '    return $inner;\n'
      '  },\n'
      ')';
}

/// Smallest wrap in [wraps] whose source range contains `[offset, end)`,
/// or `null` if none does. When [strict] is true, exact-range matches
/// (offset and end both equal) are excluded — used by the parent-of-wrap
/// pass so a wrap cannot be its own parent.
Expression? _smallestContaining(
  List<Expression> wraps,
  int offset,
  int end, {
  bool strict = false,
}) {
  Expression? smallest;
  for (final w in wraps) {
    if (w.offset > offset || end > w.end) continue;
    if (strict && w.offset == offset && w.end == end) continue;
    if (smallest == null ||
        w.offset > smallest.offset ||
        w.end < smallest.end) {
      smallest = w;
    }
  }
  return smallest;
}
