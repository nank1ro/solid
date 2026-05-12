import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Computes the set of widget expressions that must be wrapped in
/// `SignalBuilder`.
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
///    the minimum-subtree rule.
/// 3. Prune ancestors: if both an outer and inner widget appear in the
///    wrap set, drop the outer (nested-reads rule).
/// 4. Suppress any wrap whose ancestor chain already contains a
///    hand-written `SignalBuilder`.
///
/// [queryNames] is the per-class set of `@SolidQuery` method names. It is
/// consulted only to recognize the `<queryName>().when(...)` /
/// `<queryName>().maybeWhen(...)` widget-shape; the recorded tracked-read
/// offsets themselves come from `value_rewriter`.
Set<Expression> computeWrapSet(
  MethodDeclaration buildMethod,
  List<int> trackedReadOffsets, {
  Set<String> queryNames = const {},
}) {
  if (trackedReadOffsets.isEmpty) return <Expression>{};

  final collector = _WidgetCollector(queryNames);
  buildMethod.accept(collector);
  final widgets = collector.widgets;
  if (widgets.isEmpty) return <Expression>{};

  // Per-wrap tracked-offset map drives the safer pruning rule below — an
  // outer wrap is only redundant if every offset that picked it also falls
  // inside some inner wrap's range.
  final wrapOffsets = <Expression, Set<int>>{};
  for (final offset in trackedReadOffsets) {
    Expression? smallest;
    for (final w in widgets) {
      if (w.offset <= offset && offset < w.end) {
        if (smallest == null || w.offset > smallest.offset) smallest = w;
      }
    }
    if (smallest != null) {
      wrapOffsets.putIfAbsent(smallest, () => <int>{}).add(offset);
    }
  }

  final wrapSet = wrapOffsets.keys.toSet();
  _pruneAncestors(wrapSet, wrapOffsets);
  _suppressAlreadyWrapped(wrapSet);
  return wrapSet;
}

/// Drops an outer wrap only when ALL of its tracked-read offsets fall
/// inside the inner wrap's source range — the inner wrap already covers
/// everything the outer would. The naive "always drop the outer when
/// nested" rule was unsafe: e.g. `ListView(itemCount: xs.length, ...)`
/// with an inner `Text` reading `xs[i]` would lose list-length reactivity
/// because the outer's read sits outside the inner's range.
void _pruneAncestors(
  Set<Expression> wrapSet,
  Map<Expression, Set<int>> wrapOffsets,
) {
  final toRemove = <Expression>{};
  for (final outer in wrapSet) {
    final outerOffsets = wrapOffsets[outer] ?? const <int>{};
    if (outerOffsets.isEmpty) continue;
    for (final inner in wrapSet) {
      if (identical(outer, inner)) continue;
      if (outer.offset > inner.offset || inner.end > outer.end) continue;
      final allCovered = outerOffsets.every(
        (o) => inner.offset <= o && o < inner.end,
      );
      if (allCovered) {
        toRemove.add(outer);
        break;
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
    widgets.add(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    super.visitMethodInvocation(node);
    if (_isAtKeyPosition(node)) return;
    if (_looksLikeWidgetCtor(node) || _isQueryStateChain(node)) {
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
/// constructor in pre-resolution Dart AST. The bare form covers ordinary
/// widget creation; the named-constructor form covers `ListView.separated`,
/// `ListView.builder`, `GridView.builder`, etc. Library-prefixed calls
/// (`prefix.Foo(...)`) are left for the future type-resolved pivot.
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
/// a `Widget` and cannot host a `SignalBuilder` wrap. The general non-Widget-
/// argument case (e.g. `EdgeInsets`) waits for the future type-driven pivot.
bool _isAtKeyPosition(Expression expr) {
  final parent = expr.parent;
  return parent is NamedExpression && parent.name.label.name == 'key';
}
