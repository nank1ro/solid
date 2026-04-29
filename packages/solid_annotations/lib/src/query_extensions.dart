/// Source-time stub extensions for `@SolidQuery` (SPEC §3.5).
///
/// These extensions exist solely so that user source — written under
/// `source/` — typechecks without referencing the codegen-internal
/// `Resource<T>` / `ResourceState<T>` types from `flutter_solidart`. After
/// lowering, `<queryName>` is a `Resource<T>` field in `lib/`, and the
/// `.when` / `.maybeWhen` / `.isRefreshing` / `.refresh()` chain resolves to
/// upstream `flutter_solidart` callable + extensions on `Resource<T>` /
/// `ResourceState<T>` directly. Every method body throws because the bodies
/// are never executed at runtime — the runtime artifact lives entirely in
/// `lib/`, where these extensions are unreachable.
///
/// The receivers follow the SPEC §3.5 surface:
///
/// * `.when` / `.maybeWhen` / `.isRefreshing` chain after a method-call
///   shape (`fetchData()` → `Future<T>` / `Stream<T>`), so they live on
///   `Future<T>` and `Stream<T>` directly.
/// * `.refresh()` chains after a method tear-off shape (`fetchData` — no
///   parens), so its receiver is the function tear-off type
///   `Future<T> Function()` / `Stream<T> Function()`.
library;

import 'package:flutter/widgets.dart';

/// Stub `.when` / `.maybeWhen` for `Future<T>`-returning queries. Source-side
/// usage: `fetchData().when(ready: …, loading: …, error: …)`.
extension FutureWhen<T> on Future<T> {
  /// Source-time stub for `<query>().when({ready, loading, error})`. After
  /// lowering, this resolves to the upstream `flutter_solidart` extension on
  /// `ResourceState<T>` via `Resource<T>.call() => state`.
  Widget when({
    required Widget Function(T data) ready,
    required Widget Function() loading,
    required Widget Function(Object error, StackTrace stack) error,
  }) {
    throw Exception('This is just a stub for code generation.');
  }

  /// Source-time stub for `<query>().maybeWhen(...)` with an `orElse:`
  /// fallback. Same lowering contract as [when].
  Widget maybeWhen({
    required Widget Function() orElse,
    Widget Function(T data)? ready,
    Widget Function(Object error, StackTrace stack)? error,
    Widget Function()? loading,
  }) {
    throw Exception('This is just a stub for code generation.');
  }
}

/// Stub `.when` / `.maybeWhen` for `Stream<T>`-returning queries. Source-side
/// usage: `watchTicks().when(ready: …, loading: …, error: …)`.
extension StreamWhen<T> on Stream<T> {
  /// Source-time stub for `<query>().when({ready, loading, error})`. After
  /// lowering, this resolves to the upstream `flutter_solidart` extension on
  /// `ResourceState<T>` via `Resource<T>.call() => state`.
  Widget when({
    required Widget Function(T data) ready,
    required Widget Function() loading,
    required Widget Function(Object error, StackTrace stack) error,
  }) {
    throw Exception('This is just a stub for code generation.');
  }

  /// Source-time stub for `<query>().maybeWhen(...)` with an `orElse:`
  /// fallback. Same lowering contract as [when].
  Widget maybeWhen({
    required Widget Function() orElse,
    Widget Function(T data)? ready,
    Widget Function(Object error, StackTrace stack)? error,
    Widget Function()? loading,
  }) {
    throw Exception('This is just a stub for code generation.');
  }
}

/// Stub `.refresh()` on a `Future<T> Function()` tear-off. Source-side
/// usage: `fetchData.refresh()` (no parens after `fetchData`). After
/// lowering, `<queryName>` is a `Resource<T>` field and `.refresh()`
/// resolves to the upstream direct instance method on `Resource<T>`.
extension RefreshFuture<T> on Future<T> Function() {
  /// Source-time stub for `<query>.refresh()` on a Future-form query.
  Future<void> refresh() {
    throw Exception('This is just a stub for code generation.');
  }
}

/// Stub `.refresh()` on a `Stream<T> Function()` tear-off. Same shape as
/// [RefreshFuture] but for Stream-form queries.
extension RefreshStream<T> on Stream<T> Function() {
  /// Source-time stub for `<query>.refresh()` on a Stream-form query.
  Future<void> refresh() {
    throw Exception('This is just a stub for code generation.');
  }
}

/// Stub `.isRefreshing` on `Future<T>` for Future-form queries. Source-side
/// usage: `if (fetchData().isRefreshing) …`. After lowering this resolves
/// through `Resource<T>.call() => state` to the upstream extension on
/// `ResourceState<T>`.
extension IsRefreshingFuture<T> on Future<T> {
  /// Source-time stub for `<query>().isRefreshing` on a Future-form query.
  bool get isRefreshing {
    throw Exception('This is just a stub for code generation.');
  }
}

/// Stub `.isRefreshing` on `Stream<T>` for Stream-form queries. Same shape as
/// [IsRefreshingFuture] but for Stream-form queries.
extension IsRefreshingStream<T> on Stream<T> {
  /// Source-time stub for `<query>().isRefreshing` on a Stream-form query.
  bool get isRefreshing {
    throw Exception('This is just a stub for code generation.');
  }
}
