import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:meta/meta.dart';
import 'package:solid_generator/src/element_utils.dart';

/// Per-build wrap plan: the set of widget expressions that get an inner
/// `SignalBuilder` wrap, plus the offsets of any tracked reads that have
/// no enclosing widget candidate (the **unanchored** offsets). The
/// `build_rewriter` consumes both — anchored wraps are emitted in-place,
/// and a non-empty `unanchoredOffsets` triggers an outer SignalBuilder
/// around the whole build method body so top-level statement reads (e.g.
/// `final c = nav.currentChannel; …`) drive reactivity instead of being
/// silently dropped.
typedef WrapPlan = ({Set<Expression> wraps, List<int> unanchoredOffsets});

/// Computes the [WrapPlan] for a `build` method.
///
/// Algorithm:
///
/// 1. DFS the `build` method body, collecting every **widget-constructor
///    expression** in post-order so deepest-first ordering is natural. A
///    widget-constructor expression is either an `InstanceCreationExpression`
///    (explicit `const`/`new` form) or a `MethodInvocation` whose callee is
///    an UpperCamelCase identifier (the `Text(...)` style used without
///    `const` or `new`; the analyzer only upgrades these to
///    `InstanceCreationExpression` during resolution, which we defer). The
///    collector also recognizes the query-state chain
///    `<queryName>().when(...)` and `<queryName>().maybeWhen(...)` — the
///    `FutureWhen` / `StreamWhen` extensions on `Future<T>` / `Stream<T>`
///    from `solid_annotations` return `Widget`, so the entire chain is a
///    valid SignalBuilder wrap target even though its callee is the lowercase
///    `when` / `maybeWhen`. Constructor expressions used as the value of a
///    `key:` named argument are filtered out — Keys are not Widgets and
///    cannot host a `SignalBuilder` wrapper (see `_isAtKeyPosition`).
/// 2. For each tracked-read offset T (from `value_rewriter`), pick the
///    smallest (deepest) widget expression whose source range contains T —
///    the minimum-subtree rule. If no widget contains T, record T in
///    `unanchoredOffsets` so the caller can emit an outer body wrap.
/// 3. Prune ancestors: if both an outer and inner widget appear in the
///    wrap set, drop the outer (nested-reads rule).
/// 4. Suppress any wrap whose ancestor chain already contains a
///    hand-written `SignalBuilder`.
///
/// [queryNames] is the per-class set of `@SolidQuery` method names. It is
/// consulted only to recognize the `<queryName>().when(...)` /
/// `<queryName>().maybeWhen(...)` widget-shape; the recorded tracked-read
/// offsets themselves come from `value_rewriter`.
WrapPlan computeWrapPlan(
  MethodDeclaration buildMethod,
  Map<int, String> trackedReadNamesByOffset, {
  Set<String> queryNames = const {},
}) {
  if (trackedReadNamesByOffset.isEmpty) {
    return (wraps: <Expression>{}, unanchoredOffsets: const <int>[]);
  }

  final collector = _WidgetCollector(queryNames);
  buildMethod.accept(collector);
  final widgets = collector.widgets;

  // Per-wrap name-set drives the prune rule below: collapse nested wraps
  // whose underlying signal/query reads all read names the outer wrap
  // already subscribes to.
  final wrapNames = <Expression, Set<String>>{};
  final unanchoredOffsets = <int>[];
  for (final entry in trackedReadNamesByOffset.entries) {
    final offset = entry.key;
    Expression? smallest;
    for (final w in widgets) {
      if (w.offset <= offset && offset < w.end) {
        if (smallest == null || w.offset > smallest.offset) smallest = w;
      }
    }
    if (smallest != null) {
      wrapNames.putIfAbsent(smallest, () => <String>{}).add(entry.value);
    } else {
      // No enclosing widget candidate — this is a top-level read at the
      // build-method's statement scope (e.g. `final c = sig; if (c == null)
      // return …`). `rewriteBuildMethod` synthesizes an outer SignalBuilder
      // around the whole body so the read fires inside the tracking
      // window. The `_WidgetCollector` filter (B-2 strict) keeps non-Widget
      // method-invocation candidates from being picked here.
      unanchoredOffsets.add(offset);
    }
  }

  final wrapSet = wrapNames.keys.toSet();
  _pruneAncestors(wrapSet, wrapNames);
  _suppressAlreadyWrapped(wrapSet);
  // When the build method has unanchored reads, the synthesized outer body
  // wrap (added by `build_rewriter._synthesizeOuterWrap`) covers every
  // inner widget. Any anchored inner wrap whose name-set is a subset of
  // the unanchored-read names sits inside the outer wrap's tracking
  // window and would double-subscribe — same rule as the strict-contains
  // nested-reads case in `_pruneAncestors`, applied against the virtual
  // outer wrap.
  if (unanchoredOffsets.isNotEmpty) {
    final unanchoredNames = <String>{
      for (final offset in unanchoredOffsets) trackedReadNamesByOffset[offset]!,
    };
    final toRemove = <Expression>{};
    for (final inner in wrapSet) {
      final innerNames = wrapNames[inner] ?? const <String>{};
      if (innerNames.isEmpty) continue;
      if (unanchoredNames.containsAll(innerNames)) toRemove.add(inner);
    }
    wrapSet.removeAll(toRemove);
  }
  return (wraps: wrapSet, unanchoredOffsets: unanchoredOffsets);
}

/// Drops an inner wrap when the strictly-containing outer wrap's name-set
/// already covers every signal/query the inner subscribes to. The outer
/// `SignalBuilder.builder` runs synchronously through the subtree it
/// returns, so same-name reads in the inner widget become dependencies of
/// the outer wrap too. Different-signal nesting (outer reads `sigA`, inner
/// reads `sigB`) keeps both wraps; the superset check fails and the
/// inner's reactivity is preserved.
void _pruneAncestors(
  Set<Expression> wrapSet,
  Map<Expression, Set<String>> wrapNames,
) {
  final toRemove = <Expression>{};
  for (final outer in wrapSet) {
    final outerNames = wrapNames[outer] ?? const <String>{};
    for (final inner in wrapSet) {
      if (identical(outer, inner)) continue;
      if (outer.offset > inner.offset || inner.end > outer.end) continue;
      final innerNames = wrapNames[inner] ?? const <String>{};
      // No recorded names on the inner means we can't prove the outer's
      // dependencies cover the inner's reactivity — keep both wraps.
      if (innerNames.isEmpty) continue;
      if (outerNames.containsAll(innerNames)) {
        toRemove.add(inner);
      }
    }
  }
  wrapSet.removeAll(toRemove);
}

/// Drops any entry whose ancestor chain already contains a hand-written
/// `SignalBuilder`. Checks both `InstanceCreationExpression` and
/// `MethodInvocation` forms because pre-resolution Dart AST may parse
/// `SignalBuilder(...)` without an explicit `const` as a `MethodInvocation`.
void _suppressAlreadyWrapped(Set<Expression> wrapSet) {
  final toRemove = <Expression>{};
  for (final node in wrapSet) {
    var ancestor = node.parent;
    while (ancestor != null) {
      if (_isSignalBuilder(ancestor)) {
        toRemove.add(node);
        break;
      }
      ancestor = ancestor.parent;
    }
  }
  wrapSet.removeAll(toRemove);
}

bool _isSignalBuilder(AstNode node) {
  if (node is InstanceCreationExpression) {
    return node.constructorName.type.name.lexeme == 'SignalBuilder';
  }
  if (node is MethodInvocation) {
    return node.target == null && node.methodName.name == 'SignalBuilder';
  }
  return false;
}

/// Query-state extension methods — both `<query>().when(...)` and
/// `<query>().maybeWhen(...)` resolve to `Widget`-returning extensions, so
/// either is a valid SignalBuilder wrap target.
const Set<String> _queryStateChainMethods = {'when', 'maybeWhen'};

class _WidgetCollector extends RecursiveAstVisitor<void> {
  _WidgetCollector(this._queryNames);

  /// Per-class set of `@SolidQuery` method names — consumed by
  /// [_isQueryStateChain] to recognize `<query>().when(...)` /
  /// `<query>().maybeWhen(...)` chains as widget expressions. Empty when the
  /// enclosing class has no `@SolidQuery` methods.
  final Set<String> _queryNames;

  final List<Expression> widgets = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    // Post-order: descend first so deeper widgets are appended first.
    super.visitInstanceCreationExpression(node);
    if (_isAtKeyPosition(node)) return;
    if (!isWidgetTypedExpression(node)) return;
    widgets.add(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    if (_isAtKeyPosition(node)) return;
    // Resolved-AST fast path: when the resolver gave us a concrete
    // [InterfaceType] for [node], the Element-based widget-ness check is
    // authoritative and the syntactic UpperCamelCase gate becomes
    // redundant. This branch picks up aliased Flutter imports
    // (`m.Text('hi')` whose target lexeme is lowercase) that the syntactic
    // gate would otherwise miss.
    final type = node.staticType;
    if (type is InterfaceType) {
      if (_isWidgetInterfaceType(type)) widgets.add(node);
      return;
    }
    // Unresolved fallback (test sandboxes, parsed-AST fallback). The
    // syntactic gate filters out non-widget MethodInvocations, then the
    // permissive type check allows them through (InvalidType /
    // DynamicType / null all return true here).
    if (_looksLikeWidgetCtor(node) || _isQueryStateChain(node)) {
      // B-2 strict: a chain like `watchFoo().maybeWhen(ready: (v) => v, ...)`
      // looks syntactically like a widget candidate (matches
      // `_isQueryStateChain`), but its `.maybeWhen<R>` extension can return
      // any type. Reject the candidate when the resolved return type is not
      // a Widget — the smallest-widget rule then picks the next larger
      // candidate, or the offset is recorded as unanchored and drives the
      // outer body wrap if no enclosing Widget exists.
      if (!isWidgetTypedExpression(node)) return;
      widgets.add(node);
    }
  }

  /// True if [node] is a query-state chain `<queryName>().when(...)` /
  /// `.maybeWhen(...)`. The query-name guard prevents matches on user-defined
  /// `.when` / `.maybeWhen` methods on non-query targets.
  bool _isQueryStateChain(MethodInvocation node) {
    if (_queryNames.isEmpty) return false;
    if (!_queryStateChainMethods.contains(node.methodName.name)) return false;
    final target = node.target;
    if (target is! MethodInvocation) return false;
    if (target.target != null) return false;
    if (target.argumentList.arguments.isNotEmpty) return false;
    return _queryNames.contains(target.methodName.name);
  }
}

/// Syntactic heuristic: a `Foo(...)` or `Foo.named(...)` call with an
/// UpperCamelCase receiver (class name) is almost certainly a widget
/// constructor in unresolved AST. The bare form covers ordinary
/// widget creation; the named-constructor form covers `ListView.separated`,
/// `ListView.builder`, `GridView.builder`, etc. Library-prefixed calls
/// (`prefix.Foo(...)`) are handled by the resolved-AST fast path in
/// [_WidgetCollector.visitMethodInvocation] above; this textual gate is the
/// unresolved fallback only.
bool _looksLikeWidgetCtor(MethodInvocation node) {
  final target = node.target;
  if (target == null) {
    return _startsUpperCamel(node.methodName.name);
  }
  if (target is! SimpleIdentifier) return false;
  return _startsUpperCamel(target.name);
}

bool _startsUpperCamel(String name) {
  if (name.isEmpty) return false;
  final first = name.codeUnitAt(0);
  return first >= 0x41 && first <= 0x5A; // 'A'..'Z'
}

/// Syntactic stand-in for "this expression's static type is `Widget`": skips
/// constructor calls that sit at `key:` argument position, since `Key` is not
/// a `Widget` and cannot host a `SignalBuilder` wrap.
bool _isAtKeyPosition(Expression expr) {
  final parent = expr.parent;
  return parent is NamedExpression && parent.name.label.name == 'key';
}

/// True iff [expr]'s resolved static type is `Widget` or a subtype. The
/// `null` case (`staticType` not yet populated — the builder fell back to
/// the parsed unit for this file, or a corner the analyzer couldn't
/// resolve) is treated as "allow", since the alternative would be a
/// confusing false rejection on code paths the resolver didn't reach.
///
/// The check walks the type's `allSupertypes` list looking for an interface
/// element named `Widget`. This matches Flutter's `Widget` class regardless
/// of how the file imports it, at the cost of also matching a user-defined
/// class named `Widget` — practically acceptable since user code redefining
/// `Widget` is vanishingly rare.
///
/// Exposed via `@visibleForTesting` so the placement_visitor unit test
/// suite can probe the resolved-type rejection path directly — the
/// `testBuilder` golden harness can't (no Flutter SDK, every Flutter
/// expression resolves to `InvalidType`).
@visibleForTesting
bool isWidgetTypedExpression(Expression expr) {
  final type = expr.staticType;
  // Three "unresolved" cases — fall back to permissive (allow), matching
  // the pre-resolved-AST textual heuristic. The B-2 strict gate only fires
  // when the resolver actually told us a non-Widget type.
  //   * `null`: builder used the parsed fallback for this file (e.g., the
  //     library has no class/enum/extension anchor for `astNodeFor`).
  //   * `InvalidType`: the resolver couldn't resolve (typical in
  //     `testBuilder` sandboxes that don't include the Flutter SDK).
  //   * `DynamicType`: the receiver was `dynamic`.
  if (type == null) return true;
  if (type is InvalidType || type is DynamicType) return true;
  if (type is! InterfaceType) return false;
  return _isWidgetInterfaceType(type);
}

/// Element-based widget-ness check for a resolved [InterfaceType]. Used by
/// the resolved-AST fast path in [_WidgetCollector.visitMethodInvocation]:
/// returns `true` when the type's element or any supertype element is the
/// `Widget` class. Matches Flutter's `Widget` regardless of import alias,
/// at the cost of also matching user-defined `Widget` classes
/// (vanishingly rare).
bool _isWidgetInterfaceType(InterfaceType type) {
  if (type.element.name == 'Widget') return true;
  return supertypeChainContains(type.allSupertypes, 'Widget');
}
