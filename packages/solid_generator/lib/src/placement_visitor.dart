import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Computes the set of widget expressions that must be wrapped in
/// `SignalBuilder` for SPEC Section 7 placement.
///
/// Algorithm:
///
/// 1. DFS the `build` method body, collecting every **widget-constructor
///    expression** in post-order so deepest-first ordering is natural. A
///    widget-constructor expression is either an `InstanceCreationExpression`
///    (explicit `const`/`new` form) or a `MethodInvocation` whose callee is
///    an UpperCamelCase identifier (the `Text(...)` style used without
///    `const` or `new`; the analyzer only upgrades these to
///    `InstanceCreationExpression` during resolution, which we defer to
///    M3-05 per SPEC 5.4). Constructor expressions used as the value of a
///    `key:` named argument are filtered out — Keys are not Widgets and
///    cannot host a `SignalBuilder` wrapper (see `_isAtKeyPosition`).
/// 2. For each tracked-read offset T (from `value_rewriter`), pick the
///    smallest (deepest) widget expression whose source range contains T —
///    SPEC Section 7.2's minimum-subtree rule.
/// 3. Prune ancestors: if both an outer and inner widget appear in the
///    wrap set, drop the outer (SPEC Section 7.5 nested-reads rule).
/// 4. Suppress any wrap whose ancestor chain already contains a
///    hand-written `SignalBuilder` (SPEC Section 7.3).
Set<Expression> computeWrapSet(
  MethodDeclaration buildMethod,
  List<int> trackedReadOffsets,
) {
  if (trackedReadOffsets.isEmpty) return <Expression>{};

  final collector = _WidgetCollector();
  buildMethod.accept(collector);
  final widgets = collector.widgets;
  if (widgets.isEmpty) return <Expression>{};

  final wrapSet = <Expression>{};
  for (final offset in trackedReadOffsets) {
    Expression? smallest;
    for (final w in widgets) {
      if (w.offset <= offset && offset < w.end) {
        if (smallest == null || w.offset > smallest.offset) smallest = w;
      }
    }
    if (smallest != null) wrapSet.add(smallest);
  }

  _pruneAncestors(wrapSet);
  _suppressAlreadyWrapped(wrapSet);
  return wrapSet;
}

/// Removes any entry from [wrapSet] that strictly contains another entry
/// (SPEC Section 7.5). After this call, no two entries are in an
/// ancestor / descendant relationship.
void _pruneAncestors(Set<Expression> wrapSet) {
  final toRemove = <Expression>{};
  for (final outer in wrapSet) {
    for (final inner in wrapSet) {
      if (identical(outer, inner)) continue;
      if (outer.offset <= inner.offset && inner.end <= outer.end) {
        toRemove.add(outer);
        break;
      }
    }
  }
  wrapSet.removeAll(toRemove);
}

/// Drops any entry whose ancestor chain already contains a hand-written
/// `SignalBuilder` (SPEC Section 7.3). Checks both `InstanceCreationExpression`
/// and `MethodInvocation` forms because pre-resolution Dart AST may parse
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

class _WidgetCollector extends RecursiveAstVisitor<void> {
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
    if (!_looksLikeWidgetCtor(node) || _isAtKeyPosition(node)) return;
    widgets.add(node);
  }
}

/// Syntactic heuristic: a bare `Foo(...)` call with no target and an
/// UpperCamelCase method name is almost certainly a widget constructor in
/// pre-resolution Dart AST. Named constructors on classes (`Foo.named(...)`)
/// and library-prefixed calls are left for M3-05's type-resolved pivot.
bool _looksLikeWidgetCtor(MethodInvocation node) {
  if (node.target != null) return false;
  final name = node.methodName.name;
  if (name.isEmpty) return false;
  final first = name.codeUnitAt(0);
  return first >= 0x41 && first <= 0x5A; // 'A'..'Z'
}

/// Syntactic stand-in for "this expression's static type is `Widget`": skips
/// constructor calls that sit at `key:` argument position, since `Key` is not
/// a `Widget` and cannot host a `SignalBuilder` wrap. The general non-Widget-
/// argument case (e.g. `EdgeInsets`) waits for the type-driven pivot in M3-05.
bool _isAtKeyPosition(Expression expr) {
  final parent = expr.parent;
  return parent is NamedExpression && parent.name.label.name == 'key';
}
