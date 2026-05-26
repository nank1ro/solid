# Solid annotation contract

Per-annotation valid/invalid targets and rationale. Distilled from the user docs at <https://solid.mariuti.com>.

## `@SolidState()` — reactive state

Docs: <https://solid.mariuti.com/guides/state>.

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
| Top-level / library variable | The annotation only applies to class members. |

## `@SolidEffect()` — side effect

Docs: <https://solid.mariuti.com/guides/effect>.

### Valid target

| Form | Example |
| --- | --- |
| Instance method returning `void` | `@SolidEffect() void logCounter() { print('Counter: $counter'); }` |

The body's reads of `@SolidState` fields are tracked automatically. The effect re-runs whenever any tracked dependency changes.

### Invalid

- Non-`void` return.
- Methods with parameters.
- Static or top-level functions.

## `@SolidQuery()` — async / stream resource

Docs: <https://solid.mariuti.com/guides/query>.

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
  - `.maybeWhen(..., orElse: ...)`
  - `.isRefreshing` (true while a re-execution is in flight)
  - `.refresh()` to manually re-run

### Annotation options

| Option | Effect |
| --- | --- |
| `debounce: Duration(...)` | Wait this long after the last input change before re-running. |
| `useRefreshing` (default `true`) | On re-execution from a dependency change, the resource stays on the current value while refetching, and `.isRefreshing` becomes `true` (smoother UX, no loading flash). Pass `useRefreshing: false` to drop back into the `loading` state on each re-execution. |

## `@SolidEnvironment()` — inject from widget tree

Docs: <https://solid.mariuti.com/guides/environment>.

### Valid target

| Form | Example |
| --- | --- |
| `late` field on a `StatelessWidget` or `State<X>` | `@SolidEnvironment() late Counter counter;` |

### Behavior

- Lookup is lazy: the field initializer runs the first time the field is read.
- Resolves the nearest ancestor `Provider<T>` where `T` is the declared type.
- Reading a `@SolidState` member of the injected instance stays reactive — fine-grained reactivity is preserved across the boundary.
- Works inside `build`, `@SolidEffect`, `@SolidQuery` bodies, or any other context.

### Providing the instance

Two equivalent forms:

```dart
// 1. .environment<T>() extension shipped by solid_annotations
home: CounterDisplay().environment((_) => Counter()),

// 2. Provider<T> from package:provider
home: Provider(create: (_) => Counter(), child: CounterDisplay()),
```

For multiple providers, chain `.environment(...)` calls or use `MultiProvider` from `package:provider`.

The type argument is inferred from the closure's return type. Pass it explicitly only when consumers should read by a supertype: `.environment<AuthService>((_) => RealAuthService())`.

### Invalid

- Non-`late` field. The lookup is lazy and needs `late` to defer initialization.
- Static or top-level field.

## `.untracked` — opt out of subscription at the call site

Docs: <https://solid.mariuti.com/guides/untracked>.

Not an annotation — an extension getter shipped by `solid_annotations`:

```dart
extension UntrackedExtension<T> on T {
  T get untracked => this;
}
```

`counter.untracked` typechecks identically to `counter` and is a no-op at runtime. The generator detects the pattern at source level and rewrites it to the underlying `untrackedValue` primitive, excluding the read from the dependency set — `SignalBuilder` doesn't wrap it inside `build`, and an enclosing `@SolidEffect` / `@SolidQuery` won't re-fire on changes to it.

The getter untracks a **read**. To untrack a **write** inside an effect, use the `untracked(() => …)` function form — also shipped by `solid_annotations` as a source-time stub (`T untracked<T>(T Function() callback) => callback();`, resolving to `flutter_solidart`'s `untracked` after generation). This is required when writing a collection signal (`MapSignal`/`ListSignal`/`SetSignal`) inside an effect: their element-writes read the signal internally to diff, so the write would otherwise subscribe the effect to what it writes (a cyclic reaction). Read the dependencies first, then wrap the write:

```dart
@SolidEffect()
void recordHistory() {
  final c = counter;                          // tracked dependency
  untracked(() => history = [...history, c]); // untracked write
}
```

The generator leaves the call verbatim (inner reads still get `.value` but are not tracked) and, when the file also keeps the `solid_annotations` import, emits it with `hide untracked` so the call binds to the runtime function.

### Two ways reads become untracked

| Form | How |
| --- | --- |
| Auto-untracked: read inside an `on*` callback parameter (`onPressed`, `onTap`, `onChanged`, …) | Solid recognizes user-interaction handlers — the read does not subscribe. No source change required. |
| Manual: `field.untracked` at the read site | Use anywhere outside an `on*` callback to read the current value without subscribing. Example: `key: ValueKey(counter.untracked)`. |

### Hard rules

- **String interpolation form**: only `'${counter.untracked}'` works. The short form `'$counter.untracked'` parses as `${counter}` followed by a literal `.untracked` suffix (still tracked).
- **Shadowing**: a local variable that shadows the field disables the rewrite for that scope (the analyzer's identifier resolution wins).
- **No-op on non-reactive types**: applied to a non-`@SolidState` value, the extension is identity at compile time and at runtime — safe to leave in code that may or may not target a reactive field.

### When to reach for it

- One-time `Key` / `ValueKey` construction from a reactive field.
- Inside an effect that writes to a signal, reading that same signal's current value to avoid a self-dependency loop: `history = [...history.untracked, counter];`.
- Logging or analytics calls that should not cause rebuilds.

If `.untracked` shows up everywhere, prefer a `@SolidState` getter (derived state) or a plain non-reactive field instead.
