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
}
