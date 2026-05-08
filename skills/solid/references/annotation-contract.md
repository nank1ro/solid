# Solid annotation contract

Per-annotation valid/invalid targets. Distilled from the user docs at `docs/src/content/docs/guides/`.

## `@SolidState()` — reactive state

Source guide: `state.mdx`.

### Valid targets

| Form | Example |
| --- | --- |
| Instance field with initializer | `@SolidState() int counter = 0;` |
| `late` non-nullable instance field | `@SolidState() late String name;` |
| Nullable instance field (no initializer) | `@SolidState() String? userId;` |
| Instance getter (derived state) | `@SolidState() int get doubleCounter => counter * 2;` |

### Invalid targets

| Form | Why |
| --- | --- |
| `final`, `const` field | The state must be assignable; the generated setter rewrites your reads. |
| `static` field | State is per-widget-instance, not per-class. |
| Setter | A `@SolidState` write goes through the generated setter; you don't write your own. |
| Method | Use `@SolidEffect` for side effects or `@SolidQuery` for async values. |
| Top-level / library variable | Annotation only applies to class members. |

## `@SolidEffect()` — side effect

Source guide: `effect.mdx`.

### Valid target

| Form | Example |
| --- | --- |
| Instance method returning `void` | `@SolidEffect() void logCounter() { print('Counter: $counter'); }` |

The body's reads of `@SolidState` fields are tracked automatically. The effect re-runs whenever any tracked dependency changes.

### Invalid

- Non-`void` return.
- Methods with parameters.
- Static or top-level functions.

## `@SolidQuery()` — async/stream resource

Source guide: `query.mdx`.

### Valid target

| Form | Example |
| --- | --- |
| `Future<T>` async method, no parameters | `@SolidQuery() Future<String> fetchData() async { ... }` |
| `Stream<T>` method, no parameters | `@SolidQuery() Stream<int> tick() => Stream.periodic(...);` |

### Hard rules

- **No parameters.** Read `@SolidState` fields from the body — the query auto-re-executes when they change.
- Return type must be `Future<T>` or `Stream<T>`.
- The call site `fetchData()` does **not** return a `Future`/`Stream` — it returns a `Resource<T>` exposing:
  - `.when(ready: ..., loading: ..., error: ...)`
  - `.maybeWhen(...orElse: ...)`
  - `.isRefreshing` (true while a re-execution is in flight)
  - `.refresh()` to manually re-run

### Annotation options

| Option | Effect |
| --- | --- |
| `debounce: Duration(...)` | Wait this long after the last input change before re-running. |
| `useRefreshing: false` | On re-execution, drop back into `loading` state instead of staying on the current value. Default: `true`. |

## `@SolidEnvironment()` — inject from widget tree

Source guide: `environment.mdx`.

### Valid target

| Form | Example |
| --- | --- |
| `late` field on a `StatelessWidget` or `State<X>` | `@SolidEnvironment() late Counter counter;` |

### Behavior

- Lookup is lazy: the field initializer runs the first time the field is read.
- Resolves the nearest ancestor `Provider<T>` where `T` is the field's declared type.
- Reading a `@SolidState` member of the injected instance stays reactive — fine-grained reactivity is preserved across the boundary.
- Works inside `build`, `@SolidEffect`, `@SolidQuery` bodies, or any other context.

### Providing the instance

Two equivalent ways:

```dart
// 1. .environment<T>() extension shipped by solid_annotations
home: CounterDisplay().environment((_) => Counter()),

// 2. Provider<T> from package:provider
home: Provider(create: (_) => Counter(), child: CounterDisplay()),
```

For multiple providers chain `.environment(...)` calls or use `MultiProvider` from `package:provider`.

The type argument is inferred from the closure's return type. Pass it explicitly only when consumers should read by a supertype: `.environment<AuthService>((_) => RealAuthService())`.

### Invalid

- Non-`late` field. The lookup is lazy and needs `late` to defer initialization.
- Static or top-level field.
