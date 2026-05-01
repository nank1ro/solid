import 'package:meta/meta.dart';

/// Parsed description of one `@SolidEnvironment`-annotated field.
///
/// Populated by `annotation_reader.dart` from unresolved AST and consumed by
/// the rewriters (currently `stateless_rewriter.dart` and
/// `state_class_rewriter.dart`). All string members are the raw source text of
/// the corresponding AST node — no normalization. Mirror of `FieldModel` for
/// the `@SolidEnvironment` field-synthesis path: every annotated field lowers
/// to a `late final <fieldName> = context.read<<typeText>>();` line on the
/// host's synthesized (or in-place) `State<X>` subclass per SPEC §4.9.
///
/// Unlike `FieldModel` this carries no `initializerText`, no `isLate`, and no
/// `isNullable` because:
///
///  * `@SolidEnvironment` rejects fields with initializers (SPEC §3.6 — the
///    initializer is what the lowered `context.read<T>()` synthesizes),
///  * the `late` modifier is mandatory on the source field (the validator
///    rejects non-`late`), so it doesn't need to thread through the model,
///  * type nullability has no effect on emission — the lowered shape
///    `context.read<T>()` already returns the declared type as-is.
@immutable
class EnvironmentModel {
  /// Creates an [EnvironmentModel] describing an annotated field.
  const EnvironmentModel({required this.fieldName, required this.typeText});

  /// Declared identifier of the field (e.g. `'logger'`).
  final String fieldName;

  /// Raw source text of the declared type annotation (e.g. `'Logger'`,
  /// `'Counter'`, `'AuthService'`). The lowered field emits
  /// `context.read<<typeText>>()` so the type text appears verbatim inside the
  /// type-argument angle brackets.
  ///
  /// Empty string only if the field has no declared type — not expected for
  /// `@SolidEnvironment` fields per SPEC §3.6 (the type IS the DI key, so a
  /// missing type is rejected by `validateSolidEnvironmentTargets`).
  final String typeText;
}
