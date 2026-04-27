import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/field_model.dart';
import 'package:solid_generator/src/getter_model.dart';
import 'package:solid_generator/src/transformation_error.dart';
import 'package:solid_generator/src/value_rewriter.dart';

/// Name of the annotation class this reader looks for.
///
/// Matching is textual on the unresolved AST (see SPEC Section 5.4 — type
/// resolution is required for `.value` rewriting, but annotation detection is
/// acceptable on names because the user must import `solid_annotations` to use
/// `@SolidState` at all).
///
/// Exposed package-publicly so the target validator (SPEC Section 3.1
/// rejections) can match the same identifier on non-field declarations.
const String solidStateName = 'SolidState';

/// Reads a `@SolidState(...)` annotation on [decl] and returns a [FieldModel].
///
/// Returns `null` if [decl] carries no `@SolidState` annotation. The raw
/// [source] is passed in so each string member of the returned [FieldModel]
/// can be extracted verbatim via `source.substring(offset, end)`.
FieldModel? readSolidStateField(FieldDeclaration decl, String source) {
  final annotation = findSolidStateAnnotation(decl.metadata);
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
  final annotation = findSolidStateAnnotation(decl.metadata);
  if (annotation == null) return null;

  final returnType = decl.returnType;
  final typeText = returnType == null
      ? ''
      : source.substring(returnType.offset, returnType.end);

  final body = decl.body;
  final getterName = decl.name.lexeme;
  final String bodyText;
  final bool isBlockBody;
  if (body is ExpressionFunctionBody) {
    bodyText = _rewriteGetterBody(
      body.expression,
      reactiveFields,
      source,
      getterName,
    );
    isBlockBody = false;
  } else if (body is BlockFunctionBody) {
    bodyText = _rewriteGetterBody(
      body.block,
      reactiveFields,
      source,
      getterName,
    );
    isBlockBody = true;
  } else {
    throw CodeGenerationError(
      '@SolidState getter must have an expression body (=> ...) or a '
      'block body ({ ... }); abstract and native bodies are not supported',
      null,
      getterName,
    );
  }

  return GetterModel(
    getterName: getterName,
    typeText: typeText,
    bodyText: bodyText,
    isBlockBody: isBlockBody,
    annotationName: extractNameArgument(annotation),
  );
}

/// Returns the source range covered by [node], with SPEC §5.1 reactive-read
/// rewrites applied to every identifier in [reactiveFields]. Used for both
/// the expression-body (`Expression`) and block-body (`Block`) getter
/// shapes; the resulting text is spliced into the `Computed<T>(() ...)`
/// closure by the emitter. `trackedReadOffsets` are intentionally ignored —
/// SignalBuilder placement is a `build()` concern, not a `Computed` body
/// concern.
///
/// Throws [CodeGenerationError] for SPEC §4.5: a `Computed` with zero
/// reactive dependencies would never invalidate, so an empty edit set is
/// surfaced as a build error instead of a useless `Computed`.
String _rewriteGetterBody(
  AstNode node,
  Set<String> reactiveFields,
  String source,
  String getterName,
) {
  final result = collectValueEdits(node, reactiveFields, source);
  if (result.edits.isEmpty) {
    throw CodeGenerationError(
      "getter '$getterName' has no reactive dependencies; "
      'use `final` or a plain getter instead of `@SolidState`',
      null,
      getterName,
    );
  }
  return applyEditsToRange(
    source.substring(node.offset, node.end),
    result.edits,
    node.offset,
  );
}

/// Returns the first `@SolidState(...)` annotation in [metadata], or `null`.
///
/// Package-public so the target validator (SPEC §3.1 rejections) can reuse
/// the same matcher on `MethodDeclaration` and `FunctionDeclaration` metadata.
Annotation? findSolidStateAnnotation(NodeList<Annotation> metadata) {
  for (final ann in metadata) {
    if (ann.name.name == solidStateName) return ann;
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
