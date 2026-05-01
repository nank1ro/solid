import 'package:flutter/widgets.dart';
// `provider` is supplied by the user's pubspec (SPEC §3.6 install command);
// `solid_annotations` does not declare it as a runtime dep.
// ignore: depend_on_referenced_packages
import 'package:provider/provider.dart';

/// {@template SolidAnnotations.WidgetEnvironment}
/// SwiftUI-flavoured `.environment<T>()` extension on `Widget` (SPEC §3.6).
///
/// Wraps `this` widget in a `Provider<T>` — the SwiftUI-flavoured
/// alternative to writing `Provider<T>(create: …, child: this)` directly.
///
/// The type argument `T` is inferred from `create`'s return type:
/// `child.environment((_) => Counter())` resolves `T = Counter`.
/// Pass it explicitly to register under a supertype:
/// `child.environment<AuthService>((_) => RealAuthService())`.
///
/// There is no automatic dispose — pass `dispose` when cleanup is needed:
/// `child.environment((_) => Counter(), dispose: (_, c) => c.dispose())`.
/// See SPEC §3.6 for why `c.dispose()` requires a source-side `dispose()`
/// declaration on the injected type.
/// {@endtemplate}
extension WidgetEnvironment on Widget {
  /// {@macro SolidAnnotations.WidgetEnvironment}
  Widget environment<T extends Object>(
    T Function(BuildContext) create, {
    void Function(BuildContext, T)? dispose,
  }) {
    return Provider<T>(create: create, dispose: dispose, child: this);
  }
}
