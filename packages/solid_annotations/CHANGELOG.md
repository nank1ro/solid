## 3.0.0-dev.3

- **FEAT**: Add a `previousState` source-time stub on the `@SolidQuery` tear-off (`<query>.previousState`), mirroring `Resource.previousState` — the `ResourceState<T>?` immediately before the current one. With the default `useRefreshing: true` this retains the last `ready` value across a failed refresh (a `ResourceError` otherwise drops it); with `useRefreshing: false` a refresh re-enters `loading` immediately, so `previousState` is loading during that window, not the last ready value. Reads as `<query>.previousState?.asReady?.value` and typechecks identically source- and lib-side via the existing `FutureWhen`/`StreamWhen` state accessors.

## 3.0.0-dev.2

- **DOCS**: Update `WidgetEnvironment.environment()` doc comment for `solid_generator`'s type-aware `dispose:` auto-injection.

## 3.0.0-dev.1

- **BREAKING**: Raise the Dart SDK lower bound to `^3.10.0` and align with the solidart v3 ecosystem (`flutter_solidart` `^3.0.0-dev.1`).
- **CHORE**: Bump `meta`, `provider`, and `very_good_analysis`.

## 2.0.0+1

- **DOCS**: Update README installation.

## 2.0.0

- **FEAT**: `Disposable` marker for environment values that need teardown.
- **FEAT**: `untracked(() => …)` source-time stub for untracked writes inside reactive bodies (mirrors `flutter_solidart`'s `untracked`; identity at the source level, resolves to the runtime function after generation).

## 1.0.0

- Initial version.
