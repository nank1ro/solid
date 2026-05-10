/// Source-time stub extensions for `@SolidQuery` (SPEC §3.5).
///
/// These extensions exist solely so that user source — written under
/// `source/` — typechecks without referencing the codegen-internal
/// `Resource<T>` / `ResourceState<T>` types from `flutter_solidart`. After
/// lowering, `<queryName>` is a `Resource<T>` field in `lib/`, and the
/// chain (`.when` / `.maybeWhen` / `.value` / `.isReady` / `.error` /
/// `.asReady?.value` / `.asError?.stackTrace` / etc.) resolves to upstream
/// `flutter_solidart` callable + extensions on `Resource<T>` /
/// `ResourceState<T>` (and the real `ResourceReady<T>` / `ResourceError<T>`
/// field accessors) directly. Every method body throws because the bodies
/// are never executed at runtime — the runtime artifact lives entirely in
/// `lib/`, where these extensions are unreachable.
///
/// `solid_annotations` does NOT depend on `package:solidart` (SPEC §14
/// item 5). For the two stubs whose upstream return type is a
/// `solidart`-internal class (`asReady` returns `ResourceReady<T>?`,
/// `asError` returns `ResourceError<T>?`), this library declares
/// **library-private placeholder classes** [_AsReadyResult] and
/// [_AsErrorResult] with the same chain shape so the source-side chain
/// typechecks. Library-privacy ensures user code cannot pin the source-side
/// placeholder type against the lib-side `solidart` type.
library;

const String _stubMessage = 'This is just a stub for code generation.';

/// State-read getters and pattern-match helpers on `Future<T>` (Future-form
/// query call results). Mirrors upstream `ResourceExtensions` on
/// `ResourceState<T>` so source-side typechecking matches the lowered chain.
extension FutureWhen<T> on Future<T> {
  /// Source-time stub for `<query>().when({ready, loading, error})`. After
  /// lowering, this resolves to the upstream `flutter_solidart` extension on
  /// `ResourceState<T>` via `Resource<T>.call() => state`. Generic `R` lets
  /// the same call site work in Widget contexts (where `R = Widget` is
  /// inferred from the surrounding subtree) AND non-Widget contexts (effect
  /// / computed / query bodies returning a domain value).
  R when<R>({
    required R Function(T data) ready,
    required R Function() loading,
    required R Function(Object error, StackTrace stack) error,
  }) {
    throw Exception(_stubMessage);
  }

  /// Source-time stub for `<query>().maybeWhen(...)` with an `orElse:`
  /// fallback. Same lowering contract as [when].
  R maybeWhen<R>({
    required R Function() orElse,
    R Function(T data)? ready,
    R Function(Object error, StackTrace stack)? error,
    R Function()? loading,
  }) {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.value`: returns the inner value when ready,
  /// `null` when loading, **rethrows the error** when in the error state.
  /// Use [asReady] for safe access that never throws.
  T? get value {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.error`: returns the error when in the error
  /// state, `null` otherwise. Never throws.
  Object? get error {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.isReady`: `true` when the resource is in
  /// the ready state.
  bool get isReady {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.isLoading`: `true` when the resource is in
  /// the loading state.
  bool get isLoading {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.hasError`: `true` when the resource is in
  /// the error state.
  bool get hasError {
    throw Exception(_stubMessage);
  }

  /// Source-time stub for `<query>().isRefreshing` on a Future-form query.
  bool get isRefreshing {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.asReady`: returns the ready-state wrapper
  /// when the resource is ready, `null` otherwise. The recommended safe-read
  /// shape is `<queryName>().asReady?.value` (returns `T?`, never throws).
  /// At lib-time this resolves to upstream `ResourceReady<T>?`.
  // ignore: library_private_types_in_public_api
  _AsReadyResult<T>? get asReady {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.asError`: returns the error-state wrapper
  /// when the resource is in the error state, `null` otherwise. Use
  /// `<queryName>().asError?.error` for the error object and
  /// `<queryName>().asError?.stackTrace` for the stack trace. At lib-time
  /// this resolves to upstream `ResourceError<T>?`.
  // ignore: library_private_types_in_public_api
  _AsErrorResult<T>? get asError {
    throw Exception(_stubMessage);
  }
}

/// State-read getters and pattern-match helpers on `Stream<T>` (Stream-form
/// query call results). Mirrors [FutureWhen] on the Stream-form receiver.
extension StreamWhen<T> on Stream<T> {
  /// Source-time stub for `<query>().when({ready, loading, error})`. After
  /// lowering, this resolves to the upstream `flutter_solidart` extension on
  /// `ResourceState<T>` via `Resource<T>.call() => state`. See
  /// [FutureWhen.when].
  R when<R>({
    required R Function(T data) ready,
    required R Function() loading,
    required R Function(Object error, StackTrace stack) error,
  }) {
    throw Exception(_stubMessage);
  }

  /// Source-time stub for `<query>().maybeWhen(...)` with an `orElse:`
  /// fallback. Same lowering contract as [when].
  R maybeWhen<R>({
    required R Function() orElse,
    R Function(T data)? ready,
    R Function(Object error, StackTrace stack)? error,
    R Function()? loading,
  }) {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.value`. See [FutureWhen.value].
  T? get value {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.error`. See [FutureWhen.error].
  Object? get error {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.isReady`. See [FutureWhen.isReady].
  bool get isReady {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.isLoading`. See [FutureWhen.isLoading].
  bool get isLoading {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.hasError`. See [FutureWhen.hasError].
  bool get hasError {
    throw Exception(_stubMessage);
  }

  /// Source-time stub for `<query>().isRefreshing` on a Stream-form query.
  bool get isRefreshing {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.asReady`. See [FutureWhen.asReady].
  // ignore: library_private_types_in_public_api
  _AsReadyResult<T>? get asReady {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceExtensions.asError`. See [FutureWhen.asError].
  // ignore: library_private_types_in_public_api
  _AsErrorResult<T>? get asError {
    throw Exception(_stubMessage);
  }
}

/// Stub `.refresh()` on a `Future<T> Function()` tear-off. Source-side
/// usage: `fetchData.refresh()` (no parens after `fetchData`). After
/// lowering, `<queryName>` is a `Resource<T>` field and `.refresh()`
/// resolves to the upstream direct instance method on `Resource<T>`.
extension RefreshFuture<T> on Future<T> Function() {
  /// Source-time stub for `<query>.refresh()` on a Future-form query.
  Future<void> refresh() {
    throw Exception(_stubMessage);
  }
}

/// Stub `.refresh()` on a `Stream<T> Function()` tear-off. Same shape as
/// [RefreshFuture] but for Stream-form queries.
extension RefreshStream<T> on Stream<T> Function() {
  /// Source-time stub for `<query>.refresh()` on a Stream-form query.
  Future<void> refresh() {
    throw Exception(_stubMessage);
  }
}

/// Library-private placeholder mirroring the public surface of
/// `solidart.ResourceReady<T>`. Source-side, `<query>().asReady` resolves to
/// `_AsReadyResult<T>?`; lib-side, the same chain resolves through upstream
/// `ResourceExtensions.asReady` to `solidart.ResourceReady<T>?`. Both
/// expose `T value`, so `.asReady?.value` typechecks identically in both
/// contexts. The class is library-private so user code cannot pin the
/// source-side type against the lib-side type.
class _AsReadyResult<T> {
  _AsReadyResult._();

  /// Mirrors `ResourceReady<T>.value` (the non-nullable inner value).
  T get value {
    throw Exception(_stubMessage);
  }
}

/// Library-private placeholder mirroring the public surface of
/// `solidart.ResourceError<T>`. Source-side, `<query>().asError` resolves to
/// `_AsErrorResult<T>?`; lib-side, the same chain resolves through upstream
/// `ResourceExtensions.asError` to `solidart.ResourceError<T>?`. Both
/// expose `Object error` and `StackTrace? stackTrace`, so
/// `.asError?.error` / `.asError?.stackTrace` typecheck identically in both
/// contexts.
class _AsErrorResult<T> {
  _AsErrorResult._();

  /// Mirrors `ResourceError<T>.error` (the non-nullable error object).
  Object get error {
    throw Exception(_stubMessage);
  }

  /// Mirrors `ResourceError<T>.stackTrace` (nullable per upstream).
  StackTrace? get stackTrace {
    throw Exception(_stubMessage);
  }
}
