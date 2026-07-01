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
