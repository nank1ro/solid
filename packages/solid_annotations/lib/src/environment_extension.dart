import 'package:flutter/widgets.dart';
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
/// The Solid generator auto-injects
/// `dispose: (context, provider) => provider.dispose()` when the call site
/// omits `dispose:` (SPEC §4.9 rule 7). For source-layer typecheck of the
/// auto-injected closure, declare an empty `void dispose() {}` on the
/// injected type (SPEC §3.6) — Solid-lowered classes get a synthesized
/// `dispose()` in `lib/`. Pass `dispose:` explicitly (any value, including
/// `null`) to opt out.
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
