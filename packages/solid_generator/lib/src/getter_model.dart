import 'package:meta/meta.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Parsed description of one `@SolidState`-annotated getter.
///
/// Populated by `annotation_reader.dart` from unresolved AST and consumed by
/// the rewriters (currently `stateless_rewriter.dart`). All string members are
/// the raw source text of the corresponding AST node — except
/// [bodyExpressionText], which is the source-substring of the getter body
/// expression with the SPEC §5.1 `.value` rewrites already applied so the
/// emitter can splice it directly into a `Computed<T>(() => …)` template.
@immutable
class GetterModel {
  /// Creates a [GetterModel] describing an annotated getter.
  const GetterModel({
    required this.getterName,
    required this.typeText,
    required this.bodyExpressionText,
    required this.annotationName,
  });

  /// Declared identifier of the getter (e.g. `'doubleCounter'`).
  final String getterName;

  /// Raw source text of the declared return type (e.g. `'int'`,
  /// `'List<String>'`). Empty string only if the getter has no declared type —
  /// not expected for `@SolidState` getters per SPEC §3.1.
  final String typeText;

  /// Source text of the getter's expression body with the SPEC §5.1
  /// reactive-read rewrite already applied. For an input
  /// `int get doubleCounter => counter * 2;` where `counter` is a sibling
  /// `@SolidState` field, this is the string `'counter.value * 2'`.
  ///
  /// M2-01 only supports expression-body getters (`get x => <expr>;`). The
  /// block-body form (SPEC §4.6) is rejected by `readSolidStateGetter` and
  /// scheduled for M2-01b.
  final String bodyExpressionText;

  /// Value of the `name:` argument on `@SolidState(name: '…')`, or `null` if
  /// the annotation had no `name:` argument (SPEC §4.4).
  final String? annotationName;
}

/// Throws [CodeGenerationError] when [solidGetters] is non-empty, naming the
/// first offending getter and the [classKindLabel] (`'plain class'`,
/// `'existing State<X> subclass'`, …) of the rewriter that has not yet
/// implemented getter→`Computed` lowering.
///
/// Mirrors the `_reject` pattern in `target_validator.dart`: the message
/// template lives in one place so two rewriters' "not yet supported" errors
/// can never drift.
void rejectIfGettersNotYetSupported(
  List<GetterModel> solidGetters,
  String classKindLabel,
  String className,
) {
  if (solidGetters.isEmpty) return;
  throw CodeGenerationError(
    '@SolidState getter on $classKindLabel is not yet supported '
    '(will land in a later M2 TODO); '
    'offending getter: ${solidGetters.first.getterName}',
    null,
    className,
  );
}
