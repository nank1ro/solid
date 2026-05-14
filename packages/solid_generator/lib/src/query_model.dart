import 'package:meta/meta.dart';

/// One cross-class signal dependency reached through an `@SolidEnvironment`
/// receiver — `<envField>.<name>` shape. Shared by [QueryModel] and
/// `ValueRewriteResult.trackedCrossClassReadNames` so both layers carry the
/// same shape end-to-end.
typedef CrossClassDep = ({String envField, String name});

/// Parsed description of one `@SolidQuery`-annotated method.
///
/// Populated by `annotation_reader.dart` from unresolved AST and consumed by
/// the rewriters (currently `stateless_rewriter.dart`). All string members are
/// the raw source text of the corresponding AST node — except [bodyText],
/// which is the source-substring of the method body with the `.value`
/// rewrites already applied so the emitter can splice it directly
/// into the `Resource(...)` fetcher closure.
///
/// Mirrors `EffectModel` for the parallel `@SolidEffect` method → `Effect`
/// lowering. The two models share an identical body-rewrite
/// contract; the differences are (a) queries carry an [innerTypeText] for the
/// `Resource<T>` type argument, (b) queries preserve the [bodyKeyword] to
/// splice into the emitted closure, and (c) queries do NOT enforce a
/// reactive-deps requirement (a query body MAY have zero reactive reads).
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
    this.trackedQueryNames = const [],
    this.trackedCrossClassSignalNames = const [],
    this.debounce,
    this.useRefreshing,
    this.annotationName,
  });

  /// Declared identifier of the method (e.g. `'fetchData'`). Used as the
  /// public field name on the lowered class — no underscore prefix (a single
  /// emitted declaration per query).
  final String methodName;

  /// Source text of the method's body with the reactive-read
  /// rewrite already applied. The shape depends on [isBlockBody]:
  ///
  /// * **Expression body** ([isBlockBody] is `false`): the
  ///   rewritten expression text alone — for an input
  ///   `Future<int> fetchOne() async => 1;`, this is the string `'1'`.
  ///   The emitter wraps it in `() async => <text>`.
  /// * **Block body** ([isBlockBody] is `true`): the rewritten
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
  /// source-Computed synthesis together with [trackedQueryNames]:
  ///
  /// * **0 deps total** → no `source:` argument on the lowered Resource.
  /// * **1 dep total** → the Signal/Computed/Resource is passed directly as
  ///   `source:` (a single-observable Computed wrapper would be a no-op).
  /// * **≥ 2 deps total** → a synthesized Record-Computed field
  ///   `late final _<methodName>Source = Computed<(E1, E2, …)>(...)` is
  ///   emitted before the Resource, and the Resource gets
  ///   `source: _<methodName>Source,`. State elements contribute element
  ///   type `T` and read expression `<name>.value`; query elements
  ///   contribute element type `ResourceState<T>` and read expression
  ///   `<name>.state`.
  ///
  /// The list is populated by `readSolidQueryMethod` from the body-rewriter's
  /// [`ValueRewriteResult.trackedReadNames`]; a query body with zero reactive
  /// reads is permitted (`@SolidQuery` waives the `@SolidEffect` deps
  /// requirement).
  final List<String> trackedSignalNames;

  /// Names of same-class `@SolidQuery` methods invoked as zero-arg calls in
  /// the query body's tracked position, in source-first-appearance order,
  /// deduplicated. Disjoint from [trackedSignalNames]; combined dep count
  /// drives the source-synthesis branches (zero / one / many) —
  /// see [totalTrackedDeps].
  ///
  /// The list is populated by `readSolidQueryMethod` from the body-rewriter's
  /// [`ValueRewriteResult.trackedQueryNames`]. A self-cycle (this query's own
  /// name) never appears in the list because `readSolidQueryMethod` excludes
  /// the current method from the per-class set passed to the rewriter, and
  /// rejects self-cycles upstream with a clear error.
  final List<String> trackedQueryNames;

  /// Cross-class `@SolidState` dependencies read in the query body via an
  /// `@SolidEnvironment` receiver — `(envField, signalName)` pairs in
  /// source-first-appearance order, deduplicated. Drives `Resource.source:`
  /// synthesis the same way [trackedSignalNames] does: a single dep is passed
  /// directly as `source: <envField>.<signalName>`; two or more deps (of any
  /// mix across the three tracked-name lists) synthesize the Record-Computed
  /// source where this entry contributes element type
  /// `classFieldTypes[environmentFields[envField]][signalName]` and read
  /// expression `<envField>.<signalName>.value`.
  ///
  /// Populated by `readSolidQueryMethod` from
  /// [`ValueRewriteResult.trackedCrossClassReadNames`].
  final List<CrossClassDep> trackedCrossClassSignalNames;

  /// Combined dep count: sum of state, query, and cross-class reads in
  /// tracked position. Drives the wiring branches (zero / one / many).
  int get totalTrackedDeps =>
      trackedSignalNames.length +
      trackedQueryNames.length +
      trackedCrossClassSignalNames.length;

  /// True when [totalTrackedDeps] is two or more — i.e. the rewriter must
  /// synthesize a Record-Computed `source:` field. Single-dep queries pass
  /// the observable directly; zero-dep queries omit `source:` entirely.
  bool get needsSourceComputed => totalTrackedDeps >= 2;

  /// Conventional name of the synthesized Record-Computed source field
  /// emitted when [needsSourceComputed] is true. Single source of truth shared
  /// by `emitQuerySourceField`, `emitResourceField`, and the dispose-name
  /// list pushes in every rewriter.
  String get sourceFieldName => '_${methodName}Source';

  /// Emit-ready source text of the `debounce:` annotation argument
  /// (e.g. `'const Duration(milliseconds: 300)'`), or `null` if the
  /// annotation had no `debounce:` argument. The reader prepends `const ` for
  /// the implicit-const annotation form so the lowered
  /// `Resource(... debounceDelay: <text>, ...)` arg compiles in a non-const
  /// constructor-arg context. Stored as source text (not a runtime
  /// `Duration`) so the emitter can splice it verbatim — mirrors how
  /// [bodyText], [innerTypeText], and [annotationName] carry source
  /// substrings.
  final String? debounce;

  /// Value of the `useRefreshing:` argument on `@SolidQuery(useRefreshing: …)`,
  /// or `null` if the annotation had no `useRefreshing:` argument.
  final bool? useRefreshing;

  /// Value of the `name:` argument on `@SolidQuery(name: '…')`, or `null` if
  /// the annotation had no `name:` argument.
  final String? annotationName;
}
