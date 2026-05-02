## 2.0.0

- **FEAT**: `Widget.environment<T>()` SwiftUI-flavoured extension that wraps `this` widget in a `Provider<T>` — alternative to writing `Provider<T>(create: …, child: this)` directly.
- **FEAT**: `Disposable` marker for environment values that need teardown.
- **FEAT**: Adds `provider: ^6.1.0` as a runtime dependency.

## 1.0.0

- Initial version.
