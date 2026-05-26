import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:solid_generator/src/element_utils.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// Returns [text] with `dispose: (context, provider) => provider.dispose()`
/// injected into every `Provider(...)`, `Provider<T>(...)`, and
/// `.environment<T>(...)` call site that omits the `dispose:` named argument.
///
/// Every Solid-lowered class implements `Disposable` and has a synthesized
/// `dispose()`, so the injected closure resolves at runtime for any annotated
/// reactive class. Non-Solid types whose creator has no `dispose()` method
/// must opt out by supplying an explicit `dispose:` (including
/// `dispose: null`).
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
  final visitor = _ProviderDisposeVisitor(text);
  ast.accept(visitor);
  if (visitor.edits.isEmpty) return text;
  return applyEditsToRange(text, visitor.edits, 0);
}

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
  _ProviderDisposeVisitor(this._source);

  final String _source;
  final List<ValueEdit> edits = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (_isEnvironmentCall(node)) {
      if (!_hasNamedArg(node.argumentList, _disposeArgName)) {
        _addInjection(node.argumentList);
      }
    } else if (_isBareProviderCall(node)) {
      _maybeInject(node.argumentList);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (_isUnnamedProviderCtor(node)) {
      _maybeInject(node.argumentList);
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

  /// Provider-form guard: inject only when the call site has a `create:`
  /// argument and lacks a `dispose:` argument.
  void _maybeInject(ArgumentList args) {
    if (_hasNamedArg(args, _createArg) &&
        !_hasNamedArg(args, _disposeArgName)) {
      _addInjection(args);
    }
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
