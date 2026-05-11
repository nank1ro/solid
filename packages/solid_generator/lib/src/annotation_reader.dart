import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/environment_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/query_model.dart';
import 'package:solid_generator/src/transformation_error.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// Name of the `@SolidState` annotation class.
///
/// Matching is textual on the unresolved AST — type resolution is required
/// for `.value` rewriting, but annotation detection is acceptable on names
/// because the user must import `solid_annotations` to use `@SolidState`
/// at all.
///
/// Exposed package-publicly so the target validator can match the same
/// identifier on non-field declarations.
const String solidStateName = 'SolidState';

/// Name of the `@SolidEffect` annotation class. Same matching contract as
/// [solidStateName] (textual on unresolved AST).
const String solidEffectName = 'SolidEffect';

/// Name of the `@SolidQuery` annotation class. Same matching contract as
/// [solidStateName] (textual on unresolved AST).
const String solidQueryName = 'SolidQuery';

/// Name of the `@SolidEnvironment` annotation class. Same matching contract
/// as [solidStateName] (textual on unresolved AST).
const String solidEnvironmentName = 'SolidEnvironment';

/// Lexemes of the `flutter_solidart` types whose runtime classes extend
/// `SignalBase<T>`. Matched textually on the unresolved AST per the
/// [solidStateName] contract. Consumed by the target validator (rejecting
/// `@SolidEnvironment` fields typed as one of these) and by the
/// cross-class `.value` rewrite. Excludes `SignalBuilder` /
/// `SolidartConfig` (those are non-`SignalBase` solidart names).
const Set<String> signalBaseTypeNames = {
  'Signal',
  'Computed',
  'Effect',
  'Resource',
};

/// Lexeme of the `Future` return-type identifier on a `@SolidQuery` method.
/// Matched textually on the unresolved AST per the same contract as
/// [solidStateName] — the user must import `dart:async` (or its re-export via
/// `dart:core`) to write the type at all.
const String futureLexeme = 'Future';

/// Lexeme of the `Stream` return-type identifier on a `@SolidQuery` method.
/// Same matching contract as [futureLexeme].
const String streamLexeme = 'Stream';

/// Reads a `@SolidState(...)` annotation on [decl] and returns a [FieldModel].
///
/// Returns `null` if [decl] carries no `@SolidState` annotation. The raw
/// [source] is passed in so each string member of the returned [FieldModel]
/// can be extracted verbatim via `source.substring(offset, end)`.
FieldModel? readSolidStateField(FieldDeclaration decl, String source) {
  final annotation = findAnnotationByName(solidStateName, decl.metadata);
  if (annotation == null) return null;

  final varList = decl.fields;
  final type = varList.type;
  final variable = varList.variables.first;

  return FieldModel(
    fieldName: variable.name.lexeme,
    typeText: type == null ? '' : source.substring(type.offset, type.end),
    initializerText: variable.initializer == null
        ? ''
        : source.substring(
            variable.initializer!.offset,
            variable.initializer!.end,
          ),
    annotationName: extractNameArgument(annotation),
    isLate: varList.isLate,
    // `TypeAnnotation.question` is the `?` token at the top level of the
    // declared type. Using it (vs. a `typeText.endsWith('?')` heuristic)
    // correctly classifies nested-nullable types like `List<int?>` as
    // non-nullable at the outer level.
    isNullable: type?.question != null,
  );
}

/// Reads a `@SolidEnvironment()` annotation on [decl] and returns an
/// [EnvironmentModel], or `null` if no `@SolidEnvironment` annotation is
/// present. Validation (`late` required, no initializer, non-`SignalBase`
/// type, widget/state host) runs upstream in
/// `validateSolidEnvironmentTargets`; this reader only extracts the textual
/// name and type for `emitEnvironmentField`.
EnvironmentModel? readSolidEnvironmentField(
  FieldDeclaration decl,
  String source,
) {
  final annotation = findAnnotationByName(solidEnvironmentName, decl.metadata);
  if (annotation == null) return null;

  final varList = decl.fields;
  final type = varList.type;
  final variable = varList.variables.first;

  return EnvironmentModel(
    fieldName: variable.name.lexeme,
    typeText: type == null ? '' : source.substring(type.offset, type.end),
  );
}

/// Reads a `@SolidState(...)` annotation on the getter [decl] and returns a
/// [GetterModel]. Returns `null` when the method is not an `@SolidState`
/// getter; non-getter methods and static getters are filtered out earlier by
/// `validateSolidStateTargets`, but this reader is defensive and skips them
/// silently as well.
///
/// The getter body is rewritten in place: any reference to a name in
/// [reactiveFields] receives `.value`. Both expression-body
/// (`get x => <expr>;`) and block-body (`get x { ... }`) shapes are
/// supported. Other body kinds (abstract / native) are rejected with a
/// [CodeGenerationError].
GetterModel? readSolidStateGetter(
  MethodDeclaration decl,
  Set<String> reactiveFields,
  String source, {
  Set<String> queryNames = const {},
  Map<String, Set<String>> classRegistry = const {},
  Map<String, Set<String>> classCollectionFields = const {},
  Map<String, String> environmentFields = const {},
}) {
  if (!decl.isGetter || decl.isStatic) return null;
  final annotation = findAnnotationByName(solidStateName, decl.metadata);
  if (annotation == null) return null;

  final returnType = decl.returnType;
  final typeText = returnType == null
      ? ''
      : source.substring(returnType.offset, returnType.end);

  final body = decl.body;
  final getterName = decl.name.lexeme;
  // Getters do not need tracked names: the lowered Computed auto-tracks via
  // its closure's reads at runtime — both `@SolidState` reads (rewritten
  // with `.value`) and `@SolidQuery` calls subscribe through their respective
  // upstream accessors (`Signal.value` / `Resource.call() → state`).
  final (
    :bodyText,
    :isBlockBody,
    trackedNames: _,
    trackedQueryNames: _,
    selfCycleFound: _,
  ) = _readReactiveBody(
    body,
    reactiveFields,
    source,
    memberName: getterName,
    emptyDepsError:
        "getter '$getterName' has no reactive dependencies; "
        'use `final` or a plain getter instead of `@SolidState`',
    unsupportedBodyError:
        '@SolidState getter must have an expression body (=> ...) or a '
        'block body ({ ... }); abstract and native bodies are not supported',
    queryNames: queryNames,
    classRegistry: classRegistry,
    classCollectionFields: classCollectionFields,
    environmentFields: environmentFields,
  );

  return GetterModel(
    getterName: getterName,
    typeText: typeText,
    bodyText: bodyText,
    isBlockBody: isBlockBody,
    annotationName: extractNameArgument(annotation),
  );
}

/// Returns the rewritten body text, whether it came from a block body, and
/// the dedup'd source-order lists of `@SolidState` field/getter and
/// `@SolidQuery` method names read in tracked position inside the body.
/// Shared between `readSolidStateGetter`, `readSolidEffectMethod`, and
/// `readSolidQueryMethod`: all three discriminate `ExpressionFunctionBody`
/// vs `BlockFunctionBody`, run the `.value` rewrite, and reject
/// abstract/native bodies. The zero-deps check fires only when
/// [emptyDepsError] is non-null; queries pass `null` because the
/// reactive-deps requirement is waived for them. Error wording differs per
/// caller — pass it in.
///
/// `trackedReadOffsets` from the rewrite are intentionally discarded here —
/// SignalBuilder placement is a `build()` concern, not a `Computed` /
/// `Effect` / `Resource` body concern. The two name lists feed
/// `readSolidQueryMethod`'s `source:` argument synthesis; getter and effect
/// callers destructure them into `_` since their lowered shapes (Computed,
/// Effect) auto-track via the closure's reads at runtime.
///
/// [currentMember] is the enclosing method's name when reading a
/// `@SolidQuery` body — passed through to the visitor so a zero-arg call
/// to it sets [ValueRewriteResult.selfCycleFound]. Pass `null` for
/// state-getter / effect callers.
({
  String bodyText,
  bool isBlockBody,
  List<String> trackedNames,
  List<String> trackedQueryNames,
  bool selfCycleFound,
})
_readReactiveBody(
  FunctionBody body,
  Set<String> reactiveFields,
  String source, {
  required String memberName,
  required String? emptyDepsError,
  required String unsupportedBodyError,
  Set<String> queryNames = const {},
  String? currentMember,
  Map<String, Set<String>> classRegistry = const {},
  Map<String, Set<String>> classCollectionFields = const {},
  Map<String, String> environmentFields = const {},
}) {
  final AstNode node;
  final bool isBlockBody;
  if (body is ExpressionFunctionBody) {
    node = body.expression;
    isBlockBody = false;
  } else if (body is BlockFunctionBody) {
    node = body.block;
    isBlockBody = true;
  } else {
    throw CodeGenerationError(unsupportedBodyError, null, memberName);
  }
  final result = collectValueEdits(
    node,
    reactiveFields,
    source,
    queryNames: queryNames,
    currentMember: currentMember,
    classRegistry: classRegistry,
    classCollectionFields: classCollectionFields,
    environmentFields: environmentFields,
  );
  // Zero-deps Effect / Computed are rejected. A reactive dep is either a
  // `.value`-rewritten state read, a tracked query-call invocation, OR a
  // cross-class read that produced a tracked-read offset (cross-class reads
  // record offsets even when the rewrite emits no edit — e.g. `xs.length`
  // on a ListSignal field reached via env-injection).
  if (emptyDepsError != null &&
      result.edits.isEmpty &&
      result.trackedQueryNames.isEmpty &&
      result.trackedReadOffsets.isEmpty) {
    throw CodeGenerationError(emptyDepsError, null, memberName);
  }
  final bodyText = applyEditsToRange(
    source.substring(node.offset, node.end),
    result.edits,
    node.offset,
  );
  return (
    bodyText: bodyText,
    isBlockBody: isBlockBody,
    trackedNames: result.trackedReadNames,
    trackedQueryNames: result.trackedQueryNames,
    selfCycleFound: result.selfCycleFound,
  );
}

/// Reads a `@SolidEffect(...)` annotation on the method [decl] and returns an
/// [EffectModel]. Returns `null` when [decl] is not an `@SolidEffect`-bearing
/// instance method; getters, setters, and static methods are filtered out
/// here defensively (the target validator rejects them with a clearer
/// error before this reader runs).
///
/// The method body is rewritten in place: any reference to a name in
/// [reactiveFields] receives `.value`. Both expression-body
/// (`void m() => <expr>;`) and block-body (`void m() { ... }`) shapes are
/// supported. Other body kinds (abstract / native) are rejected with a
/// [CodeGenerationError].
///
/// An Effect with zero reactive dependencies is rejected with the message
/// `"effect '<name>' has no reactive dependencies"`. A dedicated rejection
/// test pins this behavior.
EffectModel? readSolidEffectMethod(
  MethodDeclaration decl,
  Set<String> reactiveFields,
  String source, {
  Set<String> queryNames = const {},
  Map<String, Set<String>> classRegistry = const {},
  Map<String, Set<String>> classCollectionFields = const {},
  Map<String, String> environmentFields = const {},
}) {
  if (decl.isGetter || decl.isSetter || decl.isStatic) return null;
  final annotation = findAnnotationByName(solidEffectName, decl.metadata);
  if (annotation == null) return null;

  final methodName = decl.name.lexeme;
  // Effects do not need tracked names: the autorun subscribes by running the
  // body eagerly. A `<query>()` call inside an effect body subscribes via
  // `Resource.call() → state` at runtime, same mechanism as a state read.
  final (
    :bodyText,
    :isBlockBody,
    trackedNames: _,
    trackedQueryNames: _,
    selfCycleFound: _,
  ) = _readReactiveBody(
    decl.body,
    reactiveFields,
    source,
    memberName: methodName,
    emptyDepsError:
        "effect '$methodName' has no reactive dependencies; "
        'use a regular method or call it once explicitly instead of '
        '`@SolidEffect`',
    unsupportedBodyError:
        '@SolidEffect method must have an expression body (=> ...) or a '
        'block body ({ ... }); abstract and native bodies are not supported',
    queryNames: queryNames,
    classRegistry: classRegistry,
    classCollectionFields: classCollectionFields,
    environmentFields: environmentFields,
  );

  return EffectModel(
    methodName: methodName,
    bodyText: bodyText,
    isBlockBody: isBlockBody,
    annotationName: extractNameArgument(annotation),
  );
}

/// Reads a `@SolidQuery(...)` annotation on the method [decl] and returns a
/// [QueryModel]. Returns `null` when [decl] is not an `@SolidQuery`-bearing
/// instance method whose return type is `Future<T>` or `Stream<T>`. Getters,
/// setters, and static methods are filtered out here defensively; the target
/// validator rejects them with a clearer error before this reader runs.
///
/// The method body is rewritten in place: any reference to a name in
/// [reactiveFields] receives `.value`. Both expression-body
/// (`Future<T> m() async => …;` / `Stream<T> m() => …;`) and block-body
/// (`Future<T> m() async {…}` / `Stream<T> m() async* {…}` /
/// `Stream<T> m() {…}`) shapes are supported. Other body kinds (abstract /
/// native) are rejected with a [CodeGenerationError].
///
/// Unlike [readSolidEffectMethod] / [readSolidStateGetter], this reader does
/// NOT enforce a reactive-deps requirement — a query body MAY have zero
/// reactive reads.
QueryModel? readSolidQueryMethod(
  MethodDeclaration decl,
  Set<String> reactiveFields,
  String source, {
  Set<String> queryNames = const {},
  Map<String, Set<String>> classRegistry = const {},
  Map<String, Set<String>> classCollectionFields = const {},
  Map<String, String> environmentFields = const {},
}) {
  if (decl.isGetter || decl.isSetter || decl.isStatic) return null;
  final annotation = findAnnotationByName(solidQueryName, decl.metadata);
  if (annotation == null) return null;
  // Other return types are rejected by `validateSolidQueryTargets`;
  // this defensive guard keeps the reader robust against direct callers.
  final returnType = decl.returnType;
  if (returnType is! NamedType) return null;
  final returnTypeName = returnType.name.lexeme;
  if (returnTypeName != futureLexeme && returnTypeName != streamLexeme) {
    return null;
  }
  final typeArg = returnType.typeArguments?.arguments.firstOrNull;
  final innerTypeText = typeArg == null
      ? ''
      : source.substring(typeArg.offset, typeArg.end);

  final methodName = decl.name.lexeme;
  // emptyDepsError: null — the reactive-deps requirement is waived for
  // queries.
  final (
    :bodyText,
    :isBlockBody,
    :trackedNames,
    :trackedQueryNames,
    :selfCycleFound,
  ) = _readReactiveBody(
    decl.body,
    reactiveFields,
    source,
    memberName: methodName,
    emptyDepsError: null,
    unsupportedBodyError:
        '@SolidQuery method must have an expression body (=> ...) or a '
        'block body ({ ... }); abstract and native bodies are not supported',
    queryNames: queryNames,
    currentMember: methodName,
    classRegistry: classRegistry,
    classCollectionFields: classCollectionFields,
    environmentFields: environmentFields,
  );

  // A self-cycle is rejected at codegen — solidart would re-run
  // indefinitely otherwise. Inter-query cycles (A reads B, B reads A) are
  // not validated at codegen and surface as a runtime error.
  if (selfCycleFound) {
    throw CodeGenerationError(
      "@SolidQuery '$methodName' invokes itself in its own body — "
      'self-cycles are rejected at codegen because the lowered Resource '
      'would re-run indefinitely. Refactor the body to remove the recursive '
      'call, or split into two queries.',
      null,
      methodName,
    );
  }

  return QueryModel(
    methodName: methodName,
    bodyText: bodyText,
    isBlockBody: isBlockBody,
    innerTypeText: innerTypeText,
    bodyKeyword: decl.body.keyword?.lexeme ?? '',
    isStream: returnTypeName == streamLexeme,
    trackedSignalNames: trackedNames,
    trackedQueryNames: trackedQueryNames,
    annotationName: extractNameArgument(annotation),
    debounce: extractDebounceArgument(annotation, source),
    useRefreshing: extractUseRefreshingArgument(annotation),
  );
}

/// Returns the first `@<className>(...)` annotation in [metadata], or `null`.
///
/// Package-public so the target validator can reuse the same matcher on
/// every declaration kind. Use the [solidStateName] or [solidEffectName]
/// constants for [className] rather than bare strings.
Annotation? findAnnotationByName(
  String className,
  NodeList<Annotation> metadata,
) {
  for (final ann in metadata) {
    if (ann.name.name == className) return ann;
  }
  return null;
}

/// Returns the [Expression] passed for `<label>: <expr>` on [annotation], or
/// `null` if the annotation has no named argument with that label.
Expression? _findNamedArg(Annotation annotation, String label) {
  final args = annotation.arguments?.arguments ?? const [];
  for (final arg in args) {
    if (arg is NamedExpression && arg.name.label.name == label) {
      return arg.expression;
    }
  }
  return null;
}

/// Extracts the string value of a `name: '…'` named argument on [annotation],
/// or `null` if the annotation has no such argument. Shared between the field
/// and getter readers so both reactive shapes thread the debug name
/// uniformly.
String? extractNameArgument(Annotation annotation) {
  final expr = _findNamedArg(annotation, 'name');
  return expr is SimpleStringLiteral ? expr.value : null;
}

/// Returns the emit-ready source text of the `debounce:` argument's
/// expression on `@SolidQuery(debounce: …)`, or `null` if the annotation has
/// no `debounce:` argument.
///
/// In the unresolved AST that the builder operates on, `Duration(...)` (no
/// keyword) parses as a [MethodInvocation] because the parser cannot tell
/// it's a constructor call without semantic resolution; `const Duration(...)`
/// parses as an [InstanceCreationExpression] because the keyword
/// disambiguates. Annotation argument context is implicit-const, so the
/// canonical user shape lacks `const`; both no-keyword shapes therefore
/// receive a `const ` prefix so the lowered
/// `Resource(... debounceDelay: <text>, ...)` arg compiles in its non-const
/// constructor-arg context. Other shapes (`const Duration(...)`, identifier
/// references like a const-declared `_myDebounce`) emit verbatim.
String? extractDebounceArgument(Annotation annotation, String source) {
  final expr = _findNamedArg(annotation, 'debounce');
  if (expr == null) return null;
  final raw = source.substring(expr.offset, expr.end);
  final implicitConst =
      expr is MethodInvocation ||
      (expr is InstanceCreationExpression && expr.keyword == null);
  return implicitConst ? 'const $raw' : raw;
}

/// Returns `true`/`false` for `useRefreshing: <bool>` on
/// `@SolidQuery(useRefreshing: …)`, or `null` if the annotation has no
/// `useRefreshing:` argument. The `null` case is distinct from the
/// annotation default (`true`) at the model layer, but both omit the
/// emitted `useRefreshing:` argument (the upstream `Resource` default is
/// `true`, so emitting it would be redundant noise).
bool? extractUseRefreshingArgument(Annotation annotation) {
  final expr = _findNamedArg(annotation, 'useRefreshing');
  return expr is BooleanLiteral ? expr.value : null;
}
