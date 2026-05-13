import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// Returns [text] with `const ` prepended to every constructor invocation
/// whose constructor name is in [constCtorNames] and whose arguments are all
/// statically const-evaluable.
///
/// A sibling pass adds `const` to the constructor *declaration* of an eligible
/// lowered widget. This pass closes the gap on the call site —
/// `runApp(CounterDisplay())` becomes `runApp(const CounterDisplay())` so the
/// analyzer's `prefer_const_constructors` lint stays silent without requiring
/// the user to run `dart fix --apply` after every build.
///
/// [constCtorNames] is the union of two sources:
/// 1. Names emitted with `const ` on their *declaration* by the per-class
///    rewriters (`_emitCtors` in `stateless_rewriter.dart`).
/// 2. Names harvested from the resolved source AST via
///    [collectResolvedConstCtorNames] — every constructor invocation in
///    source whose resolved `ConstructorElement.isConst == true` qualifies.
///    This is what extends promotion to Flutter widgets (`MaterialApp`),
///    cross-file Solid widgets (`CounterPage` from `counter.dart`), and any
///    third-party class with a `const` constructor.
///
/// The pass parses [text] without resolution (the assembled output's offsets
/// differ from the source after lowering, so the resolved AST cannot drive
/// the visitor's edit positions). A bare constructor call like `Foo()`
/// (no `const` / `new` keyword) appears in the unresolved AST as
/// `MethodInvocation`, not `InstanceCreationExpression`. Both forms are
/// handled — the visitor walks each, computes the full constructor name as
/// `"$Type"` (unnamed) or `"$Type.$name"` (named), and matches against
/// [constCtorNames].
///
/// `const` is added only at the OUTERMOST const-eligible position in any
/// expression tree. Once the outer call becomes a const constructor
/// invocation, Dart's const-context elision makes the explicit `const`
/// redundant on every nested const-eligible call (and would trip
/// `unnecessary_const`). The visitor implements this by short-circuiting
/// the recursion at every promoted node — children are not visited, so they
/// cannot accumulate their own `const` insertions.
///
/// Argument const-evaluability is conservative — accepts only literal forms,
/// `AdjacentStrings` of simple-string parts, already-`const`
/// `InstanceCreationExpression`s, and constructor-call sites whose class is
/// in [constCtorNames] (i.e., would *also* be made const by this pass).
/// Identifier reads, method invocations of non-class names, operators,
/// string interpolations, list/map/set literals, and explicitly-`new`
/// expressions are rejected. This is the smallest rule that lints clean for
/// the multi-constructor case (`Counter(title: 'count=$value')` — rejected
/// because of string interpolation) and the const-call-site cases
/// (`CounterDisplay()` / `Outer(child: Inner())` / `MaterialApp(home: …)` —
/// accepted) without resolving offsets in the assembled output.
/// Identifier-RHS and list/map literal const-evaluability are tractable
/// future extensions.
String addConstAtCallSites(String text, Set<String> constCtorNames) {
  if (constCtorNames.isEmpty) return text;

  final parsed = parseString(
    content: text,
    featureSet: FeatureSet.latestLanguageVersion(),
    throwIfDiagnostics: false,
  );
  final visitor = _ConstCallSiteVisitor(constCtorNames);
  parsed.unit.accept(visitor);
  if (visitor.insertOffsets.isEmpty) return text;

  final edits = [
    for (final offset in visitor.insertOffsets)
      ValueEdit(offset, offset, 'const '),
  ];
  return applyEditsToRange(text, edits, 0);
}

/// Walks [resolvedUnit] and returns the names of every constructor whose
/// resolved `ConstructorElement` is `const`. Names are formatted to match
/// the `ConstructorName.toString()` shape consumed by [addConstAtCallSites]:
/// `"$Type"` for an unnamed ctor (`MaterialApp`), `"$Type.$name"` for a named
/// ctor (`Duration.zero`).
///
/// Resolved analysis is needed because the unresolved parse cannot tell
/// `Foo()` (a method call) from `Foo()` (an unnamed-ctor invocation); only
/// the analyzer's `ConstructorName.element` distinguishes them. The
/// collected set is unioned with the per-file declaration-emitted names by
/// the builder before [addConstAtCallSites] runs.
///
/// Returns names visible by being USED in [resolvedUnit] (every
/// `InstanceCreationExpression` is visited). This is enough for the
/// post-emit text scan: any name the visitor will need to match is one the
/// source already mentions.
Set<String> collectResolvedConstCtorNames(CompilationUnit resolvedUnit) {
  final names = <String>{};
  resolvedUnit.accept(_ConstCtorNameCollector(names));
  return names;
}

class _ConstCtorNameCollector extends RecursiveAstVisitor<void> {
  _ConstCtorNameCollector(this._names);

  final Set<String> _names;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    if (element != null && element.isConst) {
      _names.add(node.constructorName.toString());
    }
    super.visitInstanceCreationExpression(node);
  }
}

class _ConstCallSiteVisitor extends RecursiveAstVisitor<void> {
  _ConstCallSiteVisitor(this._constCtorNames);

  final Set<String> _constCtorNames;
  final List<int> insertOffsets = [];

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final keyword = node.keyword?.lexeme;
    // Already-`const`: the whole subtree is in a const context per Dart's
    // const-context elision, so any explicit `const` we add to a nested
    // eligible ctor would trip `unnecessary_const`. Short-circuit the
    // recursion. (When a *promoted* outer would-be const reaches the same
    // state below — `insertOffsets.add(...); return;` — we similarly skip
    // recursion for the same reason.)
    if (keyword == 'const') return;
    // Explicit-`new`: the user wants this allocation non-const, but nested
    // expressions are still in their own contexts. Recurse normally so
    // eligible inner ctors are still promoted.
    if (keyword == 'new') {
      super.visitInstanceCreationExpression(node);
      return;
    }
    final fullName = node.constructorName.toString();
    if (_constCtorNames.contains(fullName) &&
        _argsAreConstEvaluable(node.argumentList)) {
      insertOffsets.add(node.offset);
      return;
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final fullName = _ctorNameFromMethodInvocation(node);
    if (fullName != null &&
        _constCtorNames.contains(fullName) &&
        _argsAreConstEvaluable(node.argumentList)) {
      insertOffsets.add(node.offset);
      return;
    }
    super.visitMethodInvocation(node);
  }

  /// Computes the constructor-name string for a [MethodInvocation] that
  /// could be a bare (unresolved) constructor call. Returns null when the
  /// shape is incompatible with a constructor invocation — typically a
  /// non-`SimpleIdentifier` target (e.g., a chained property access or
  /// another invocation).
  String? _ctorNameFromMethodInvocation(MethodInvocation node) {
    final target = node.target;
    if (target == null) return node.methodName.name;
    if (target is SimpleIdentifier) {
      return '${target.name}.${node.methodName.name}';
    }
    return null;
  }

  bool _argsAreConstEvaluable(ArgumentList args) {
    for (final arg in args.arguments) {
      final inner = arg is NamedExpression ? arg.expression : arg;
      if (!_isConstEvaluable(inner)) return false;
    }
    return true;
  }

  bool _isConstEvaluable(Expression expr) {
    if (expr is BooleanLiteral ||
        expr is DoubleLiteral ||
        expr is IntegerLiteral ||
        expr is NullLiteral ||
        expr is SimpleStringLiteral ||
        expr is SymbolLiteral) {
      return true;
    }
    // AdjacentStrings (`'foo' 'bar'`) is const-evaluable iff every part is a
    // SimpleStringLiteral. StringInterpolation parts disqualify because
    // interpolation itself is not const in Dart, even when every expression
    // inside is.
    if (expr is AdjacentStrings) {
      for (final part in expr.strings) {
        if (part is! SimpleStringLiteral) return false;
      }
      return true;
    }
    if (expr is InstanceCreationExpression) {
      final keyword = expr.keyword?.lexeme;
      if (keyword == 'const') return true;
      // `new Foo(42)` is explicitly non-const — rejecting here keeps
      // `_isConstEvaluable` symmetric with `visitInstanceCreationExpression`,
      // so an outer site never gets promoted on the strength of a `new` arg.
      if (keyword == 'new') return false;
      if (!_constCtorNames.contains(expr.constructorName.toString())) {
        return false;
      }
      return _argsAreConstEvaluable(expr.argumentList);
    }
    if (expr is MethodInvocation) {
      final fullName = _ctorNameFromMethodInvocation(expr);
      if (fullName == null) return false;
      if (!_constCtorNames.contains(fullName)) return false;
      return _argsAreConstEvaluable(expr.argumentList);
    }
    return false;
  }
}
