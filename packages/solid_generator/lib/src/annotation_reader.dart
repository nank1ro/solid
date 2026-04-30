import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/effect_model.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/query_model.dart';
import 'package:solid_generator/src/transformation_error.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// Name of the `@SolidState` annotation class.
///
/// Matching is textual on the unresolved AST (see SPEC Section 5.4 — type
/// resolution is required for `.value` rewriting, but annotation detection is
/// acceptable on names because the user must import `solid_annotations` to use
/// `@SolidState` at all).
///
/// Exposed package-publicly so the target validator (SPEC Section 3.1
/// rejections) can match the same identifier on non-field declarations.
const String solidStateName = 'SolidState';

/// Name of the `@SolidEffect` annotation class. Same matching contract as
/// [solidStateName] (textual on unresolved AST).
const String solidEffectName = 'SolidEffect';

/// Name of the `@SolidQuery` annotation class. Same matching contract as
/// [solidStateName] (textual on unresolved AST).
const String solidQueryName = 'SolidQuery';

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
    // non-nullable at the outer level (SPEC Section 4.3).
    isNullable: type?.question != null,
  );
}

/// Reads a `@SolidState(...)` annotation on the getter [decl] and returns a
/// [GetterModel]. Returns `null` when the method is not an `@SolidState`
/// getter; non-getter methods and static getters are filtered out earlier by
/// `validateSolidStateTargets`, but this reader is defensive and skips them
/// silently as well.
///
/// The getter body is rewritten in place per SPEC §5.1: any reference to a
/// name in [reactiveFields] receives `.value`. Both expression-body
/// (`get x => <expr>;` — SPEC §4.5) and block-body (`get x { ... }` —
/// SPEC §4.6) shapes are supported. Other body kinds (abstract / native) are
/// rejected with a [CodeGenerationError].
GetterModel? readSolidStateGetter(
  MethodDeclaration decl,
  Set<String> reactiveFields,
  String source,
) {
  if (!decl.isGetter || decl.isStatic) return null;
  final annotation = findAnnotationByName(solidStateName, decl.metadata);
  if (annotation == null) return null;

  final returnType = decl.returnType;
  final typeText = returnType == null
      ? ''
      : source.substring(returnType.offset, returnType.end);

  final body = decl.body;
  final getterName = decl.name.lexeme;
  // Getters do not need tracked names; no `source:` wiring.
  final (:bodyText, :isBlockBody, trackedNames: _) = _readReactiveBody(
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
/// the dedup'd source-order list of `@SolidState` field/getter names read in
/// tracked position inside the body. Shared between `readSolidStateGetter`,
/// `readSolidEffectMethod`, and `readSolidQueryMethod`: all three
/// discriminate `ExpressionFunctionBody` vs `BlockFunctionBody`, run the
/// SPEC §5.1 `.value` rewrite, and reject abstract/native bodies. The
/// zero-deps check (SPEC §4.5 / §3.4) fires only when [emptyDepsError] is
/// non-null; queries pass `null` because SPEC §3.5 explicitly waives the
/// reactive-deps requirement. Error wording differs per caller
/// (SPEC §4.5 vs §3.4 vs §3.5) — pass it in.
///
/// `trackedReadOffsets` from the rewrite are intentionally discarded here —
/// SignalBuilder placement is a `build()` concern, not a `Computed` /
/// `Effect` / `Resource` body concern. `trackedNames` is consumed only by
/// `readSolidQueryMethod` to wire the Resource's `source:` argument; getter
/// and effect callers destructure it into `_`.
({String bodyText, bool isBlockBody, List<String> trackedNames})
_readReactiveBody(
  FunctionBody body,
  Set<String> reactiveFields,
  String source, {
  required String memberName,
  required String? emptyDepsError,
  required String unsupportedBodyError,
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
  final result = collectValueEdits(node, reactiveFields, source);
  if (emptyDepsError != null && result.edits.isEmpty) {
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
  );
}

/// Reads a `@SolidEffect(...)` annotation on the method [decl] and returns an
/// [EffectModel]. Returns `null` when [decl] is not an `@SolidEffect`-bearing
/// instance method; getters, setters, and static methods are filtered out
/// here defensively (the M4-04 target validator rejects them with a clearer
/// error before this reader runs).
///
/// The method body is rewritten in place per SPEC §5.1: any reference to a
/// name in [reactiveFields] receives `.value`. Both expression-body
/// (`void m() => <expr>;`) and block-body (`void m() { ... }`) shapes are
/// supported per SPEC §4.7. Other body kinds (abstract / native) are
/// rejected with a [CodeGenerationError].
///
/// SPEC §3.4 reactive-deps requirement: an Effect with zero reactive
/// dependencies is rejected with the SPEC-defined message
/// `"effect '<name>' has no reactive dependencies"`. M4-05 pins this
/// behavior with a dedicated rejection test.
EffectModel? readSolidEffectMethod(
  MethodDeclaration decl,
  Set<String> reactiveFields,
  String source,
) {
  if (decl.isGetter || decl.isSetter || decl.isStatic) return null;
  final annotation = findAnnotationByName(solidEffectName, decl.metadata);
  if (annotation == null) return null;

  final methodName = decl.name.lexeme;
  // Effects do not need tracked names: the autorun subscribes by running the
  // body eagerly, no explicit `source:` wiring.
  final (:bodyText, :isBlockBody, trackedNames: _) = _readReactiveBody(
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
/// The method body is rewritten in place per SPEC §5.1: any reference to a
/// name in [reactiveFields] receives `.value`. Both expression-body
/// (`Future<T> m() async => …;` / `Stream<T> m() => …;`) and block-body
/// (`Future<T> m() async {…}` / `Stream<T> m() async* {…}` /
/// `Stream<T> m() {…}`) shapes are supported per SPEC §3.5 / §4.8. Other body
/// kinds (abstract / native) are rejected with a [CodeGenerationError].
///
/// Unlike [readSolidEffectMethod] / [readSolidStateGetter], this reader does
/// NOT enforce a reactive-deps requirement — a query body MAY have zero
/// reactive reads (SPEC §3.5 "No reactive-deps requirement").
QueryModel? readSolidQueryMethod(
  MethodDeclaration decl,
  Set<String> reactiveFields,
  String source,
) {
  if (decl.isGetter || decl.isSetter || decl.isStatic) return null;
  final annotation = findAnnotationByName(solidQueryName, decl.metadata);
  if (annotation == null) return null;
  // Other return types are rejected by `validateSolidQueryTargets` (M5-05);
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
  // emptyDepsError: null — SPEC §3.5 waives the reactive-deps requirement.
  final (:bodyText, :isBlockBody, :trackedNames) = _readReactiveBody(
    decl.body,
    reactiveFields,
    source,
    memberName: methodName,
    emptyDepsError: null,
    unsupportedBodyError:
        '@SolidQuery method must have an expression body (=> ...) or a '
        'block body ({ ... }); abstract and native bodies are not supported',
  );

  return QueryModel(
    methodName: methodName,
    bodyText: bodyText,
    isBlockBody: isBlockBody,
    innerTypeText: innerTypeText,
    bodyKeyword: decl.body.keyword?.lexeme ?? '',
    isStream: returnTypeName == streamLexeme,
    trackedSignalNames: trackedNames,
    annotationName: extractNameArgument(annotation),
  );
}

/// Returns the first `@<className>(...)` annotation in [metadata], or `null`.
///
/// Package-public so the target validator (SPEC §3.1 / §3.4 rejections) can
/// reuse the same matcher on every declaration kind. Use the [solidStateName]
/// or [solidEffectName] constants for [className] rather than bare strings.
Annotation? findAnnotationByName(
  String className,
  NodeList<Annotation> metadata,
) {
  for (final ann in metadata) {
    if (ann.name.name == className) return ann;
  }
  return null;
}

/// Extracts the string value of a `name: '…'` named argument on [annotation],
/// or `null` if the annotation has no such argument. Shared between the field
/// and getter readers so both reactive shapes thread the SPEC §4.4 debug name
/// uniformly.
String? extractNameArgument(Annotation annotation) {
  final args = annotation.arguments?.arguments ?? const [];
  for (final arg in args) {
    if (arg is NamedExpression && arg.name.label.name == 'name') {
      final expr = arg.expression;
      if (expr is SimpleStringLiteral) return expr.value;
    }
  }
  return null;
}
