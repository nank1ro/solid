/// Annotations for the Solid framework.
library;

import 'package:meta/meta_meta.dart';

/// {@template SolidAnnotations.SolidState}
/// Marks a field or getter as reactive state.
/// {@endtemplate}
@Target({TargetKind.field, TargetKind.getter})
class SolidState {
  /// {@macro SolidAnnotations.SolidState}
  const SolidState({this.name});

  /// Optional debug name; defaults to the annotated identifier.
  final String? name;
}

/// {@template SolidAnnotations.SolidEffect}
/// Marks an instance method as a reactive side effect.
///
/// The annotated method must declare a `void` return type and take no
/// parameters; its body must read at least one reactive declaration. The
/// generator lowers it to a `late final <name> = Effect(() { … }, name: '…')`
/// field that re-runs whenever any read reactive declaration changes.
/// {@endtemplate}
@Target({TargetKind.method})
class SolidEffect {
  /// {@macro SolidAnnotations.SolidEffect}
  const SolidEffect({this.name});

  /// Optional debug name; defaults to the annotated method's identifier.
  final String? name;
}

/// {@template SolidAnnotations.SolidQuery}
/// Marks an instance method as an async reactive source.
///
/// The annotated method must declare a `Future<T>` return type with an `async`
/// body, or a `Stream<T>` return type whose body either returns a pre-existing
/// `Stream<T>` or yields with `async*`. The method must take no parameters.
/// The generator lowers it to a `late final <name> = Resource<T>(…, name: '…')`
/// (or `Resource<T>.stream(…)`) field whose state any reader of the call site
/// auto-subscribes to. Source-side `<name>()`, `<name>().when(…)`,
/// `<name>().maybeWhen(…)`, `<name>().isRefreshing`, and `<name>.refresh()`
/// chains survive byte-identical in lowered output.
/// {@endtemplate}
@Target({TargetKind.method})
class SolidQuery {
  /// {@macro SolidAnnotations.SolidQuery}
  const SolidQuery({this.name, this.debounce, this.useRefreshing = true});

  /// Optional debug name; defaults to the annotated method's identifier.
  final String? name;

  /// Optional delay applied to auto-refreshes triggered by upstream reactive
  /// changes — useful for typeahead-style queries where rapid keystrokes
  /// should coalesce into a single fetch. Maps to the upstream
  /// `Resource.debounceDelay:` argument when non-null.
  final Duration? debounce;

  /// When `true` (the upstream default), an auto-refresh keeps the previous
  /// `ready` / `error` state and exposes `isRefreshing == true` while the new
  /// value resolves. When `false`, every refresh re-enters `loading`.
  final bool useRefreshing;
}

/// {@template SolidAnnotations.SolidEnvironment}
/// Marks a `late` instance field as a dependency-injection binding.
///
/// The generator lowers `@SolidEnvironment() late T name;` to
/// `late final name = context.read<T>();` in the produced `lib/` output.
/// The host class must be a `StatelessWidget` or `State<X>` subclass.
/// The annotation takes no parameters.
/// {@endtemplate}
@Target({TargetKind.field})
class SolidEnvironment {
  /// {@macro SolidAnnotations.SolidEnvironment}
  const SolidEnvironment();
}

/// {@template SolidAnnotations.UntrackedExtension}
/// Marks a reactive field read as untracked at the call site.
///
/// When `solid_generator` sees `<field>.untracked` for a `@SolidState` field,
/// it rewrites the expression to `<field>.untrackedValue` and excludes the
/// read from `SignalBuilder` placement. The extension is identity at runtime;
/// applied to a non-reactive expression it is a no-op.
/// {@endtemplate}
extension UntrackedExtension<T> on T {
  /// {@macro SolidAnnotations.UntrackedExtension}
  T get untracked => this;
}

/// {@template SolidAnnotations.LazyStateExtension}
/// Source-time stubs for `SignalBase<T>` getters that survive verbatim through
/// lowering: `.hasValue` (lazy-state probe) and
/// `.previousValue` (the value just before the most recent update — useful in
/// `observe(...)` callbacks).
///
/// In source, `<field>.hasValue` reads through a non-reactive declaration
/// (e.g. `late int counter`) and the bare Dart analyzer cannot prove the
/// chain typechecks against the lowered `Signal<T>` type. This extension
/// provides the source-side getter so the chain compiles; at lib-time the
/// real `SignalBase<T>` getter wins (instance members beat extension members
/// in Dart), so the stub body is unreachable for tracked-field call sites.
/// {@endtemplate}
extension LazyStateExtension<T> on T {
  /// {@macro SolidAnnotations.LazyStateExtension}
  bool get hasValue => true;

  /// {@macro SolidAnnotations.LazyStateExtension}
  T? get previousValue => null;
}
