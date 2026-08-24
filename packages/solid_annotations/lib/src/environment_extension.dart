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
/// The Solid generator decides whether to auto-inject
/// `dispose: (context, provider) => provider.dispose()` when the call site
/// omits `dispose:`, per four rules (see SPEC.md §4.9 rule 7 for the full
/// decision table):
///
///  1. `T` provably has a `dispose()` method (own declaration, or
///     inherited — e.g. `implements Disposable`, or `extends
///     ChangeNotifier`) → inject.
///  2. `T` is `@Solid*`-annotated, same-file OR cross-file — every
///     Solid-lowered class synthesizes `dispose()` in `lib/`, even before a
///     source-side stub exists → inject.
///  3. `T`'s declaration is otherwise visible to the running check and
///     shows neither of the above (a genuinely plain type) → skip; the
///     call site is left byte-identical, same as explicit `dispose: null`.
///  4. `T`'s declaration isn't visible anywhere the check looked (mainly: a
///     cross-file, non-`@Solid*` type reached from a file that ALSO has a
///     `@Solid*`-annotated class) → inject anyway, so a wrong guess fails
///     loudly at compile time instead of silently leaking a resource.
///
/// For a plain (non-Solid) type, declare `void dispose() {}` on it so rule 1
/// fires (and so the auto-injected closure typechecks at the source layer).
/// Pass `dispose:` explicitly (any value, including `null`) to always opt
/// out — this is REQUIRED, not just available, for a plain cross-file type
/// that rule 4 can't prove dispose-less.
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
