import 'package:meta/meta.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Parsed description of one `@SolidState`-annotated getter.
///
/// Populated by `annotation_reader.dart` from unresolved AST and consumed by
/// the rewriters (currently `stateless_rewriter.dart`). All string members are
/// the raw source text of the corresponding AST node — except [bodyText],
/// which is the source-substring of the getter body with the SPEC §5.1
/// `.value` rewrites already applied so the emitter can splice it directly
/// into the `Computed<T>(...)` closure.
@immutable
class GetterModel {
  /// Creates a [GetterModel] describing an annotated getter.
  const GetterModel({
    required this.getterName,
    required this.typeText,
    required this.bodyText,
    required this.isBlockBody,
    required this.annotationName,
  });

  /// Declared identifier of the getter (e.g. `'doubleCounter'`).
  final String getterName;

  /// Raw source text of the declared return type (e.g. `'int'`,
  /// `'List<String>'`). Empty string only if the getter has no declared type —
  /// not expected for `@SolidState` getters per SPEC §3.1.
  final String typeText;

  /// Source text of the getter's body with the SPEC §5.1 reactive-read
  /// rewrite already applied. The shape depends on [isBlockBody]:
  ///
  /// * **Expression body** (SPEC §4.5, [isBlockBody] is `false`): the
  ///   rewritten expression text alone — for an input
  ///   `int get doubleCounter => counter * 2;` where `counter` is a sibling
  ///   `@SolidState` field, this is the string `'counter.value * 2'`. The
  ///   emitter wraps it in `() => <text>`.
  /// * **Block body** (SPEC §4.6, [isBlockBody] is `true`): the rewritten
  ///   block including its braces — for an input
  ///   `String get summary { final c = counter; return 'count is $c'; }`,
  ///   this is the string `'{ final c = counter.value; return \'count is \$c\'; }'`.
  ///   The emitter wraps it in `() <text>`.
  final String bodyText;

  /// True when the source getter has a block body (`get x { ... }`); false
  /// for an expression body (`get x => <expr>;`). Determines how the emitter
  /// shapes the closure passed to `Computed<T>(...)`.
  final bool isBlockBody;

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
