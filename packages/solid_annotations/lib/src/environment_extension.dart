import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// {@template SolidAnnotations.WidgetEnvironment}
/// SwiftUI-flavoured `.environment<T>()` extension on `Widget`.
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
/// omits `dispose:` AND `T` statically has a `dispose()` method (its own
/// declaration, or inherited — e.g. `implements Disposable`, or
/// `extends ChangeNotifier`). Solid-lowered classes always qualify (they get
/// a synthesized `dispose()` in `lib/`); for a plain type, declare a
/// `void dispose() {}` on it for the injection to fire (and for
/// source-layer typecheck of the auto-injected closure). When `T` has no
/// `dispose()` at all, omitting `dispose:` injects nothing — same as
/// explicit `dispose: null`. Pass `dispose:` explicitly (any value,
/// including `null`) to always opt out, even for a type that does have
/// `dispose()` (e.g. one that must outlive this `Provider`).
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
