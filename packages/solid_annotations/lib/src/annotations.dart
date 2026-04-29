/// Annotations for the Solid framework.
library;

import 'package:meta/meta_meta.dart';

/// {@template SolidAnnotations.SolidState}
/// Marks a field or getter as reactive state. See SPEC Section 3.1.
/// {@endtemplate}
@Target({TargetKind.field, TargetKind.getter})
class SolidState {
  /// {@macro SolidAnnotations.SolidState}
  const SolidState({this.name});

  /// Optional debug name; defaults to the annotated identifier.
  final String? name;
}

/// {@template SolidAnnotations.SolidEffect}
/// Marks an instance method as a reactive side effect. See SPEC Section 3.4.
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
/// Marks an instance method as an async reactive source. See SPEC Section 3.5.
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
/// Reserved. Full contract deferred to a later SPEC revision;
/// see SPEC Section 3.2.
/// {@endtemplate}
class SolidEnvironment {
  /// {@macro SolidAnnotations.SolidEnvironment}
  const SolidEnvironment();
}

/// {@template SolidAnnotations.UntrackedExtension}
/// Marks a reactive field read as untracked at the call site (SPEC §6.4).
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
