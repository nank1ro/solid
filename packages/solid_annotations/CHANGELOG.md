## 3.0.0-dev.2

- **DOCS**: Update `WidgetEnvironment.environment()` doc comment — `solid_generator` now only auto-injects `dispose:` when the created type is recognized as needing it (has a provable `dispose()`, or is `@Solid*`-annotated — same-file or cross-file); omitting `dispose:` on a type provably without one injects nothing instead of a call that previously failed source-layer typechecking with a compile-time `undefined_method` error on `.dispose()`.

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
