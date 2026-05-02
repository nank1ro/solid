## 2.0.0

- **BREAKING CHANGE**: Complete annotation surface rewrite. v2 ships four annotations consumed by `solid_generator`'s source-to-lib transformer:
  - `@SolidState` — fine-grained reactive fields (signals) and getters (computed)
  - `@SolidEffect` — declarative effects with auto-tracking and dispose synthesis
  - `@SolidQuery` — async resource lowering (Future + Stream) with `.when()` / `.refresh()` / `debounce:` / `useRefreshing:` / `source:` auto-tracking
  - `@SolidEnvironment` — Provider-backed dependency injection with `.environment<T>()` extension and cross-class chain rewrite
- **FEAT**: `Disposable` marker for environment values that need teardown.
- **FEAT**: `BuildContext.environment<T>()` extension for ergonomic consumption (alternative to `Provider.of<T>(context)`).
- **FEAT**: Adds `provider: ^6.1.0` as a runtime dependency.

## 1.0.0

- Initial version.
