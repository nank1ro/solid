import 'package:flutter/widgets.dart';
import 'package:solid_annotations/provider.dart';

/// Extension methods for Future and Stream to handle loading, error, and data
/// states.
extension FutureWhen<T> on Future<T> {
  /// Handles the different states of the Future: loading, error, and data
  /// ready.
  Widget when({
    required Widget Function(T data) ready,
    required Widget Function() loading,
    required Widget Function(Object error, StackTrace stack) error,
  }) {
    throw Exception('This is just a stub for code generation.');
  }

  /// Handles the different states of the Future with an orElse fallback.
  Widget maybeWhen({
    required Widget Function() orElse,
    Widget Function(T data)? ready,
    Widget Function(Object error, StackTrace stack)? error,
    Widget Function()? loading,
  }) {
    throw Exception('This is just a stub for code generation.');
  }
}

/// Extension methods for Stream to handle loading, error, and data states.
extension StreamWhen<T> on Stream<T> {
  /// Handles the different states of the Stream: loading, error, and data
  Widget when({
    required Widget Function(T data) ready,
    required Widget Function() loading,
    required Widget Function(Object error, StackTrace stack) error,
  }) {
    throw Exception('This is just a stub for code generation.');
  }

  /// Handles the different states of the Stream with an orElse fallback.
  Widget maybeWhen({
    required Widget Function() orElse,
    Widget Function(T data)? ready,
    Widget Function(Object error, StackTrace stack)? error,
    Widget Function()? loading,
  }) {
    throw Exception('This is just a stub for code generation.');
  }
}

/// Extension method to easily wrap a widget with an InheritedSolidProvider
extension EnvironmentExtension on Widget {
  /// Wraps the widget with a SolidProvider that provides data of type T.
  Widget environment<T>(
    T Function(BuildContext) create, {

    /// Whether to notify the update of the provider, defaults to false.
    bool Function(InheritedSolidProvider<T> oldWidget)? notifyUpdate,
  }) =>
      SolidProvider<T>(create: create, notifyUpdate: notifyUpdate, child: this);
}

/// Extension methods on BuildContext to read and watch provided data.
extension ProviderReadExt on BuildContext {
  /// Reads the provided data of type T without listening for updates.
  T read<T>() => SolidProvider.of<T>(this, listen: false);

  /// Reads the provided data of type T without listening for updates.
  T? maybeRead<T>() => SolidProvider.maybeOf<T>(this, listen: false);
}

/// Extension methods on BuildContext to watch for updates in provided data.
extension ProviderWatchExt on BuildContext {
  /// Watches the provided data of type T and rebuilds when it changes.
  T watch<T>() => SolidProvider.of<T>(this);

  /// Watches the provided data of type T and rebuilds when it changes.
  T? maybeWatch<T>() => SolidProvider.maybeOf<T>(this);
}

/// Extension methods to refresh Future functions
extension RefreshFuture<T> on Future<T> Function() {
  /// Triggers a refresh of the Future function.
  Future<void> refresh() {
    throw Exception('This is just a stub for code generation.');
  }
}

/// Extension methods to refresh Stream functions
extension RefreshStream<T> on Stream<T> Function() {
  /// Triggers a refresh of the Stream function.
  Future<void> refresh() {
    throw Exception('This is just a stub for code generation.');
  }
}

/// Extension to check if a Future is in refreshing state
extension IsRefreshingFuture<T> on Future<T> {
  /// Checks if the Future is currently refreshing.
  bool get isRefreshing {
    throw Exception('This is just a stub for code generation.');
  }
}

/// Extension to check if a Stream is in refreshing state
extension IsRefreshingStream<T> on Stream<T> {
  /// Checks if the Stream is currently refreshing.
  bool get isRefreshing {
    throw Exception('This is just a stub for code generation.');
  }
}
