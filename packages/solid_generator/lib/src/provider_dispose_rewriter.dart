import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:solid_generator/src/annotation_reader.dart'
    show solidEffectName, solidEnvironmentName, solidQueryName, solidStateName;
import 'package:solid_generator/src/ast_compat.dart';
import 'package:solid_generator/src/element_utils.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// Returns [text] with `dispose: (context, provider) => provider.dispose()`
/// injected into every `Provider(...)`, `Provider<T>(...)`, and
/// `.environment<T>(...)` call site that omits the `dispose:` named argument
/// AND whose created type is recognized as needing injection under the
/// four-tier decision rule documented on [_ProviderDisposeVisitor.
/// _createdTypeHasDispose] (also SPEC.md §4.9 rule 7):
///
///  1. The created type statically has a `dispose()` method (own
///     declaration, or inherited — including transitively through a
///     same-file base class chain) → inject.
///  2. The created type is `@Solid*`-annotated — its lowered `lib/` output
///     always synthesizes `dispose()`, even though the pre-lowering source
///     declaration this checker sees does not have one yet → inject.
///  3. The created type's declaration IS visible (resolved, or found in the
///     file being scanned) and shows neither of the above → skip; injecting
///     unconditionally here is exactly the bug this file exists to avoid
///     (a compile-time `undefined_method` on `.dispose()` for a type that
///     never had one).
///  4. The created type's declaration is not visible anywhere this checker
///     looked (typically a cross-file, non-`@Solid*` type on the path that
///     has no resolver available at all) → inject, preserving the
///     pre-type-aware default: a wrong guess fails LOUDLY at compile time,
///     and an explicit `dispose: null` remains the opt-out.
///
/// Tier 2's cross-file recognition reuses the same `classRegistry` that
/// `builder.dart` populates for the `.value` cross-class rewrite (same-file
/// via `_prescanClassRegistry`, cross-file via `_populateCrossFileTypes`) —
/// see [collectProviderCreatedTypeNames], which seeds that registry with the
/// types created at Provider/`.environment` call sites so a type gets
/// recognized even when nothing in the file consumes it via an
/// `@SolidEnvironment` field. Because matching is by simple name (not
/// library-identity), two distinct types sharing a name across libraries
/// could in principle collide in the registry; see SPEC.md §4.9 rule 7 for
/// the caveat.
///
/// `MultiProvider(...)` itself never receives a `dispose:` argument — the
/// visitor descends into its `providers:` list naturally and applies the
/// per-Provider rule to each entry. `Provider.value(...)` is not rewritten:
/// it owns no instance and takes no `dispose:`.
///
/// When [unit] is supplied the function reuses it instead of re-parsing
/// [text] — used by the builder's no-annotation fast path, which already has
/// a parsed (and, in that case, TYPE-RESOLVED) `CompilationUnit` in hand.
/// [classRegistry] is the class-name → reactive-member-name map described
/// above; pass the same map threaded through the rest of the builder's
/// rewrite pipeline so tier 2 sees every same-file and cross-file
/// `@Solid*`-annotated type the builder already knows about.
///
/// Returns [text] (the same `String` object, by reference) when no edits are
/// emitted. Callers can rely on that identity to skip downstream work like
/// re-formatting an unchanged file.
String addProviderDisposeAtCallSites(
  String text, {
  CompilationUnit? unit,
  Map<String, Set<String>> classRegistry = const {},
}) {
  final ast =
      unit ??
      parseString(
        content: text,
        featureSet: FeatureSet.latestLanguageVersion(),
        throwIfDiagnostics: false,
      ).unit;
  final visitor = _ProviderDisposeVisitor(text, ast, classRegistry);
  ast.accept(visitor);
  if (visitor.edits.isEmpty) return text;
  return applyEditsToRange(text, visitor.edits, 0);
}

/// Returns the simple type names referenced by every `Provider(...)`,
/// `Provider<T>(...)`, and `.environment<T>(...)` call site in [unit] —
/// regardless of whether the call site already carries a `dispose:`
/// argument, and regardless of whether the type turns out to be
/// `@Solid*`-annotated.
///
/// Used by `builder.dart` to seed the cross-file class registry
/// (`_populateCrossFileTypes` / `classRegistry`) with the types created at
/// Provider/`.environment` call sites — the registry's OTHER population
/// route only looks at `@SolidEnvironment` field types, which misses the
/// dominant real-world shape: a top-level `main()` (or an unannotated
/// widget) that provides a cross-file `@SolidState` controller via
/// `.environment<T>()` without ever consuming it through an
/// `@SolidEnvironment` field itself. Without this seed, such a controller's
/// synthesized `dispose()` (added only during lowering, invisible both to
/// the resolved-element tier — which sees the pre-lowering source class —
/// and to the same-file AST tier — which never looks outside the current
/// file) is silently never invoked: a real resource leak.
Set<String> collectProviderCreatedTypeNames(CompilationUnit unit) {
  final visitor = _ProviderCreatedTypeNameVisitor();
  unit.accept(visitor);
  return visitor.typeNames;
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

/// Names of the four `@Solid*` annotation classes. Consulted by
/// [_resolvedDeclarationIsAnnotated] to recognize a resolved type as
/// Solid-annotated directly off its element model, without needing AST
/// access to its declaring file.
const Set<String> _solidAnnotationNames = {
  solidStateName,
  solidEffectName,
  solidQueryName,
  solidEnvironmentName,
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

/// True iff any field, getter, or method of [type]'s resolved declaration
/// carries a `@Solid*` annotation.
///
/// Only meaningful — and only ever consulted — when [type] was resolved
/// from an already-resolved `CompilationUnit` (the builder's no-annotation
/// fast path). That path resolves the user's pre-lowering `source/` library,
/// so a type like a cross-file `@SolidState` controller has NOT yet gained
/// its synthesized `dispose()` (lowering hasn't happened) but DOES already
/// carry its real `@SolidState` / `@SolidEffect` / `@SolidQuery` /
/// `@SolidEnvironment` metadata, because those are genuine source-level
/// annotations, resolvable on the element model like any other.
bool _resolvedDeclarationIsAnnotated(InterfaceType type) {
  final element = type.element;
  return _anyMemberHasSolidAnnotation(element.fields) ||
      _anyMemberHasSolidAnnotation(element.getters) ||
      _anyMemberHasSolidAnnotation(element.methods);
}

bool _anyMemberHasSolidAnnotation(Iterable<Element> members) =>
    members.any((m) => _hasSolidAnnotationElement(m.metadata));

/// Element-level counterpart of `annotation_reader.findAnnotationByName`'s
/// Element-based branch: true iff any of [metadata]'s annotations resolves
/// to a constructor of one of [_solidAnnotationNames] declared in
/// `package:solid_annotations/`.
///
/// In practice this rarely fires for a CROSS-FILE type: an
/// `ElementAnnotation`'s `.element` is only populated once the annotation's
/// OWN declaring library has gone through constant-evaluation, which the
/// resolver invoked on the file being built does not guarantee for a
/// class reached only transitively through an import — so a resolved
/// `InterfaceType` can come back with fully-typed `fields`/`getters`/
/// `methods` (proving the declaration IS visible) while every annotation's
/// `.element` is still `null`. `_createdTypeHasDispose` therefore treats
/// this check as a secondary, belt-and-suspenders signal and relies on the
/// name-based `classRegistry` (tier 2's other route) as the mechanism that
/// actually carries cross-file recognition in practice.
bool _hasSolidAnnotationElement(Metadata metadata) {
  for (final ann in metadata.annotations) {
    final element = ann.element;
    if (element is! ConstructorElement) continue;
    final enclosing = element.enclosingElement;
    if (!_solidAnnotationNames.contains(enclosing.name)) continue;
    if (isFromPackage(enclosing.library.uri, 'solid_annotations')) return true;
  }
  return false;
}

/// Collects every type name referenced by a Provider / `.environment` call
/// site — the lightweight sibling of [_ProviderDisposeVisitor] used only for
/// name collection (see [collectProviderCreatedTypeNames]). Shares the
/// call-site detection predicates above; unlike [_ProviderDisposeVisitor] it
/// records every call site regardless of whether `dispose:` is already
/// present, because the builder needs to know about the type either way.
class _ProviderCreatedTypeNameVisitor extends RecursiveAstVisitor<void> {
  final Set<String> typeNames = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isEnvironmentCall(node)) {
      _record(node.typeArguments, _firstPositionalArg(node.argumentList));
    } else if (_isBareProviderCall(node)) {
      _record(
        node.typeArguments,
        _namedArgValue(node.argumentList, _createArg),
      );
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_isUnnamedProviderCtor(node)) {
      _record(
        node.constructorName.type.typeArguments,
        _namedArgValue(node.argumentList, _createArg),
      );
    }
    super.visitInstanceCreationExpression(node);
  }

  void _record(TypeArgumentList? typeArguments, Expression? callback) {
    final name =
        _explicitTypeArgName(typeArguments) ??
        _constructedTypeNameFromExpression(_calleeReturnExpression(callback));
    if (name != null) typeNames.add(name);
  }
}

/// Walks the AST and records insertion edits at every Provider /
/// `.environment<T>()` call that needs a `dispose:` argument, per the
/// four-tier rule documented on [addProviderDisposeAtCallSites] /
/// [_createdTypeHasDispose].
class _ProviderDisposeVisitor extends RecursiveAstVisitor<void> {
  _ProviderDisposeVisitor(this._source, this._ast, this._classRegistry);

  final String _source;

  /// The compilation unit being walked — reused by [_hasDisposeInSameUnit]
  /// for the AST-only same-file class lookup (tier 2). This is the SAME
  /// unit the visitor is traversing (either the builder's already-resolved
  /// unit, or the freshly re-parsed assembled output), so a class found here
  /// is always in scope at the call site being rewritten.
  final CompilationUnit _ast;

  /// Class-name → reactive-member-name map — the same `classRegistry` the
  /// rest of the builder threads through the `.value` cross-class rewrite
  /// (same-file entries from `_prescanClassRegistry`, cross-file entries
  /// from `_populateCrossFileTypes`, seeded for Provider/`.environment`
  /// call sites via [collectProviderCreatedTypeNames]). A type name present
  /// as a key is, by construction, `@Solid*`-annotated (only annotated
  /// classes are ever added) — see tier 2 of [_createdTypeHasDispose].
  final Map<String, Set<String>> _classRegistry;

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

  /// Injects the dispose closure into [args] iff the created type needs it
  /// under [_createdTypeHasDispose]. Callers have already checked the
  /// presence / absence of `create:` and `dispose:` named args; this is the
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

  /// True iff the type created at this call site needs `dispose:` injected,
  /// using a four-tier decision rule:
  ///
  ///  1. **Provable dispose().** Own declaration, or inherited — checked via
  ///     `InterfaceType.lookUpMethod` when the `create` callback's return
  ///     expression's `staticType` resolved (only reachable when the caller
  ///     supplied an
  ///     already-resolved `CompilationUnit` — the builder's no-annotation
  ///     fast path) or the same-file AST tier ([_hasDisposeInSameUnit] /
  ///     [_classDeclaresDispose] / [_extendsKnownDisposableBase], which also
  ///     walks a same-file base class transitively).
  ///  2. **`@Solid*`-annotated type.** Every Solid-lowered class always
  ///     synthesizes `dispose()` in its `lib/` output, even though the
  ///     pre-lowering declaration this checker can see has none yet.
  ///     Recognized via [_classRegistry] (name-based; same-file AND
  ///     cross-file — checked whether or not the type resolved, since a
  ///     resolved element's OWN annotation metadata is not reliably
  ///     resolvable across library boundaries — see
  ///     [_resolvedDeclarationIsAnnotated]'s doc) or, secondarily, via
  ///     [_resolvedDeclarationIsAnnotated] itself.
  ///  3. **Provably plain.** The type's declaration IS visible (resolved,
  ///     or found in [_ast]) and shows neither of the above — the type
  ///     genuinely has no `dispose()` and isn't Solid-lowered.
  ///  4. **Unknown.** The declaration isn't visible anywhere this checker
  ///     looked — typically a cross-file, non-`@Solid*` type reached on the
  ///     main annotated path, which never gets a resolver at all. The
  ///     conservative default here is to INJECT (not skip): this preserves
  ///     the tool's pre-type-aware behavior for anything it truly can't
  ///     see, so a wrong guess fails loudly at compile time rather than
  ///     silently leaking a resource; `dispose: null` is the explicit,
  ///     always-available opt-out.
  bool _createdTypeHasDispose(
    TypeArgumentList? typeArguments,
    Expression? callback,
  ) {
    final returnExpr = _calleeReturnExpression(callback);
    final type = returnExpr?.staticType;
    // The simple type name, when determinable at all — from the resolved
    // element when [type] resolved, else from the explicit type argument or
    // the `create` callback's constructor call text. Computed once up front
    // because tier 2's [_classRegistry] lookup applies identically whether
    // or not [type] resolved: a resolved element's OWN annotation metadata
    // is not reliably resolvable across library boundaries by every
    // resolver this function is fed (cross-file `@Solid*` constant
    // annotations can come back element-less even when the type itself is a
    // fully resolved `InterfaceType`), so the name-based registry — not
    // [_resolvedDeclarationIsAnnotated] alone — is the mechanism this tier
    // actually depends on.
    final typeName =
        (type is InterfaceType ? type.element.name : null) ??
        _explicitTypeArgName(typeArguments) ??
        _constructedTypeNameFromExpression(returnExpr);

    if (type is InterfaceType) {
      if (type.lookUpMethod('dispose', type.element.library) != null) {
        return true; // Tier 1 (resolved).
      }
      if (typeName != null && _classRegistry.containsKey(typeName)) {
        return true; // Tier 2 (registry).
      }
      if (_resolvedDeclarationIsAnnotated(type)) {
        return true; // Tier 2 (resolved element, belt-and-suspenders).
      }
      return false; // Tier 3: resolved, visible, neither → provably plain.
    }

    if (typeName != null) {
      if (_classRegistry.containsKey(typeName)) return true; // Tier 2.
      final sameUnitResult = _hasDisposeInSameUnit(typeName);
      if (sameUnitResult != null) return sameUnitResult; // Tiers 1 / 3.
    }
    return true; // Tier 4: declaration not visible anywhere — inject.
  }

  /// Tiers 1 / 3 of [_createdTypeHasDispose], same-file AST variant.
  /// Returns `null` when no `ClassDeclaration` named [typeName] exists in
  /// [_ast] — distinct from a definite `true`/`false` so the caller falls
  /// through to tier 4 instead of guessing.
  bool? _hasDisposeInSameUnit(String typeName) {
    final decl = _findClassInAst(typeName);
    if (decl == null) return null;
    return _classDeclaresDispose(decl) || _extendsKnownDisposableBase(decl);
  }

  /// Returns the `ClassDeclaration` named [name] in [_ast], or `null` if
  /// none exists. Shared by [_hasDisposeInSameUnit] and the transitive
  /// same-file base-class walk in [_extendsKnownDisposableBase].
  ClassDeclaration? _findClassInAst(String name) {
    for (final decl in _ast.declarations) {
      if (decl is ClassDeclaration && decl.name.lexeme == name) return decl;
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
  /// [_knownDisposableBaseNames] — checked TRANSITIVELY up a same-file
  /// `extends` chain: `class Mid extends ChangeNotifier {}` then
  /// `class Leaf extends Mid {}` in the same file must recognize `Leaf` as
  /// disposable even though `Leaf`'s own `extends` clause names `Mid`, not
  /// `ChangeNotifier` directly. [visited] guards against infinite recursion
  /// on a cyclic `extends` chain (invalid Dart, but the AST-only tier has no
  /// resolver to reject it upstream).
  bool _extendsKnownDisposableBase(
    ClassDeclaration decl, [
    Set<String>? visited,
  ]) {
    final seen = visited ?? <String>{};
    if (!seen.add(decl.name.lexeme)) return false;
    final mixinNames =
        decl.withClause?.mixinTypes.map((t) => t.name.lexeme) ?? const [];
    if (mixinNames.any(_knownDisposableBaseNames.contains)) return true;
    final interfaceNames =
        decl.implementsClause?.interfaces.map((t) => t.name.lexeme) ?? const [];
    if (interfaceNames.any(_knownDisposableBaseNames.contains)) return true;
    final superName = decl.extendsClause?.superclass.name.lexeme;
    if (superName == null) return false;
    if (_knownDisposableBaseNames.contains(superName)) return true;
    final superDecl = _findClassInAst(superName);
    if (superDecl == null) return false;
    return _extendsKnownDisposableBase(superDecl, seen);
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
