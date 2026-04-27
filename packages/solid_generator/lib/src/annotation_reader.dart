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
/// The getter body's expression is rewritten in place per SPEC §5.1: any
/// reference to a name in [reactiveFields] receives `.value`. M2-01 supports
/// expression-body getters only (`get x => <expr>;`); a block-body getter is
/// rejected with a clear error pointing at the M2-01b TODO.
GetterModel? readSolidStateGetter(
  MethodDeclaration decl,
  Set<String> reactiveFields,
  String source,
) {
  if (!decl.isGetter || decl.isStatic) return null;
  final annotation = findSolidStateAnnotation(decl.metadata);
  if (annotation == null) return null;

  final body = decl.body;
  if (body is! ExpressionFunctionBody) {
    throw CodeGenerationError(
      '@SolidState block-body getter is not yet supported '
      '(scheduled for TODO M2-01b)',
      null,
      decl.name.lexeme,
    );
  }

  final returnType = decl.returnType;
  final typeText = returnType == null
      ? ''
      : source.substring(returnType.offset, returnType.end);

  // SPEC §5.1: rewrite reactive reads inside the body. `trackedReadOffsets`
  // are intentionally ignored — SignalBuilder placement is a `build()`
  // concern, not a `Computed` body concern.
  final expr = body.expression;
  final result = collectValueEdits(expr, reactiveFields, source);
  final bodyExpressionText = applyEditsToRange(
    source.substring(expr.offset, expr.end),
    result.edits,
    expr.offset,
  );

  return GetterModel(
    getterName: decl.name.lexeme,
    typeText: typeText,
    bodyExpressionText: bodyExpressionText,
    annotationName: extractNameArgument(annotation),
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
