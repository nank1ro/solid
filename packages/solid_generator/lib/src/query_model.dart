import 'package:meta/meta.dart';

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
/// `Resource<T>` type argument, (b) queries preserve the [bodyKeyword] to
/// splice into the emitted closure, and (c) queries do NOT enforce a
/// reactive-deps requirement (SPEC §3.5 — a query body MAY have zero reactive
/// reads).
@immutable
class QueryModel {
  /// Creates a [QueryModel] describing an annotated method.
  const QueryModel({
    required this.methodName,
    required this.bodyText,
    required this.isBlockBody,
    required this.innerTypeText,
    this.bodyKeyword = '',
    this.isStream = false,
    this.trackedSignalNames = const [],
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

  /// Source text of the inner type `T` peeled from the method's `Future<T>` /
  /// `Stream<T>` return type. Used as the `Resource<T>` type argument in
  /// lowered output.
  final String innerTypeText;

  /// Source method's body modifier keyword — one of `'async'`, `'async*'`, or
  /// `''` (empty for sync-bodied Stream queries like `Stream<T> m() => …;` or
  /// `Stream<T> m() { return …; }`). Spliced verbatim into the closure
  /// signature so the lowered fetcher preserves the original body semantics.
  final String bodyKeyword;

  /// True when the source return type is `Stream<T>`; false for `Future<T>`.
  /// Drives the choice between `Resource<T>(...)` and `Resource<T>.stream(...)`
  /// in the emitter.
  final bool isStream;

  /// Names of `@SolidState` field/getter identifiers read in the query body's
  /// tracked position, in source-first-appearance order, deduplicated. Drives
  /// M5-10 source-Computed synthesis:
  ///
  /// * **0 names** → no `source:` argument on the lowered Resource.
  /// * **1 name** → that Signal/Computed is passed directly as `source:`
  ///   (SPEC §4.8 rule 5: a single-Signal Computed wrapper would be a no-op).
  /// * **≥ 2 names** → a synthesized Record-Computed field
  ///   `late final _<methodName>Source = Computed<(T1, T2, …)>(...)` is
  ///   emitted before the Resource, and the Resource gets
  ///   `source: _<methodName>Source,`. The closure body is
  ///   `() => (s1.value, s2.value, …)`.
  ///
  /// The list is populated by `readSolidQueryMethod` from the body-rewriter's
  /// [`ValueRewriteResult.trackedReadNames`]; a query body with zero reactive
  /// reads is permitted (SPEC §3.5 waives the `@SolidEffect` deps requirement).
  final List<String> trackedSignalNames;

  /// True when [trackedSignalNames] has two or more names — i.e. the rewriter
  /// must synthesize a Record-Computed `source:` field. Single-name queries
  /// pass the Signal directly; zero-name queries omit `source:` entirely.
  bool get needsSourceComputed => trackedSignalNames.length >= 2;

  /// Conventional name of the synthesized Record-Computed source field
  /// emitted when [needsSourceComputed] is true. Single source of truth shared
  /// by `emitQuerySourceField`, `emitResourceField`, and the dispose-name
  /// list pushes in every rewriter.
  String get sourceFieldName => '_${methodName}Source';

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
