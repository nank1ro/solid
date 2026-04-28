import 'package:meta/meta.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Parsed description of one `@SolidEffect`-annotated method.
///
/// Populated by `annotation_reader.dart` from unresolved AST and consumed by
/// the rewriters (currently `stateless_rewriter.dart`). All string members are
/// the raw source text of the corresponding AST node — except [bodyText],
/// which is the source-substring of the method body with the SPEC §5.1
/// `.value` rewrites already applied so the emitter can splice it directly
/// into the `Effect(...)` closure.
///
/// Mirrors `GetterModel` for the parallel `@SolidState` getter → `Computed`
/// lowering (SPEC §4.5). The two models share an identical body-rewrite
/// contract; the only differences are (a) effects have no return type, and
/// (b) the emitted constructor is `Effect(...)` instead of `Computed<T>(...)`.
@immutable
class EffectModel {
  /// Creates an [EffectModel] describing an annotated method.
  const EffectModel({
    required this.methodName,
    required this.bodyText,
    required this.isBlockBody,
    required this.annotationName,
  });

  /// Declared identifier of the method (e.g. `'logCounter'`).
  final String methodName;

  /// Source text of the method's body with the SPEC §5.1 reactive-read
  /// rewrite already applied. The shape depends on [isBlockBody]:
  ///
  /// * **Expression body** (SPEC §4.7, [isBlockBody] is `false`): the
  ///   rewritten expression text alone — for an input
  ///   `void logCounter() => print(counter);` where `counter` is a sibling
  ///   `@SolidState` field, this is the string `'print(counter.value)'`. The
  ///   emitter wraps it in `() => <text>`.
  /// * **Block body** (SPEC §4.7, [isBlockBody] is `true`): the rewritten
  ///   block including its braces — for an input
  ///   `void logCounter() { print('Counter: $counter'); }`,
  ///   this is the string `"{ print('Counter: \${counter.value}'); }"`.
  ///   The emitter wraps it in `() <text>`.
  final String bodyText;

  /// True when the source method has a block body (`void m() { ... }`); false
  /// for an expression body (`void m() => <expr>;`). Determines how the
  /// emitter shapes the closure passed to `Effect(...)`.
  final bool isBlockBody;

  /// Value of the `name:` argument on `@SolidEffect(name: '…')`, or `null` if
  /// the annotation had no `name:` argument (SPEC §4.7).
  final String? annotationName;
}

/// Throws [CodeGenerationError] when [solidEffects] is non-empty, naming the
/// first offending method and the [classKindLabel] (`'plain class'`,
/// `'existing State<X> subclass'`, …) of the rewriter that has not yet
/// implemented method→`Effect` lowering.
///
/// Mirrors `rejectIfGettersNotYetSupported` in `getter_model.dart`: the
/// message template lives in one place so two rewriters' "not yet supported"
/// errors can never drift. The StatelessWidget path lands in M4-01; the
/// `State<X>` and plain-class paths land in M4-08.
void rejectIfEffectsNotYetSupported(
  List<EffectModel> solidEffects,
  String classKindLabel,
  String className,
) {
  if (solidEffects.isEmpty) return;
  throw CodeGenerationError(
    '@SolidEffect on $classKindLabel is not yet supported '
    '(will land in M4-08); '
    'offending method: ${solidEffects.first.methodName}',
    null,
    className,
  );
}
