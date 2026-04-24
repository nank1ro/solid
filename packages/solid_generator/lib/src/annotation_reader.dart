import 'package:analyzer/dart/ast/ast.dart';
import 'package:solid_generator/src/field_model.dart';

/// Name of the annotation class this reader looks for.
///
/// Matching is textual on the unresolved AST (see SPEC Section 5.4 — type
/// resolution is required for `.value` rewriting, but annotation detection is
/// acceptable on names because the user must import `solid_annotations` to use
/// `@SolidState` at all).
const String _solidStateName = 'SolidState';

/// Reads a `@SolidState(...)` annotation on [decl] and returns a [FieldModel].
///
/// Returns `null` if [decl] carries no `@SolidState` annotation. The raw
/// [source] is passed in so each string member of the returned [FieldModel]
/// can be extracted verbatim via `source.substring(offset, end)`.
FieldModel? readSolidStateField(FieldDeclaration decl, String source) {
  final annotation = _findSolidStateAnnotation(decl);
  if (annotation == null) return null;

  final varList = decl.fields;
  final type = varList.type;
  final variable = varList.variables.first;

  return FieldModel(
    fieldName: variable.name.lexeme,
    typeText: type == null ? '' : source.substring(type.offset, type.end),
    isNullable: _typeIsNullable(type),
    isLate: varList.isLate,
    initializerText: variable.initializer == null
        ? ''
        : source.substring(
            variable.initializer!.offset,
            variable.initializer!.end,
          ),
    annotationName: _extractNameArgument(annotation),
  );
}

/// Returns the first `@SolidState(...)` annotation on [decl], or `null`.
Annotation? _findSolidStateAnnotation(FieldDeclaration decl) {
  for (final ann in decl.metadata) {
    if (ann.name.name == _solidStateName) return ann;
  }
  return null;
}

/// Whether [type] ends with `?`.
///
/// Uses `NamedType.question` for the common case; returns `false` if the type
/// annotation is absent (fields without a declared type are not emitted by M1
/// — see SPEC Section 3.1).
bool _typeIsNullable(TypeAnnotation? type) {
  if (type is NamedType) return type.question != null;
  return false;
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
