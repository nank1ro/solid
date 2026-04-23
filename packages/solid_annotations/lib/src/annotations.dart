/// Annotations for Solid framework to mark reactive state, effects, queries,
/// and environment variables.
library;

import 'package:meta/meta_meta.dart';

/// {@template SolidAnnotations.SolidState}
/// Marks a variable or getter as reactive state.
/// The compiler transforms fields into Signal\<T> and getters into Computed\<T>.
/// {@endtemplate}
@Target({TargetKind.field, TargetKind.getter})
class SolidState {
  /// {@macro SolidAnnotations.SolidState}
  const SolidState({this.name});

  /// Optional name for the reactive state, useful for debugging.
  final String? name;
}

/// {@template SolidAnnotations.SolidEffect}
/// Marks a method as a reactive effect that runs whenever its dependencies
/// change. The compiler transforms this into an Effect that tracks reactive
/// state usage.
/// {@endtemplate}
@Target({TargetKind.method})
class SolidEffect {
  /// {@macro SolidAnnotations.SolidEffect}
  const SolidEffect();
}

/// {@template SolidAnnotations.SolidQuery}
/// Marks a method as a SolidQuery that will be transformed into a Resource.
/// The method must return a Future and will be automatically managed
/// for loading, error, and data states.
/// {@endtemplate}
@Target({TargetKind.method})
class SolidQuery {
  /// {@macro SolidAnnotations.SolidQuery}
  const SolidQuery({this.name, this.debounce, this.useRefreshing});

  /// Optional name for the SolidQuery, useful for debugging.
  final String? name;

  /// Optional debounce duration for the SolidQuery, to limit how often it runs
  /// when its sources change.
  final Duration? debounce;

  /// By default, queries stay in the current state while refreshing.
  /// If you set this to false, the SolidQuery will enter the loading state when
  /// refreshed.
  final bool? useRefreshing;
}

/// {@template SolidAnnotations.SolidEnvironment}
/// Marks a field as part of the Solid environment, making it accessible
/// throughout the widget tree.
/// {@endtemplate}
@Target({TargetKind.field})
class SolidEnvironment {
  /// {@macro SolidAnnotations.SolidEnvironment}
  const SolidEnvironment();
}
