import 'package:meta/meta.dart';
import 'package:solid_generator/src/transformation_error.dart';

/// Parsed description of one `@SolidQuery`-annotated method.
///
/// Populated by `annotation_reader.dart` from unresolved AST and consumed by
/// the rewriters (currently `stateless_rewriter.dart`). All string members are
/// the raw source text of the corresponding AST node — except [bodyText],
/// which is the source-substring of the method body with the SPEC §5.1
/// `.value` rewrites already applied so the emitter can splice it directly
/// into the `Resource(...)` fetcher closure.
///
/// Mirrors `EffectModel` for the parallel `@SolidEffect` method → `Effect`
/// lowering (SPEC §4.7). The two models share an identical body-rewrite
/// contract; the differences are (a) queries carry an [innerTypeText] for the
/// `Resource<T>` type argument, (b) queries preserve the [isAsyncBody]
/// keyword to splice into the emitted closure, and (c) queries do NOT enforce
/// a reactive-deps requirement (SPEC §3.5 — a query body MAY have zero
/// reactive reads).
@immutable
class QueryModel {
  /// Creates a [QueryModel] describing an annotated method.
  const QueryModel({
    required this.methodName,
    required this.bodyText,
    required this.isBlockBody,
    required this.isAsyncBody,
    required this.innerTypeText,
    this.isStream = false,
    this.debounce,
    this.useRefreshing,
    this.annotationName,
  });

  /// Declared identifier of the method (e.g. `'fetchData'`). Used as the
  /// public field name on the lowered class — no underscore prefix per
  /// SPEC §4.8 rule 1.
  final String methodName;

  /// Source text of the method's body with the SPEC §5.1 reactive-read
  /// rewrite already applied. The shape depends on [isBlockBody]:
  ///
  /// * **Expression body** (SPEC §4.8, [isBlockBody] is `false`): the
  ///   rewritten expression text alone — for an input
  ///   `Future<int> fetchOne() async => 1;`, this is the string `'1'`.
  ///   The emitter wraps it in `() async => <text>`.
  /// * **Block body** (SPEC §4.8, [isBlockBody] is `true`): the rewritten
  ///   block including its braces — for an input
  ///   `Future<int> fetchOne() async { return 1; }`, this is
  ///   `'{ return 1; }'`. The emitter wraps it in `() async <text>`.
  final String bodyText;

  /// True when the source method has a block body (`Future<T> m() async {…}`);
  /// false for an expression body (`Future<T> m() async => …;`). Determines
  /// how the emitter shapes the closure passed to `Resource(...)`.
  final bool isBlockBody;

  /// True when the source method's body keyword is `async` (Future form) or
  /// `async*` (Stream form). The emitter splices `async ` into the closure
  /// signature so the lowered fetcher preserves the async semantics.
  ///
  /// In M5-01 only Future + `async` is reachable; the Stream + plain-bodied
  /// path lands in M5-02 where this flag stays `false`.
  final bool isAsyncBody;

  /// Source text of the inner type `T` peeled from the method's `Future<T>`
  /// (or in M5-02, `Stream<T>`) return type. Used as the `Resource<T>` type
  /// argument in lowered output.
  final String innerTypeText;

  /// True when the source return type is `Stream<T>`; false for `Future<T>`.
  /// Reserved in M5-01 for the M5-02 Stream-form branch in `emitResourceField`.
  final bool isStream;

  /// Value of the `debounce:` argument on `@SolidQuery(debounce: …)`, or
  /// `null` if the annotation had no `debounce:` argument. Reserved in M5-01
  /// for M5-11 — present on the model so future readers don't reshape it.
  final Duration? debounce;

  /// Value of the `useRefreshing:` argument on `@SolidQuery(useRefreshing: …)`,
  /// or `null` if the annotation had no `useRefreshing:` argument. Reserved
  /// in M5-01 for M5-11 — present on the model so future readers don't
  /// reshape it.
  final bool? useRefreshing;

  /// Value of the `name:` argument on `@SolidQuery(name: '…')`, or `null` if
  /// the annotation had no `name:` argument (SPEC §3.5 / §4.8 rule 8).
  final String? annotationName;
}

/// Throws [CodeGenerationError] when [solidQueries] is non-empty, naming the
/// first offending method and the [classKindLabel] (`'plain class'`,
/// `'existing State<X> subclass'`, …) of the rewriter that has not yet
/// implemented method→`Resource` lowering.
///
/// Mirrors `rejectIfEffectsNotYetSupported` in `effect_model.dart`: the
/// message template lives in one place so two rewriters' "not yet supported"
/// errors can never drift. The StatelessWidget path lands in M5-01; the
/// `State<X>` and plain-class paths land in M5-08 / M5-09.
void rejectIfQueriesNotYetSupported(
  List<QueryModel> solidQueries,
  String classKindLabel,
  String className,
) {
  if (solidQueries.isEmpty) return;
  throw CodeGenerationError(
    '@SolidQuery on $classKindLabel is not yet supported '
    '(will land in M5-08/M5-09); '
    'offending method: ${solidQueries.first.methodName}',
    null,
    className,
  );
}
