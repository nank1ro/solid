import 'package:meta/meta.dart';

/// Parsed description of one `@SolidState`-annotated field.
///
/// Populated by `annotation_reader.dart` from unresolved AST and consumed by
/// the rewriters (currently `stateless_rewriter.dart`). All string members are
/// the raw source text of the corresponding AST node — no normalization.
@immutable
class FieldModel {
  /// Creates a [FieldModel] describing an annotated field.
  const FieldModel({
    required this.fieldName,
    required this.typeText,
    required this.initializerText,
    required this.annotationName,
    required this.isLate,
    required this.isNullable,
  });

  /// Declared identifier of the field (e.g. `'counter'`).
  final String fieldName;

  /// Raw source text of the declared type annotation (e.g. `'int'`, `'int?'`,
  /// `'List<String>'`). Empty string only if the field has no declared type —
  /// not expected for `@SolidState` fields per SPEC Section 3.1.
  final String typeText;

  /// Raw source text of the initializer expression (e.g. `'0'`), or empty
  /// string if the field has no initializer (valid for `late` or nullable
  /// fields — see SPEC Section 4.2 / 4.3).
  final String initializerText;

  /// Value of the `name:` argument on `@SolidState(name: '…')`, or `null` if
  /// the annotation had no `name:` argument (SPEC Section 4.4).
  final String? annotationName;

  /// Whether the source field was declared with the `late` modifier (SPEC
  /// Section 4.2). Preserved verbatim on the emitted `Signal` field so that
  /// `Signal` construction is deferred until first access.
  final bool isLate;

  /// Whether the field's declared top-level type is nullable (SPEC Section
  /// 4.3). True when the type annotation ends with `?` (e.g. `int?`,
  /// `List<int>?`); false for non-nullable types (e.g. `int`, `List<int?>` —
  /// the inner `?` does not make the outer type nullable). Determined from
  /// the analyzer's `TypeAnnotation.question` token so nested generics are
  /// handled correctly. A nullable field without an initializer emits
  /// `Signal<T?>(null, name: '…')` rather than `Signal<T>.lazy(…)`.
  final bool isNullable;
}
