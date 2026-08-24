import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:solid_generator/src/ast_compat.dart';
import 'package:solid_generator/src/element_utils.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// Returns [text] with `dispose: (context, provider) => provider.dispose()`
/// injected into every `Provider(...)`, `Provider<T>(...)`, and
/// `.environment<T>(...)` call site that omits the `dispose:` named argument
/// AND whose created type statically has a `dispose()` method (own
/// declaration or inherited — see [_ProviderDisposeVisitor] for the
/// two-tier check).
///
/// Every Solid-lowered class implements `Disposable` and has a synthesized
/// `dispose()`, so the injected closure resolves at runtime for any annotated
/// reactive class. Non-Solid types whose creator has no `dispose()` method
/// get NOTHING injected — same as an explicit `dispose: null` — rather than
/// an injected closure that crashes at dispose time. A type that DOES have a
/// `dispose()` but must outlive the `Provider` can still opt out via an
/// explicit `dispose: null`.
///
/// `MultiProvider(...)` itself never receives a `dispose:` argument — the
/// visitor descends into its `providers:` list naturally and applies the
/// per-Provider rule to each entry. `Provider.value(...)` is not rewritten:
/// it owns no instance and takes no `dispose:`.
///
/// When [unit] is supplied the function reuses it instead of re-parsing
/// [text] — used by the builder's no-annotation fast path, which already has
/// a parsed `CompilationUnit` in hand.
///
/// Returns [text] (the same `String` object, by reference) when no edits are
/// emitted. Callers can rely on that identity to skip downstream work like
/// re-formatting an unchanged file.
String addProviderDisposeAtCallSites(String text, {CompilationUnit? unit}) {
  final ast =
      unit ??
      parseString(
        content: text,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      ).unit;
  final visitor = _ProviderDisposeVisitor(text, ast);
  ast.accept(visitor);
  if (visitor.edits.isEmpty) return text;
  return applyEditsToRange(text, visitor.edits, 0);
}

/// Base-class / mixin / interface names known to declare a `dispose()`
/// method that the AST-only tier of [_ProviderDisposeVisitor] cannot see the
/// members of (they are declared outside the file being scanned). A small,
/// explicit allowlist rather than full type inference — mirrors the
/// `Disposable`-marker-name convention already used by
/// `plain_class_rewriter.dart`.
const Set<String> _knownDisposableBaseNames = {
  'Disposable', // package:solid_annotations — every Solid-lowered class.
  'ChangeNotifier', // package:flutter/foundation.dart
  'ValueNotifier', // package:flutter/foundation.dart (extends ChangeNotifier)
};

/// Closure spliced before the closing `)` of every matching call site.
const String _disposeArg = 'dispose: (context, provider) => provider.dispose()';

/// Constructor name (unnamed ctor) that triggers injection.
const String _providerType = 'Provider';

/// Method name on the `WidgetEnvironment.environment` extension from
/// `solid_annotations`.
const String _environmentMethod = 'environment';

/// Named-argument labels the visitor inspects.
const String _createArg = 'create';
const String _disposeArgName = 'dispose';

/// Walks the AST and records insertion edits at every Provider /
/// `.environment<T>()` call that needs a `dispose:` argument.
///
/// Two-tier matching:
///
///   1. **Element-based.** When the resolver has populated
///      `MethodInvocation.methodName.element` /
///      `InstanceCreationExpression.constructorName.element`, match by class
///      name plus library URI (`package:provider/` for `Provider`,
///      `package:solid_annotations/` for `.environment`). Catches aliased
///      imports like `import 'package:provider/provider.dart' as p;
///      p.Provider(...)`.
///   2. **Textual fallback.** When the resolver hasn't run (parsed-AST
///      fallback for an annotation-free file, or test sandbox without the
///      Flutter SDK), match by lexeme. Bare `Provider(...)` parses as
///      [MethodInvocation] (no `const` / `new` keyword); `new Provider(...)`
///      and `const Provider(...)` parse as [InstanceCreationExpression].
class _ProviderDisposeVisitor extends RecursiveAstVisitor<void> {
  _ProviderDisposeVisitor(this._source, this._ast);

  final String _source;

  /// The compilation unit being walked — reused by [_hasDisposeInSameUnit]
  /// for the AST-only same-file class lookup (tier 2). This is the SAME
  /// unit the visitor is traversing (either the builder's already-resolved
  /// unit, or the freshly re-parsed assembled output), so a class found here
  /// is always in scope at the call site being rewritten.
  final CompilationUnit _ast;

  final List<ValueEdit> edits = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isEnvironmentCall(node)) {
      if (!_hasNamedArg(node.argumentList, _disposeArgName)) {
        _maybeInject(
          node.argumentList,
          typeArguments: node.typeArguments,
          callback: _firstPositionalArg(node.argumentList),
        );
      }
    } else if (_isBareProviderCall(node)) {
      if (_hasNamedArg(node.argumentList, _createArg) &&
          !_hasNamedArg(node.argumentList, _disposeArgName)) {
        _maybeInject(
          node.argumentList,
          typeArguments: node.typeArguments,
          callback: _namedArgValue(node.argumentList, _createArg),
        );
      }
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_isUnnamedProviderCtor(node)) {
      final args = node.argumentList;
      if (_hasNamedArg(args, _createArg) &&
          !_hasNamedArg(args, _disposeArgName)) {
        _maybeInject(
          args,
          typeArguments: node.constructorName.type.typeArguments,
          callback: _namedArgValue(args, _createArg),
        );
      }
    }
    // `MultiProvider(...)` and named ctors (`Provider.value(...)`) are not
    // injected here; the recursion below descends into argument lists so
    // inner `Provider(...)` entries inside `MultiProvider(providers: [...])`
    // are visited.
    super.visitInstanceCreationExpression(node);
  }

  /// True when [node] is a `.environment<T>(...)` extension call from
  /// `solid_annotations`. Element-based when the resolver populated the
  /// extension-method element; textual fallback on
  /// `target != null && methodName.name == 'environment'`.
  bool _isEnvironmentCall(MethodInvocation node) {
    final element = node.methodName.element;
    if (element != null) {
      if (element.name != _environmentMethod) return false;
      final enclosing = element.enclosingElement;
      if (enclosing is! ExtensionElement) return false;
      return isFromPackage(enclosing.library.uri, 'solid_annotations');
    }
    // Unresolved fallback. `target != null` keeps `environment` instance
    // calls on user types from being misidentified — the canonical
    // authoring shape is `context.environment<T>(...)`.
    return node.target != null && node.methodName.name == _environmentMethod;
  }

  /// True when [node] is a bare `Provider(...)` (no `const` / `new`) whose
  /// resolved ctor (when present) lives in `package:provider/`.
  bool _isBareProviderCall(MethodInvocation node) {
    final element = node.methodName.element;
    if (element is ConstructorElement) {
      return _isProviderCtor(element);
    }
    return node.target == null && node.methodName.name == _providerType;
  }

  /// True when [node]'s ctor element is the unnamed `Provider` constructor.
  bool _isUnnamedProviderCtor(InstanceCreationExpression node) {
    final element = node.constructorName.element;
    if (element != null) {
      if (!_isProviderCtor(element)) return false;
      // Analyzer 9 docs say the unnamed ctor's name is `'new'`; null and
      // empty are accepted defensively in case the implementation drifts.
      final name = element.name;
      return name == 'new' || name == null || name.isEmpty;
    }
    final typeName = node.constructorName.type.name.lexeme;
    final namedCtor = node.constructorName.name?.name;
    return typeName == _providerType && namedCtor == null;
  }

  /// True iff [ctor] is a constructor on the `Provider` class declared in
  /// `package:provider/`.
  bool _isProviderCtor(ConstructorElement ctor) {
    final enclosing = ctor.enclosingElement;
    if (enclosing.name != _providerType) return false;
    return isFromPackage(enclosing.library.uri, 'provider');
  }

  /// Injects the dispose closure into [args] iff the created type statically
  /// has a `dispose()` method. Callers have already checked the presence /
  /// absence of `create:` and `dispose:` named args; this is the new
  /// type-aware gate.
  void _maybeInject(
    ArgumentList args, {
    required TypeArgumentList? typeArguments,
    required Expression? callback,
  }) {
    if (_createdTypeHasDispose(typeArguments, callback)) {
      _addInjection(args);
    }
  }

  /// True iff the type created at this call site has a `dispose()` method,
  /// using two-tier resolution:
  ///
  ///  1. **Element-based.** When the `create` callback's return expression
  ///     has a resolved `staticType`, look up `dispose()` across its full
  ///     inheritance chain via `InterfaceType.lookUpMethod`. Correct for any
  ///     resolvable type, including ones declared in another file/package
  ///     (e.g. a real `ChangeNotifier`) — but only reachable when the caller
  ///     supplied an already-resolved `CompilationUnit` (the builder's
  ///     no-annotation fast path); the main annotated-file pipeline
  ///     re-parses its assembled output with no resolver, so this tier is a
  ///     no-op there.
  ///  2. **AST fallback (same file only).** Resolve the created type's
  ///     *name* — the explicit type argument (`Provider<T>`,
  ///     `.environment<T>()`) if present, else the name parsed from the
  ///     `create` callback's returned constructor call — then look for a
  ///     `ClassDeclaration` of that name in [_ast] and check whether it
  ///     declares `dispose()` itself or extends/implements/mixes in one of
  ///     [_knownDisposableBaseNames]. A type declared in a DIFFERENT file
  ///     that this tier cannot see is treated as "no evidence of dispose()"
  ///     — the safe default is to inject nothing rather than guess.
  bool _createdTypeHasDispose(
    TypeArgumentList? typeArguments,
    Expression? callback,
  ) {
    final returnExpr = _calleeReturnExpression(callback);
    final elementResult = _hasDisposeViaElement(returnExpr);
    if (elementResult != null) return elementResult;

    final typeName =
        _explicitTypeArgName(typeArguments) ??
        _constructedTypeNameFromExpression(returnExpr);
    if (typeName == null) return false;
    return _hasDisposeInSameUnit(typeName) ?? false;
  }

  /// Tier 1 of [_createdTypeHasDispose]. Returns `null` (not `false`) when
  /// [returnExpr]'s `staticType` isn't a resolved `InterfaceType` — that
  /// means "inapplicable", distinct from "resolved and definitely no
  /// `dispose()`", so the caller knows to fall through to tier 2 instead of
  /// treating an unresolved type as a hard negative.
  bool? _hasDisposeViaElement(Expression? returnExpr) {
    final type = returnExpr?.staticType;
    if (type is! InterfaceType) return null;
    return type.lookUpMethod('dispose', type.element.library) != null;
  }

  /// Tier 2 of [_createdTypeHasDispose]. Returns `null` when no
  /// `ClassDeclaration` named [typeName] exists in [_ast] — distinct from
  /// `false` ("found it, and it has no dispose evidence") purely for
  /// documentation; the caller treats both as "don't inject".
  bool? _hasDisposeInSameUnit(String typeName) {
    for (final decl in _ast.declarations) {
      if (decl is ClassDeclaration && decl.name.lexeme == typeName) {
        return _classDeclaresDispose(decl) || _extendsKnownDisposableBase(decl);
      }
    }
    return null;
  }

  /// True iff [decl] declares its own `dispose()` method (not a getter or
  /// setter). Matches both a hand-written stub (the documented
  /// `void dispose() {}` opt-in from `WidgetEnvironment.environment`'s doc
  /// comment) and a Solid-synthesized `dispose()` — by the time this
  /// visitor runs on the assembled output, an annotated class's synthesized
  /// `dispose()` is already textually present.
  bool _classDeclaresDispose(ClassDeclaration decl) {
    for (final member in decl.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == 'dispose' &&
          !member.isGetter &&
          !member.isSetter) {
        return true;
      }
    }
    return false;
  }

  /// True iff [decl]'s `extends` / `with` / `implements` clause names one of
  /// [_knownDisposableBaseNames].
  bool _extendsKnownDisposableBase(ClassDeclaration decl) {
    final superName = decl.extendsClause?.superclass.name.lexeme;
    if (superName != null && _knownDisposableBaseNames.contains(superName)) {
      return true;
    }
    final mixinNames =
        decl.withClause?.mixinTypes.map((t) => t.name.lexeme) ?? const [];
    if (mixinNames.any(_knownDisposableBaseNames.contains)) return true;
    final interfaceNames =
        decl.implementsClause?.interfaces.map((t) => t.name.lexeme) ?? const [];
    return interfaceNames.any(_knownDisposableBaseNames.contains);
  }

  /// The `create` callback's returned expression: the expression body for
  /// `(ctx) => X()`, or the first `return` statement's expression for a
  /// block-bodied callback (`(ctx) { ...; return X(); }`). `null` for any
  /// other callback shape (not a `FunctionExpression`, no `return`, etc.) —
  /// callers treat that as "cannot determine".
  Expression? _calleeReturnExpression(Expression? callback) {
    if (callback is! FunctionExpression) return null;
    final body = callback.body;
    if (body is ExpressionFunctionBody) return body.expression;
    if (body is BlockFunctionBody) {
      for (final stmt in body.block.statements) {
        if (stmt is ReturnStatement) return stmt.expression;
      }
    }
    return null;
  }

  /// The simple name of a single explicit type argument (`Provider<T>`,
  /// `.environment<T>()`). `null` when there are zero or more-than-one type
  /// arguments, or the argument isn't a plain `NamedType`.
  String? _explicitTypeArgName(TypeArgumentList? typeArguments) {
    final args = typeArguments?.arguments;
    if (args == null || args.length != 1) return null;
    final arg = args.single;
    return arg is NamedType ? arg.name.lexeme : null;
  }

  /// The constructed class's simple name parsed from [expr]: an
  /// `InstanceCreationExpression` (`new X()` / `const X()`) or a bare
  /// `MethodInvocation` with no target (`X()` — the unresolved-AST shape for
  /// a constructor call without `new`/`const`, per [_isBareProviderCall]).
  /// `null` for any other shape.
  String? _constructedTypeNameFromExpression(Expression? expr) {
    if (expr is InstanceCreationExpression) {
      return expr.constructorName.type.name.lexeme;
    }
    if (expr is MethodInvocation && expr.target == null) {
      return expr.methodName.name;
    }
    return null;
  }

  /// The first argument in [args] that is NOT a `NamedExpression` — the
  /// `.environment(create, {dispose})` shape's positional `create` callback.
  Expression? _firstPositionalArg(ArgumentList args) {
    for (final arg in args.arguments) {
      if (arg is! NamedExpression) return arg;
    }
    return null;
  }

  /// The value expression of the named argument [name] in [args], or `null`
  /// if absent.
  Expression? _namedArgValue(ArgumentList args, String name) {
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == name) {
        return arg.expression;
      }
    }
    return null;
  }

  bool _hasNamedArg(ArgumentList args, String name) {
    for (final arg in args.arguments) {
      if (arg is NamedExpression && arg.name.label.name == name) {
        return true;
      }
    }
    return false;
  }

  /// Inserts the dispose closure just before the closing `)` of [args].
  ///
  /// The existing argument list either ends in a trailing comma or it does
  /// not. The dart formatter will normalize whitespace in either case, so the
  /// raw insertion just keeps the resulting source syntactically valid.
  void _addInjection(ArgumentList args) {
    final replacement = _argsEndWithTrailingComma(args)
        ? '$_disposeArg,'
        : ', $_disposeArg';
    edits.add(
      ValueEdit(
        args.rightParenthesis.offset,
        args.rightParenthesis.offset,
        replacement,
      ),
    );
  }

  /// True iff the argument list source ends with a trailing comma between
  /// the last argument and the closing `)`. Empty argument lists return
  /// false (there is no last-argument comma to detect).
  bool _argsEndWithTrailingComma(ArgumentList args) {
    if (args.arguments.isEmpty) return false;
    final lastArg = args.arguments.last;
    final rightParen = args.rightParenthesis.offset;
    final between = _source.substring(lastArg.end, rightParen);
    return between.contains(',');
  }
}
