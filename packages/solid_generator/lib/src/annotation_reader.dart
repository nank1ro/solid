import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/field_model.dart';

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
    annotationName: _extractNameArgument(annotation),
    isLate: varList.isLate,
    // `TypeAnnotation.question` is the `?` token at the top level of the
    // declared type. Using it (vs. a `typeText.endsWith('?')` heuristic)
    // correctly classifies nested-nullable types like `List<int?>` as
    // non-nullable at the outer level (SPEC Section 4.3).
    isNullable: type?.question != null,
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
/// or `null` if the annotation has no such argument.
String? _extractNameArgument(Annotation annotation) {
  final args = annotation.arguments?.arguments ?? const [];
  for (final arg in args) {
    if (arg is NamedExpression && arg.name.label.name == 'name') {
      final expr = arg.expression;
      if (expr is SimpleStringLiteral) return expr.value;
    }
  }
  return null;
}
