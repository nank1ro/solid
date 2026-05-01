# Solid — Product Specification (v2)

**Status:** DRAFT — under review
**Scope of this SPEC:** defines the user-facing contract for `@SolidState`, `@SolidEffect`, `@SolidQuery`, and `@SolidEnvironment` (M1, M4, M5, and M6 milestones). The full v2 annotation surface is specified here.

This document is the single source of truth for what Solid does. Reviewer agents cite this document by section number when judging an implementation. It contains no file names, no class names, no AST details — only what the developer sees and the guarantees they get.

---

## 1. Vision

Solid is a Flutter code-generation layer that lets a developer put reactive state directly on widgets, the way SwiftUI allows reactive state directly on views. The developer writes an ordinary Flutter widget with annotated fields. Solid transforms the widget into a fine-grained reactive Flutter widget backed by `flutter_solidart` primitives (`Signal`, `Computed`, `SignalBuilder`). The result: when a piece of reactive state changes, only the widget subtree that actually reads it rebuilds. No ViewModel, no `setState`, no `ChangeNotifier`, no `notifyListeners`, no manual rebuild scopes.

---

## 2. Source / Generated Model

The developer writes annotated code in a top-level directory called `source/`. Solid reads every `.dart` file under `source/` and emits a transformed `.dart` file at the mirrored path under `lib/`.

Example:

```
source/counter.dart        ← developer writes (committed)
lib/counter.dart           ← Solid emits (committed)
```

> **Why this differs from the pub.dev convention.** Most Dart generators read files from `lib/` and emit adjacent `*.g.dart` parts. Solid cannot: annotated Solid source violates Flutter invariants — e.g., a `StatelessWidget` with mutable fields — so it is not valid to ship as-is under `lib/`. The solution is to put source in its own top-level directory (`source/`) and let Solid emit the runnable form into `lib/`.

Rules:

- **Input path**: any `.dart` file under `source/` at any depth.
- **Output path**: same relative path under `lib/`. No suffix change. `source/foo/bar.dart` becomes `lib/foo/bar.dart`.
- **Transformation vs verbatim copy.** Solid reads every `.dart` file under `source/`. If a file contains at least one `@Solid*` annotation (`@SolidState`, `@SolidEffect`, `@SolidQuery`, `@SolidEnvironment`), Solid transforms it. Otherwise the file is copied verbatim to the mirrored path under `lib/`. Non-`.dart` files (assets, configs, etc.) are always copied verbatim. The key is annotation presence, not file extension.
- **Both are committed to git.** Source is the review artifact for intent. Lib is the review artifact for correctness — every PR that changes `source/` must include the regenerated `lib/` diff so reviewers catch generator regressions.
- **Solid emits no `.g.dart` files of its own.** Third-party generators (freezed, json_serializable, drift) may emit `.g.dart` or `.freezed.dart` files under `source/`; Solid copies those verbatim to the mirrored path under `lib/`.
- **The example app's `main.dart`** lives in `lib/` (or `source/` if itself annotated) and imports from `lib/` using normal Flutter imports (`import 'counter.dart';`).
- **Source is analyzed** with a couple of lint suppressions (notably `must_be_immutable`) so that a `StatelessWidget` with a mutable `@SolidState` field does not trip the analyzer. Source remains valid Dart at all times; any real error (typo, type error, undefined symbol) fails analysis.
- **Hot reload requires a bridge.** `dart run build_runner watch` regenerates `lib/` as the developer edits `source/`, but `flutter run` does not auto-detect that filesystem change because no IDE save event fires. The developer must either press `r` in the `flutter run` terminal after build_runner emits, or use `dashmon` (https://pub.dev/packages/dashmon) to bridge the filesystem change to Flutter's stdin automatically. See Section 12 for the full workflow.

---

## 3. Annotations

> **Milestones vs v2.** The v2 public release ships the full annotation set: `@SolidState`, `@SolidEffect`, `@SolidQuery`, `@SolidEnvironment`. Implementation is split into internal milestones. M1 implements `@SolidState`; M4 adds `@SolidEffect`; M5 adds `@SolidQuery`; M6 adds `@SolidEnvironment`. The user-facing API of every annotation is fixed in this SPEC.

### 3.1 M1 scope: `@SolidState`

`@SolidState` declares a reactive property on a class. It attaches to either a field or a getter.

```dart
@SolidState()
int counter = 0;

@SolidState()
int get doubleCounter => counter * 2;
```

Optional `name:` parameter overrides the auto-derived debug name:

```dart
@SolidState(name: 'myCounter')
int counter = 0;
```

#### Valid targets

- Instance field with an initializer, or a `late` non-nullable field without one; nullable fields need neither.
- Instance getter with an expression body (`=> ...`) or a block body (`{ return ...; }`).

#### Invalid targets (the generator must reject with a clear error)

- `final` field (a `Signal` wrapping a never-reassigned value is a static constant — pointless).
- `const` field (same reason plus a type-system impossibility).
- `static` field or getter (class-level, not instance; out of M1 scope).
- Top-level variable or getter.
- Method (not a getter).
- Setter.

### 3.2 Later milestones (shipped before v2 release)

All four v2 annotations now have full user-facing contracts in this SPEC: `@SolidState` (Section 3.1), `@SolidEffect` (Section 3.4), `@SolidQuery` (Section 3.5), and `@SolidEnvironment` (Section 3.6). No annotation remains reserved-only.

### 3.3 Permanent non-goals

Solid will never:

- Replace `flutter_solidart`. Signal / Computed / Effect / Resource / SignalBuilder come from the upstream package.
- Ship its own reactive runtime.
- Use Dart Macros, Dart augmentations, or part-file patterns.
- Split one source file into multiple lib files. Each `source/*.dart` produces exactly one `lib/*.dart` at the mirrored path.

### 3.4 M4 scope: `@SolidEffect`

`@SolidEffect` declares a reactive side effect on a class. It attaches to an instance method whose body reads one or more reactive declarations and runs them as a side effect whenever those declarations change.

```dart
@SolidState()
int counter = 0;

@SolidEffect()
void logCounter() {
  print('Counter changed: $counter');
}
```

Optional `name:` parameter overrides the auto-derived debug name:

```dart
@SolidEffect(name: 'counterLogger')
void logCounter() {
  print('Counter changed: $counter');
}
```

#### Valid target

- Instance method declared with a `void` return type, with **no parameters** and **no return value**. The body may be expression-bodied (`=> ...`) or block-bodied (`{ ... }`); both forms work uniformly with the body-rewrite pipeline (Section 4.7).

#### Invalid targets (the generator must reject with a clear error)

- Method with one or more parameters (the lowered `Effect` callback signature is fixed; user-supplied parameters cannot be threaded through).
- Method with a non-`void` return type (an Effect produces side effects, not values; for a value-producing reactive expression use `@SolidState` on a getter — Section 3.1).
- `static` method (class-level, not instance — out of scope, parallel to `@SolidState`).
- `abstract` or `external` method (no body to lower).
- Getter (use `@SolidState` on a getter for a `Computed`).
- Setter.
- Top-level function.
- Field.

#### Reactive-deps requirement

The method body MUST read at least one reactive declaration — any identifier whose resolved static type is `SignalBase<T>` or a subtype. An `Effect` with zero reactive dependencies is rejected at build time: *"effect `<name>` has no reactive dependencies; use a regular method or call it once explicitly instead of `@SolidEffect`."* This mirrors Section 4.5's rejection rule for zero-dep `Computed`.

### 3.5 M5 scope: `@SolidQuery`

`@SolidQuery` declares an async reactive source on a class. It attaches to an instance method whose body fetches data from a `Future` or `Stream` and exposes the result through a `Resource<T>` whose state any reader of the call site auto-subscribes to. The annotated method is invoked at every read site as a normal method call (`fetchData()`), and the value the call returns supports `.when`, `.maybeWhen`, `.refresh`, and `.isRefreshing`.

```dart
@SolidQuery()
Future<String> fetchData() async {
  await Future.delayed(const Duration(seconds: 1));
  return 'fetched';
}
```

Stream form:

```dart
@SolidQuery()
Stream<int> watchTicks() {
  return Stream.periodic(const Duration(seconds: 1), (i) => i);
}
```

Optional `name:` parameter overrides the auto-derived debug name:

```dart
@SolidQuery(name: 'currentUser')
Future<User> fetchUser() async => api.getUser();
```

Optional `debounce:` parameter delays auto-refresh after a tracked upstream change. Useful for typeahead-style queries where rapid keystrokes should coalesce into one fetch:

```dart
@SolidQuery(debounce: Duration(milliseconds: 300))
Future<List<Item>> search() async => api.search(query);
```

Optional `useRefreshing:` parameter (default `true`) controls whether the query re-enters the `loading` state when an auto-refresh fires. With `true`, the query stays in its current `ready` / `error` state and exposes `isRefreshing == true` while the new value resolves (the upstream `flutter_solidart` default). With `false`, the query transitions back to `loading` on each refresh.

#### Valid target

- Instance method declared with one of two return-type / body-keyword pairings:
  1. `Future<T>` return type with an `async` body (expression or block).
  2. `Stream<T>` return type whose body either returns a pre-existing `Stream<T>` (synchronous body) or yields with an `async*` block body.
- The method must take **no parameters**.

#### Invalid targets (the generator must reject with a clear error)

- Method with a non-`Future`/non-`Stream` return type.
- Method whose body keyword does not match the return type (a `Future<T>`-typed body that is not `async`, or a `Stream<T>`-typed body that is neither plain-bodied nor `async*`).
- Method with one or more parameters.
- `static` method (class-level, not instance — out of scope, parallel to `@SolidState` and `@SolidEffect`).
- `abstract` or `external` method (no body to lower).
- Getter or setter.
- Top-level function.
- Field.

#### No reactive-deps requirement

A query body MAY read zero, one, or many reactive declarations. The Section 4.5 / Section 3.4 zero-deps rejection rule does NOT apply.

#### Auto-tracking of upstream reactive reads

When the body reads identifiers whose resolved type is `SignalBase<T>` (a `@SolidState` field, a `@SolidState` getter, etc.), the generator wires those reads into the lowered `Resource<T>`'s `source:` argument so the Resource auto-refreshes when any read signal changes. The Section 5.1 type-driven `.value` rewrite still applies inside the body so the bare identifiers typecheck against the lowered Signal types. See Section 4.8 for the synthesis details.

```dart
@SolidState() String? userId;

@SolidQuery(debounce: Duration(seconds: 1))
Future<String?> fetchData() async {
  if (userId == null) return null;
  return await api.fetch(userId);
}
```

Whenever `userId` changes, `fetchData()` auto-refreshes. The 1-second `debounce:` coalesces rapid changes (e.g., typeahead) into one fetch.

#### Read pattern

The user invokes the query in two distinct shapes depending on the operation. **State reads** (`.when`, `.maybeWhen`, `.isRefreshing`) call the method first, then chain on the resulting `Future<T>` / `Stream<T>`. **Refresh** uses the method tear-off (no parens) and chains `.refresh()` on the resulting function reference:

```dart
@override
Widget build(BuildContext context) {
  return fetchData().when(
    ready: (data) => Text(data),
    loading: () => CircularProgressIndicator(),
    error: (error, stackTrace) => Text('Error: $error'),
  );
}
```

`.maybeWhen` is the partial-match analogue with an `orElse:` default:

```dart
fetchData().maybeWhen(
  orElse: () => const SizedBox.shrink(),
  ready: (data) => Text(data),
)
```

`.refresh()` re-runs the fetcher imperatively (typically inside an `onPressed` callback). Note the tear-off form — `fetchData.refresh()`, not `fetchData().refresh()`:

```dart
ElevatedButton(
  onPressed: () => fetchData.refresh(),
  child: const Text('Reload'),
)
```

`.isRefreshing` exposes whether a refresh is in flight (only meaningful when `useRefreshing: true` — otherwise the query enters `loading` instead). Same call-then-chain shape as `.when`:

```dart
if (fetchData().isRefreshing) const LinearProgressIndicator(),
```

#### Source-time typechecking

The user's source layer never references `Resource<T>` or `ResourceState<T>` directly — those are codegen-internal types that appear only in `lib/`. To preserve that abstraction while keeping source-time typechecking honest, `package:solid_annotations` exports six runtime-throwing stub extension families that mirror the upstream `flutter_solidart` surface but on `Future<T>` / `Stream<T>` (and their tear-off types):

- `extension FutureWhen<T> on Future<T>` — surfaces `.when({ready, loading, error})` and `.maybeWhen({orElse, ready, loading, error})`, both returning `Widget`. Used in source by `fetchData().when(...)` / `fetchData().maybeWhen(...)`.
- `extension StreamWhen<T> on Stream<T>` — same surface as `FutureWhen` but on `Stream<T>` for the Stream-form queries.
- `extension RefreshFuture<T> on Future<T> Function()` — surfaces `.refresh()` returning `Future<void>`. Note the receiver type is the function tear-off (`Future<T> Function()`), not the Future itself; this is why the source idiom is `fetchData.refresh()` (no parens) — the user is chaining on the method reference, not on the called Future.
- `extension RefreshStream<T> on Stream<T> Function()` — same surface as `RefreshFuture` but on Stream tear-offs.
- `extension IsRefreshingFuture<T> on Future<T>` — surfaces `.isRefreshing` returning `bool`. Used by `fetchData().isRefreshing`.
- `extension IsRefreshingStream<T> on Stream<T>` — same on `Stream<T>`.

Every extension method body throws `Exception('This is just a stub for code generation.')`. The bodies are never executed at runtime because the runtime artifact lives in `lib/`, where `fetchData` is a `Resource<T>` field. The source syntax `fetchData()` survives byte-identical (no body rewrite) — at runtime it invokes the upstream `Resource<T>.call()` operator, which returns `ResourceState<T>`. The trailing `.when(...)` / `.maybeWhen(...)` / `.isRefreshing` chain then resolves to upstream `flutter_solidart` extensions on `ResourceState<T>` directly. The tear-off `fetchData.refresh()` resolves to the upstream `Resource<T>.refresh()` direct instance method. `solid_annotations` exports no extensions on `Resource<T>` or `ResourceState<T>` — the upstream `flutter_solidart` callable + extensions handle the chain.

### 3.6 M6 scope: `@SolidEnvironment`

`@SolidEnvironment` declares a dependency-injection field on a class. The field reads its value once, when the host widget mounts, from the nearest ancestor `Provider<T>` in the widget tree. The semantics mirror SwiftUI's `@Environment` property wrapper: type-keyed, invisible-lookup, and transparent reactivity (the host class never owns or disposes the injected instance — the providing scope does).

The annotation takes no parameters.

```dart
@SolidEnvironment()
late Counter counter;
```

Both `late <T>` and `late final <T>` are accepted in source — they produce the same output:

```dart
@SolidEnvironment()
late final Counter counter;
```

#### Valid target

- Instance field declared `late <T> <name>;` or `late final <T> <name>;` with NO initializer. The type must be a non-nullable, non-`SignalBase` reference type. Optional (`T?`) fields are NOT supported in M6 — the consumer declares a non-null dependency, and a missing provider raises a clear runtime error from `context.read<T>()`.
- The host class must be either a `StatelessWidget` subclass or a `State<X>` subclass.

#### Invalid targets (the generator must reject with a clear error)

- Field with an initializer (`@SolidEnvironment() late Counter c = Counter();`).
- Field without `late` (`@SolidEnvironment() Counter counter;`).
- `final` (without `late`), `const`, or `static` field.
- Method, getter, setter, top-level declaration, parameter.
- Field whose type resolves to `SignalBase<T>` or a subtype (ambiguous with `@SolidState`; the generator suggests picking one annotation).
- Field on a plain (non-Widget, non-State) class — no `BuildContext` available, so the read cannot resolve.

#### Provider side: `Provider<T>` and `.environment<T>()`

The injected instance is provided by `Provider<T>` from `package:provider`. `solid_annotations` ships a thin `.environment<T>()` extension on `Widget` as the SwiftUI-flavored alternative — it just wraps `this` in a `Provider<T>` at runtime.

Users install `package:provider` in their own pubspec because they reference `Provider<T>` / `MultiProvider` / `context.read<T>()` directly in their source code (the `depend_on_referenced_packages` lint requires it):

```bash
flutter pub add solid_annotations flutter_solidart provider
```

Two equivalent surfaces:

##### Extension form

```dart
HomePage().environment((context) => Counter())
```

The type argument is inferred from the closure's return type. Specify it explicitly only when registering an instance under a supertype (so consumers can read by the abstract type):

```dart
HomePage().environment<AuthService>((context) => RealAuthService())
```

`.environment<T>()` is a runtime extension on `Widget` shipped by `solid_annotations`. Its body is a one-line pass-through wrap:

```dart
extension WidgetEnvironment on Widget {
  Widget environment<T extends Object>(
    T Function(BuildContext) create, {
    void Function(BuildContext, T)? dispose,
  }) {
    return Provider<T>(create: create, dispose: dispose, child: this);
  }
}
```

There is NO automatic dispose behavior — the `Disposable` marker (below) is invisible to the user's source layer (it appears only in the generated `lib/` output, added by the generator at Section 10). When the injected type owns resources, the user passes `dispose:` explicitly:

```dart
HomePage().environment<Counter>(
  (context) => Counter(),
  dispose: (_, c) => c.dispose(),
)
```

The `c.dispose()` call expression typechecks at the source layer ONLY when the source-side `Counter` class itself declares a `void dispose()` method. The source analyzer cannot see the generator-synthesized `dispose()` (which exists only in lowered `lib/`). To enable this pattern for a Solid-lowered class, the user adds an empty `void dispose()` stub on the source class:

```dart
class Counter {
  @SolidState()
  int value = 0;

  void dispose() {}  // empty; generator merges synthesized reactive disposals
}
```

The empty body is appropriate because the Section 10 merge rule prepends the synthesized reactive disposals (`value.dispose();` etc.) to the user's body in the lowered output. Users don't need to write `value.dispose()` themselves; the generator handles it.

If the source-side type already declares `dispose()` (e.g., a `ChangeNotifier` subclass) or some other cleanup method (`close()`, `cancel()`, `shutdown()`), the user wires that method directly: `dispose: (_, c) => c.close()`. Solid does not constrain the cleanup-method name on non-Solid types.

Chained calls nest providers in source-declaration order:

```dart
HomePage()
  .environment((_) => Counter(), dispose: (_, c) => c.dispose())
  .environment((_) => Logger())
```

##### Widget form (uses `package:provider` directly)

```dart
Provider<Counter>(
  create: (context) => Counter(),
  dispose: (_, c) => c.dispose(),
  child: HomePage(),
)
```

The widget form is `package:provider`'s own surface and follows its conventions verbatim. For composing multiple providers, users import `MultiProvider` from `package:provider`:

```dart
MultiProvider(
  providers: [
    Provider<Counter>(create: (_) => Counter(), dispose: (_, c) => c.dispose()),
    Provider<Logger>(create: (_) => Logger()),
  ],
  child: HomePage(),
)
```

Solid does NOT ship its own provider widget or wrapper. Beyond the `.environment<T>()` extension (a one-line pass-through to `Provider<T>`), the DI surface is `package:provider` exactly as documented at <https://pub.dev/packages/provider>.

#### `Disposable` interface

```dart
abstract interface class Disposable {
  void dispose();
}
```

Exported from `solid_annotations`. The `implements Disposable` clause is added by the generator to every Solid-lowered class with a synthesized `dispose()` (any class carrying `@SolidState` / `@SolidEffect` / `@SolidQuery` declarations) — see Section 10. The marker exists ONLY in the generated `lib/` output, never in the user's `source/` class. Users who write reactive classes in `source/` therefore do NOT see `implements Disposable` on their own definitions — and the source-layer analyzer cannot resolve `c.dispose()` against a Solid-lowered type unless the user manually declares `void dispose()` on the source class (see the Provider-side note above).

Users may implement `Disposable` directly on their own non-Solid classes if they want to signal the same contract for their own dispose helpers (e.g., a runtime `is Disposable` check inside a custom callback). No Solid surface consumes the marker automatically — it is purely a typed contract that documents which generator-emitted classes carry a `dispose()` method.

#### Same-class provide-and-consume rejection

A class that both consumes (`@SolidEnvironment() late T x;`) and provides the same `T` to its own subtree (via a `Provider<T>(...)` constructor call OR a `.environment<T>(...)` extension call in its `build` body) is rejected at build time. The error names both declarations and suggests the SwiftUI-idiomatic resolutions:

- Move the consumer to a child widget.
- Own the instance locally with `@SolidState() late T x = T(...);` instead.

This matches SwiftUI: `.environment(value)` provides to the modified view's subtree, not the modifying view itself, so a self-read traps at runtime in SwiftUI too. Solid rejects statically.

#### `context.watch<T>()` is not used by Solid

`Provider` is wired into Solid as DI plumbing only. Reactivity is owned by `@SolidState` / `@SolidEffect` / `@SolidQuery` and the SignalBuilder placement rule (Section 7); the generator emits `context.read<T>()` exclusively. Users who specifically want `context.watch<T>()` semantics (rebuild when the providing scope itself replaces the instance) import `package:provider` directly and use it outside the Solid lowering.

---

## 4. Transformation Rules

Each rule shows an exact before-and-after.

### 4.1 Field → Signal

Input:

```dart
class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
```

Output (excerpt, see Section 8 for the full class transform):

```dart
final counter = Signal<int>(0, name: 'counter');
```

Rules:

- Declared type of the field → type argument of `Signal`.
- Initializer expression → first positional argument of `Signal`.
- Field name → `name:` argument, unless `@SolidState(name: '…')` overrides.

### 4.2 Field with no initializer (must be declared `late`)

Input:

```dart
@SolidState()
late String text;
```

Output:

```dart
late final text = Signal<String>.lazy(name: 'text');
```

Rules:

- For any `late` field declared without an initializer, the generator emits `Signal<T>.lazy(name: '…')` regardless of `T`. `Signal.lazy` (flutter_solidart ≥ 2.0) has no initial value; reading `.value` before the first write throws `StateError` — the one-to-one analogue of Dart's own `LateInitializationError` for `late` fields.
- The `late` modifier is preserved on the emitted Dart field so that `Signal` construction itself is deferred until first access.
- The rule is uniform across primitives, collections, and user-defined types: no defaults table, no rejection path. `@SolidState() late MyType foo;` is always valid as long as `MyType` is a real type.
- Nullable fields (Section 4.3) do not require `late` because `null` is a valid default; those continue to emit `Signal<T?>(null, name: '…')`.
- Caveat: only `Signal` has a `.lazy` constructor. `Computed` (Section 4.5) always has an initializer expression (the getter body), so this rule does not apply to it. `Resource` and `Effect` do not reach this code path.

### 4.3 Nullable field

Input:

```dart
@SolidState()
int? value;
```

Output:

```dart
final value = Signal<int?>(null, name: 'value');
```

### 4.4 Custom name

Input:

```dart
@SolidState(name: 'myCounter')
int counter = 0;
```

Output:

```dart
final counter = Signal<int>(0, name: 'myCounter');
```

### 4.5 Getter → Computed

Input:

```dart
@SolidState()
int counter = 0;

@SolidState()
int get doubleCounter => counter * 2;
```

Output:

```dart
final counter = Signal<int>(0, name: 'counter');
late final doubleCounter = Computed<int>(() => counter.value * 2, name: 'doubleCounter');
```

Rules:

- The getter body MUST read at least one reactive declaration — any identifier whose resolved static type is `SignalBase<T>` or a subtype. A `Computed` with zero reactive dependencies is rejected: *"getter `<name>` has no reactive dependencies; use `final` or a plain getter instead of `@SolidState`."*
- In M1 the only source of such a declaration is a `@SolidState` field or getter on the same class. M6 adds cross-class declarations via `@SolidEnvironment` (Section 3.6); the rule is stated in terms of resolved type, so the same Computed-body rewrite handles cross-class reads without amendment.
- Identifiers in the body that resolve to reactive declarations are rewritten with `.value` (see Section 5).
- The resulting `Computed` field is always declared `late final`, because it references other `final` instance fields whose initialization order is not guaranteed.

### 4.6 Getter with block body

Input:

```dart
@SolidState()
String get summary {
  final c = counter;
  return 'count is $c';
}
```

Output:

```dart
late final summary = Computed<String>(() {
  final c = counter.value;
  return 'count is $c';
}, name: 'summary');
```

The block is copied verbatim into a function expression with reactive-read rewriting applied.

### 4.7 `@SolidEffect` on method → `Effect`

Input:

```dart
@SolidState()
int counter = 0;

@SolidEffect()
void logCounter() {
  print('Counter changed: $counter');
}
```

Output:

```dart
final counter = Signal<int>(0, name: 'counter');
late final logCounter = Effect(() {
  print('Counter changed: ${counter.value}');
}, name: 'logCounter');
```

Rules:

- The method's body — expression body or block body — is wrapped in a `() { … }` function expression with no parameters. Section 5.1 type-driven `.value` rewriting is applied verbatim inside the body, identical to a `Computed` body (Sections 4.5–4.6).
- The `Effect` callback takes zero parameters per the upstream `flutter_solidart` API: `Effect(() { … })`. Users who want self-disposal capture the value returned by `Effect(...)` (a disposer) by hand outside the annotation flow; the generator does not surface that surface area.
- The resulting field is always declared `late final`, parallel to `Computed` (Section 4.5): the initializer reads other reactive instance fields, so its evaluation must defer until `this` is in scope.
- Method-name → `name:` argument, unless `@SolidEffect(name: '…')` overrides — symmetric with the `@SolidState` rule (Sections 4.1, 4.4).
- When the synthesized State class declares one or more `late final` Effect fields, the generator emits an `initState()` override that calls `super.initState()` then reads each Effect field via a bare-identifier statement (`<effectName>;`) in declaration order. This materializes each lazy `late final` initializer at mount time, triggering the upstream `Effect` factory's autorun (`flutter_solidart` `Effect.run()` in the factory `finally`) and registering reactive dependencies before any user interaction. Without this read, no access to the Effect field occurs until `dispose()`, so the Effect never fires.
- The cross-cutting rules in Sections 5.1, 5.2, 5.4, 5.5, 6.0, 6.2, 6.4, and 9 apply uniformly inside `Effect` bodies. The body is reactive code in the same sense as a `Computed` or a `build` body, so the type-driven `.value` rewrite, string-interpolation rewrite, no-double-append guard, shadowing handling, untracked-context detection, `.untracked` opt-out, and import-rewrite rules are reused without amendment. No new SPEC rule is required for `Effect` bodies.

### 4.8 `@SolidQuery` on method → `Resource`

Input (Future form, no upstream signals):

```dart
@SolidQuery()
Future<String> fetchData() async {
  await Future.delayed(const Duration(seconds: 1));
  return 'fetched';
}
```

Output:

```dart
late final fetchData = Resource<String>(
  () async {
    await Future.delayed(const Duration(seconds: 1));
    return 'fetched';
  },
  name: 'fetchData',
);
```

Input (Future form, body reads ONE upstream `@SolidState` signal — auto-tracking, direct source):

```dart
@SolidState() String? userId;

@SolidQuery(debounce: Duration(seconds: 1))
Future<String?> fetchData() async {
  if (userId == null) return null;
  return await api.fetch(userId);
}
```

Output:

```dart
final userId = Signal<String?>(null, name: 'userId');

late final fetchData = Resource<String?>(
  () async {
    if (userId.value == null) return null;
    return await api.fetch(userId.value);
  },
  source: userId,
  debounceDelay: const Duration(seconds: 1),
  name: 'fetchData',
);
```

Input (Future form, body reads TWO upstream signals — synthesized Record-Computed source):

```dart
@SolidState() String? userId;
@SolidState() String? orgId;

@SolidQuery()
Future<User?> fetchUser() async {
  if (userId == null || orgId == null) return null;
  return await api.fetch(userId, orgId);
}
```

Output:

```dart
final userId = Signal<String?>(null, name: 'userId');
final orgId = Signal<String?>(null, name: 'orgId');

late final _fetchUserSource = Computed<(String?, String?)>(
  () => (userId.value, orgId.value),
  name: 'fetchUser_source',
);

late final fetchUser = Resource<User?>(
  () async {
    if (userId.value == null || orgId.value == null) return null;
    return await api.fetch(userId.value, orgId.value);
  },
  source: _fetchUserSource,
  name: 'fetchUser',
);
```

Stream form:

```dart
@SolidQuery()
Stream<int> watchTicks() {
  return Stream.periodic(const Duration(seconds: 1), (i) => i);
}
```

Output:

```dart
late final watchTicks = Resource<int>.stream(
  () => Stream.periodic(const Duration(seconds: 1), (i) => i),
  name: 'watchTicks',
);
```

Rules:

1. **One emitted declaration per query.** The annotated method is replaced by a single `late final <name>` field holding the upstream `Resource<T>` (or `Resource<T>.stream(...)`). No private wrapper, no thin-accessor, no underscore prefix. The field bears the same identifier the user wrote on the source-side method, so consumers continue to reference it by that name. The original method's body becomes the Resource's fetcher closure.

2. **Source-side `<name>()` call sites survive byte-identical in lowered output.** In the user's source, state reads chain after a method call: `fetchData().when(...)`. After lowering, `<name>` is a `Resource<T>` field, not a method — but `Resource<T>` upstream defines `ResourceState<T> call() => state;`, so the syntax `fetchData()` resolves to `Resource.call()` at runtime, which returns `ResourceState<T>`. The trailing `.when(...)` / `.maybeWhen(...)` / `.isRefreshing` chains then resolve directly to upstream `flutter_solidart` extensions on `ResourceState<T>`. No body rewrite is applied to the call expression: source `fetchData().when(...)` is byte-identical to lowered `fetchData().when(...)`. The `.refresh()` form uses a method tear-off in source (`fetchData.refresh()` — no parens after `fetchData`); after lowering, `<queryName>` is a `Resource<T>` field, and `.refresh()` resolves to the upstream direct instance method on `Resource<T>` — also byte-identical between source and output.

3. **SignalBuilder placement detects query call expressions as tracked reads.** Although the call expression itself is not rewritten, the body-rewrite visitor still records the offset of each `<queryName>()` invocation in the tracked-read set so that Section 7's SignalBuilder placement wraps the enclosing widget subtree. Detection is name-based on the visitor's per-class set of `@SolidQuery` method names: a zero-argument `MethodInvocation` whose target is a bare `SimpleIdentifier` matching a query name (and not shadowed by a local) is a tracked read. The runtime subscription happens inside `Resource.call()` → `state` → upstream `setCurrentSub`, so the SignalBuilder rebuild fires correctly when the Resource emits a new state. Shadowing follows the Section 5.5 rule: if a local with the same name shadows the query, the call is left alone and not marked as a tracked read.

4. **Body rewrite.** The original method's body is wrapped in a parameterless function expression preserving the `async` / `async*` keyword (or returning a `Stream<T>` directly for the synchronous Stream form). Section 5.1 type-driven `.value` rewrite applies inside the body so any `@SolidState` field / getter reads are correctly unboxed.

5. **Auto-tracking — direct source for one dep, synthesized Record-Computed for multiple.** The body's reactive reads (identifiers whose resolved static type is `SignalBase<T>`) determine the Resource's `source:` argument:
   - **Zero reactive reads**: no `source:` argument emitted; the Resource only refreshes via explicit `.refresh()` calls.
   - **One reactive read**: the read identifier (a `Signal` or `Computed`) is passed directly as `source: <name>`. No synthesized field is emitted — wrapping a single Signal in a Computed that just returns its `.value` would be a no-op, so the generator skips it. The upstream `Resource<T>` constructor accepts any `SignalBase<dynamic>` as `source:`, and `Signal<T>` / `Computed<T>` already qualify.
   - **Two or more reactive reads**: the generator synthesizes a `late final _<name>Source = Computed<(T1, T2, …)>(() => (s1.value, s2.value, …), name: '<name>_source')` field whose value is a `Record` combining all tracked values. The Computed is passed as `source: _<name>Source`. Records compare by value-equality, so changing ANY tracked signal flips the Record's identity, the Resource sees its source change, and the fetcher re-runs (subject to any `debounce:` delay). The synthesized field is the only reason an underscore-prefixed Resource-related declaration ever appears in lowered output.

6. **`Resource<T>(...)` for Future, `Resource<T>.stream(...)` for Stream.** Type argument `T` is the inner type of the original `Future<T>` / `Stream<T>` return signature.

7. **`late final` is required** on the Resource field and (when synthesized) on the source Record-Computed field, parallel to `Computed` (Section 4.5) and `Effect` (Section 4.7): each initializer references other reactive instance fields, so its evaluation must defer until `this` is in scope.

8. **Method-name → `name:` argument** unless `@SolidQuery(name: '…')` overrides. When a Record-Computed source is synthesized, it uses `'<methodName>_source'` (or `'<overrideName>_source'` when `name:` is overridden) as its debug name.

9. **Annotation parameters propagate.** `@SolidQuery(debounce: Duration(...))` becomes the Resource's `debounceDelay:` argument. `@SolidQuery(useRefreshing: false)` becomes `useRefreshing: false` on the Resource (the upstream default `useRefreshing: true` is omitted from the emitted code to keep generated lines short).

10. **Lazy by default.** The `late final <name>` field stays uninitialized until first read. The first read happens at the first reactive call site (e.g., the body of a `SignalBuilder`-wrapped `<name>().when(...)` chain in `build` — `Resource.call()` is invoked, which triggers the late-final initializer and reads `.state`, firing the upstream Resource's first fetch). Resources do NOT use the Section 4.7 / Section 8.3 forced-materialization pattern that `Effect` requires.

11. **Disposal.** The `<name>` Resource field always joins the unified ordered dispose list. The `_<name>Source` Record-Computed (when synthesized) is emitted immediately before its Resource and joins the dispose list in that source-declaration position, so reverse-declaration disposal (Section 10) tears the Resource down before the Record-Computed and before any Signals they read.

### 4.9 `@SolidEnvironment` field → `late final` + `context.read<T>()`

Input:

```dart
class CounterDisplay extends StatelessWidget {
  CounterDisplay({super.key});

  @SolidEnvironment()
  late Counter counter;

  @override
  Widget build(BuildContext context) {
    return Text(counter.value.toString());
  }
}
```

Output (where `Counter` is a separate plain class with a `@SolidState int value = 0;` field — its own lowering follows Sections 4.1 and 8.3 plus the Section 10 `Disposable` marker rule):

```dart
class CounterDisplay extends StatefulWidget {
  CounterDisplay({super.key});

  @override
  State<CounterDisplay> createState() => _CounterDisplayState();
}

class _CounterDisplayState extends State<CounterDisplay> {
  late final counter = context.read<Counter>();

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text(counter.value.value.toString());
      },
    );
  }
}
```

Rules:

1. **`late final ... = context.read<T>()` synthesis.** The annotated `late <T> <name>;` (or `late final <T> <name>;`) field becomes `late final <name> = context.read<<T>>();` on the synthesized State class (or in place on an existing `State<X>`). The type annotation is dropped in the lowered field — Dart infers it from `context.read<T>()`.

2. **No `initState()` materialization splice.** Unlike `@SolidEffect` (Section 4.7), which has no other consumer and is force-materialized in `initState`, an `@SolidEnvironment` field IS the consumed value — any read inside `build`, an `@SolidEffect` body, a `@SolidState` getter (`Computed`) body, or a `@SolidQuery` body naturally triggers the late-final initializer. Lazy initialization is correct; the generator emits no bare-identifier read for the field.

3. **`@SolidEffect` materialization is unchanged.** When the same class hosts both `@SolidEnvironment` and `@SolidEffect` declarations, the existing `@SolidEffect` materialization splice (Section 4.7) is unaffected. When the effect's late-final initializer runs and its body reads the env field, the env's own initializer fires transitively. No special interaction rule.

4. **Class-kind forcing.** `@SolidEnvironment` reads `context`, which is only available on a `State<X>` instance. A source `StatelessWidget` that hosts at least one `@SolidEnvironment` field is split into a `StatefulWidget` + `State<X>` pair, identical to the existing `@SolidState` field-forcing rule in Section 8.1.

5. **No host-side disposal.** The injected instance is owned by the providing `Provider<T>` (its `dispose:` callback). The host class never adds the env field to its dispose-name list (Section 10).

6. **Cross-class reactive reads use the §5.1 type-driven rewrite.** When the consumer body reads `counter.value` where `counter` is a `@SolidEnvironment` field of type `Counter` and `Counter.value` resolves to `Signal<int>`, the chain becomes `counter.value.value` per Section 5.1. The §7 SignalBuilder placement rule wraps the enclosing subtree.

7. **`Provider<T>(...)` and `.environment<T>(...)` calls are NOT rewritten.** When the source uses `Provider<T>(create: ..., child: ...)` directly OR chains `.environment<T>(...)` on a child widget, source and lib are byte-identical for those call expressions. The `.environment<T>()` extension's body is a runtime helper in `solid_annotations` that wraps in `Provider<T>` at call time; no codegen rewrite is needed.

8. **Import-add.** When at least one `@SolidEnvironment` field exists in the output file, the generator emits `import 'package:provider/provider.dart' show ReadContext;`. See Section 9. Users list `provider` in their own pubspec because they reference `Provider<T>` / `MultiProvider` / `context.read<T>()` in their source code (per the `depend_on_referenced_packages` lint).

---

## 5. Reactive-Read Rules

When a generated piece of code (anything under `lib/`) references a reactive value, the reference is rewritten to read through the reactive primitive. The decision is **type-driven**, not name-driven: the generator uses the Dart analyzer's resolved static type, not a name-set, to decide whether to append `.value`.

### 5.1 Identifier rewrite

The rewrite is **type-driven and chain-aware**: any expression position whose resolved static type is `SignalBase<T>` or a subtype (`Signal<T>`, `Computed<T>`, `ReadSignal<T>`) from `package:flutter_solidart` receives a `.value` append at that position. The rule applies uniformly to:

- Bare `SimpleIdentifier`s — same-class same-class `@SolidState` reads (M1 case).
- `PrefixedIdentifier` and `PropertyAccess` chains of arbitrary depth — cross-class reactive reads (M6 case, e.g. an `@SolidEnvironment` field whose type carries `@SolidState` declarations).

For a chain `a.b.c.d` where any prefix resolves to a `SignalBase<T>`, the rewriter inserts `.value` at every such position. Example: if `a.b.c` resolves to `Signal<int>`, the chain becomes `a.b.c.value.d` (assuming `.d` is a member on `int`); if `a.b` resolves to `Signal<Foo>` and `Foo.c.d` is a plain non-reactive access, the chain becomes `a.b.value.c.d`.

`@SolidQuery` (Section 3.5) does NOT introduce a `SignalBase<T>` identifier at the call site: a query is invoked as a method call (`fetchData()`), and the lowered method returns `Resource<T>` (Section 4.8), which the call-site reads via the `.when` / `.maybeWhen` / `.refresh` / `.isRefreshing` extensions on `Resource<T>` from `solid_annotations`. The Section 5.1 `.value` rewrite does not apply to query call expressions.

Source (same-class, M1 case):

```dart
Text(counter.toString())
```

Output (inside a SignalBuilder — see Section 7):

```dart
Text(counter.value.toString())
```

Source (cross-class via `@SolidEnvironment`, M6 case):

```dart
@SolidEnvironment() late Counter counter;
// where Counter has `@SolidState() int value = 0;`
// …
Text(counter.value.toString())
```

Output:

```dart
Text(counter.value.value.toString())
```

The existing no-double-append guard (Section 5.4) prevents `.value.value.value` chains: once any chain position has been rewritten, the outer expression's type is the unboxed payload, so the rule stops applying. The shadowing rule (Section 5.5) applies — a local `value` of type `int` that shadows `counter.value` is not rewritten.

Tracked-read offset collection (Section 7) records the OUTERMOST tracked position in each chain (the last `SignalBase` access), so `SignalBuilder` placement wraps the enclosing subtree as for same-class reads.

### 5.2 String interpolation rewrite

Inside string interpolation, `$name` (implicit `.toString()` call) becomes `${name.value}`.

Source:

```dart
Text('Counter is $counter')
```

Output:

```dart
Text('Counter is ${counter.value}')
```

Already-qualified `${counter.value}` in source stays as-is (no double-append).

### 5.3 Compound assignment rewrite

Only the **left-hand side** of an assignment expression is the write. The **right-hand side** is a read, and is subject to the normal `.value` rewriting rule from Section 5.1. In `counter = counter + 1`, the left `counter` is a write (never subscribes — see Section 6.0) and the right `counter` is a read (receives `.value`).

Source:

```dart
onPressed: () => counter++
onPressed: () { counter = counter + 1; }
onPressed: () { counter += 5; }
```

Output (see Section 6.0 — writes never trigger subscription, but their RHS reads still get `.value`):

```dart
onPressed: () => counter.value++
onPressed: () { counter.value = counter.value + 1; }
onPressed: () { counter.value += 5; }
```

Supported operators: `=`, `+=`, `-=`, `*=`, `/=`, `~/=`, `%=`, `??=`, `<<=`, `>>=`, `|=`, `&=`, `^=`, `++` (prefix/postfix), `--` (prefix/postfix).

Compound-assignment operators (`+=`, `++`, etc.) are sugar: the LHS position is simultaneously a read (to compute the new value) and a write (to store it). The `.value` appears once per textual occurrence, matching Dart's evaluation of the compound form.

### 5.4 Type-aware `.value` append

The rewriter appends `.value` only when the receiver's resolved static type is `SignalBase<T>` or a subtype. If the type is anything else, the rewriter leaves the expression untouched.

This matters because `.value` is a common field name on ordinary Dart objects (e.g., `TextEditingController.value`, `ValueNotifier.value`). A name-based rewriter would produce nonsensical `controller.value.value` code. The type-based rule is the only correct form and is also inherently idempotent: once `counter.value` has been rewritten, the outer expression's type is `int` (not `SignalBase<int>`), so the rule stops applying.

The generator MUST resolve types through `package:analyzer`. Name-matching, regex, or string heuristics are not acceptable implementations of this rule.

### 5.5 Shadowing

Shadowing is handled automatically because the rule in Section 5.1 is type-driven. If a local variable or parameter with a non-`SignalBase` type shadows a reactive-field name, the analyzer resolves the inner identifier to the local's type and the `.value` rewrite does not fire.

Source:

```dart
@SolidState() int counter = 0;

Widget build(BuildContext context) {
  return Builder(builder: (context) {
    final counter = 'local'; // shadows the field; type is String
    return Text(counter);     // stays as `counter`
  });
}
```

Output: the inner `counter` stays untouched. The outer field reference, if present, still rewrites normally because its resolved type is `Signal<int>`.

M1 tests include a shadowing case to prove the rule.

---

## 6. Untracked-Context Rules

### 6.0 Reads vs writes

Every reference to a reactive identifier is either a **read** or a **write**. They behave differently.

- A **write** is any assignment form listed in Section 5.3 (`=`, compound assignments, `++`, `--`). Writes never subscribe to the signal — subscribing to your own write is meaningless. The rewriter appends `.value` so the expression typechecks, but writes never cause `SignalBuilder` wrapping under any rule in this section.
- A **read** observes the reactive value: `Text(counter)`, `if (counter > 0) ...`, `print(counter)`. Reads may or may not subscribe, depending on the context defined below.

Tracking rules in the remainder of Section 6 apply only to reads.

### 6.1 Tracked vs untracked reads

A read is **tracked** if the widget subtree that contains it must rebuild when the signal changes. A read is **untracked** if the expression reads the current value but must NOT cause its enclosing widget subtree to subscribe.

Untracked reads still get `.value` appended (so they typecheck). They just do NOT trigger `SignalBuilder` wrapping of their parent widget subtree (Section 7).

### 6.2 Reads inside user-interaction callbacks

A read is untracked when the identifier appears inside a function expression that is the value of a named argument to a widget constructor and that named argument is a user-interaction callback. The callback fires in response to a user gesture, not in response to signal changes, so subscribing the enclosing widget to the read would be wrong.

A named argument is treated as a user-interaction callback when both hold:

1. Its parameter name matches the pattern `on[A-Z]\w*` — `on` followed by an uppercase letter followed by zero or more word characters.
2. Its argument value is a function expression (a `FunctionExpression` AST node).

The pattern match covers every Flutter built-in callback (`onPressed`, `onTap`, `onLongPress`, `onDoubleTap`, `onChanged`, `onSubmitted`, `onEditingComplete`, `onFieldSubmitted`, `onSaved`, the `onHorizontalDrag*` / `onVerticalDrag*` / `onPan*` / `onScale*` families, `onHover`, `onExit`, `onEnter`, `onFocusChange`, `onDismissed`, `onClosing`, `onAccept`, `onWillAccept`, `onLeave`, `onMove`, and Flutter additions like `onRefresh`, `onGenerateRoute`, `onWillPop`, etc.) and any user-defined callback on a third-party or in-repo widget (`onTrigger`, `onSelect`, `onCustomAction`, etc.). The function-expression guard prevents non-callback `on*` named arguments (rare — e.g. an enum-valued `onFoo: Foo.bar`) from matching.

For a callback whose parameter name does not begin with `on` (very rare; Flutter and community convention prefixes all interaction callbacks with `on`), the developer opts out explicitly via `untracked(() => ...)` (Section 6.4).

A future SPEC revision paired with the M3 type-resolution pivot may refine this rule to detect void-returning function-typed parameters independent of name, making the `on*` convention unnecessary. Until then, the name-pattern + function-expression rule is the canonical detection mechanism.

The example below shows one read and one write inside `onPressed`. The read (`if (counter > 10)`) is untracked by this rule. The write (`counter++`) is untracked by Section 6.0 and would be untracked even outside a callback. Neither causes `SignalBuilder` wrapping.

Source:

```dart
FloatingActionButton(
  onPressed: () {
    if (counter > 10) showDialog(...);  // read, untracked by Section 6.2
    counter++;                           // write, untracked by Section 6.0
  },
  child: const Icon(Icons.add),
)
```

Output:

```dart
FloatingActionButton(
  onPressed: () {
    if (counter.value > 10) showDialog(...);
    counter.value++;
  },
  child: const Icon(Icons.add),
)
// NOT wrapped in SignalBuilder
```

### 6.4 Explicit opt-out via the `.untracked` extension getter

To read a reactive field's current value without subscribing the enclosing widget subtree, append `.untracked` to the field reference at the call site.

`solid_annotations` exports `extension UntrackedExtension<T> on T { T get untracked => this; }`, so the source typechecks before generation: `counter.untracked` has the same type as `counter` (an identity at runtime).

Source:

```dart
Container(key: ValueKey(counter.untracked), child: const Text('hi'))
```

Output:

```dart
Container(key: ValueKey(counter.untrackedValue), child: const Text('hi'))
// NOT wrapped in SignalBuilder
```

Rules:

- The generator detects `<reactiveField>.untracked` as a `PrefixedIdentifier`, replaces the whole expression with `<reactiveField>.untrackedValue` (the runtime primitive on `ReadableSignal<T>`), and excludes the offset from the tracked-read set. No `SignalBuilder` wrap occurs at this position, regardless of structural context — even if the read sits inside an existing `SignalBuilder` from a sibling tracked read, `untrackedValue` bypasses `reactiveSystem.setCurrentSub` and never subscribes.
- Inside string interpolations, only the long form `'${counter.untracked}'` expresses the untracked intent. The short form `'$counter.untracked'` parses as `${counter}` followed by a literal `.untracked` string suffix and rewrites as a normal tracked read of `counter`.
- Detection is name-based on the prefix (the M3-05 type-resolution deferral); the existing shadowing guard (Section 5.5) suppresses the rewrite when a local variable shadows the field.

**Migration from the v1 function-call form:** `untracked(() => ...)` is no longer supported. Writing it in source produces a build-time `CodeGenerationError` directing the user to the extension form. Replace each occurrence: `untracked(() => counter)` → `counter.untracked`.

### 6.5 Everything else is tracked

If a read is not in one of the contexts defined in Sections 6.2 or 6.4, it is tracked. The containing widget subtree must be wrapped in `SignalBuilder` (Section 7).

### 6.6 Nested cases

Tracking is determined by the innermost enclosing AST ancestor that matches a rule. A `Text(counter)` inside an `onPressed` callback is untracked. A `Text(counter)` outside any callback is tracked.

Closures passed to non-user-interaction parameters (e.g., `Builder(builder: ...)`, `LayoutBuilder(builder: ...)`, `ListView.builder(itemBuilder: ...)`) do not create an untracked context. Reads inside those closures are tracked and trigger `SignalBuilder` wrapping per Section 7. Only the parameter names enumerated in Section 6.2 mark reads as untracked.

Example:

```dart
Builder(builder: (context) => Text(counter))
```

Output wraps the `Text` in a `SignalBuilder` (see Section 7). `Builder`'s `builder:` is not on the Section 6.2 list.

---

## 7. SignalBuilder Placement Rules

`SignalBuilder` is the wrapper from `flutter_solidart` that subscribes to signals read inside its builder callback and rebuilds only the enclosed subtree.

### 7.1 Where to wrap

A widget subtree needs `SignalBuilder` wrapping if and only if all three hold:

1. The subtree is a widget expression (an `InstanceCreationExpression` that constructs a widget, or a reference to one) used as the return value of the `build` method, or as the value of a child/children parameter of another widget.
2. The subtree contains at least one **tracked** reactive read (Section 6.5).
3. The subtree is not already inside a `SignalBuilder`.

### 7.2 Minimal-subtree rule (fine-grained)

When multiple candidate subtrees in a build tree contain tracked reactive reads, wrap the **smallest** subtree for each independent read. "Smallest" is defined by the widget-subtree hierarchy: if the tracked read appears inside a `Text('$counter')`, wrap that `Text`, not its `Column` ancestor.

The practical consequence, illustrated by the canonical counter:

```dart
Scaffold(
  body: Center(
    child: Text('Counter is $counter'),   // ← ONLY this Text is wrapped
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: () => counter++,           // write — no wrap (Section 6.0)
    child: const Icon(Icons.add),
  ),
)
```

Output:

```dart
Scaffold(
  body: Center(
    child: SignalBuilder(
      builder: (context, child) {
        return Text('Counter is ${counter.value}');
      },
    ),
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: () => counter.value++,
    child: const Icon(Icons.add),
  ),
)
```

### 7.3 Already-inside-SignalBuilder rule

If a developer has manually written `SignalBuilder(...)` in source (rare but legal), the generator does NOT add a second wrapper.

### 7.4 Multiple independent tracked reads

If two sibling widgets each contain a tracked read of a different signal, each is wrapped in its own `SignalBuilder`. Siblings do not share wrappers.

### 7.5 Nested tracked reads

If an outer widget and an inner widget both contain tracked reads, only the inner widget is wrapped. The outer widget relies on the inner `SignalBuilder` to trigger the rebuild of its subtree. This is the "only the leaf rebuilds" guarantee.

---

## 8. Class-Kind Handling

`@SolidState`, `@SolidEffect`, `@SolidQuery`, and `@SolidEnvironment` can appear on classes of four kinds. Each is transformed differently. If a class has no Solid annotations, it passes through unchanged.

`@SolidEnvironment` (Section 3.6) constrains the host-class set further: it is valid only on `StatelessWidget` and `State<X>` subclasses (Sections 8.1, 8.2). Plain classes (Section 8.3) are rejected because they lack a `BuildContext`. The `late final ... = context.read<T>();` lowering rule (Section 4.9) applies to whichever of 8.1 or 8.2 hosts the field.

### 8.1 StatelessWidget with ≥1 `@SolidState`

The class is rewritten as a `StatefulWidget` + `State<X>` pair. All reactive fields, getters, and generated `SignalBuilder`-wrapped build output live on the State. The public widget keeps its original constructor and key forwarding.

Non-`@SolidState` fields are partitioned by their relationship to the class's generative constructors (unnamed and named). A field stays on the public widget class if its name appears either as a `this.X` parameter or as the LHS of an initializer-list assignment (`: field = expr`) on **any** generative constructor of the class. Every other non-`@SolidState` field — inline-initialized, `late`, or otherwise unbound to a constructor — moves to the State class verbatim. Widget-config fields (the `this.X` props) retain their normal Flutter semantics: the State reads them via `widget.X`. Factory constructors do not contribute to the binding set; they construct an instance via their body and never bind a `this.X` parameter.

Every constructor on the original class — unnamed, named, and factory — is preserved verbatim on the rewritten public widget class.

Source:

```dart
class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Text('$counter');
  }
}
```

Output:

```dart
class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text('${counter.value}');
      },
    );
  }
}
```

The generator does not add or remove `const` on any constructor. After the class split moves every mutable `@SolidState` field off the widget, the rewritten widget is typically `const`-eligible per Dart's own rules — `dart fix --apply` adds `const` to the user's verbatim constructors as a post-processing step, in line with Section 9's delegation of lint-time fixes to dart fix. See Section 14 item 7.

### 8.2 StatefulWidget with `@SolidState` on its State

No class rewriting. Reactive declarations and build rewriting happen in-place on the existing State class. This is the fix for issue #3.

### 8.3 Plain class (no Widget superclass) with `@SolidState`

Reactive declarations are applied in-place. A `dispose()` method is synthesized that disposes every generated Signal/Computed. The class header gains `implements Disposable` per the Section 10 merge rule, and the synthesized `dispose()` carries `@override`. No State wrapper.

Source:

```dart
class Counter {
  @SolidState()
  int value = 0;
}
```

Output:

```dart
class Counter implements Disposable {
  final value = Signal<int>(0, name: 'value');

  @override
  void dispose() {
    value.dispose();
  }
}
```

If the developer has already declared a `dispose()` method, the generator merges: the generated disposal calls are prepended to the existing body, then `super.dispose()` is emitted if and only if the class's supertype chain contains a `dispose()` method (e.g., `State<T>`, `ChangeNotifier`). The generator determines this via the analyzer's type resolution, not by name matching. For a plain class with no `dispose()` in the supertype chain, `super.dispose()` is omitted. The `Disposable` merge rule from Section 10 also applies to user-defined dispose: the synthesized reactive disposals are prepended; the user's body is preserved verbatim afterwards.

`@SolidEnvironment` is NOT valid on a plain class — see Section 3.6 invalid-targets list.

When the plain class has one or more `@SolidEffect` methods, the generator synthesizes a no-arg constructor whose body reads each Effect field by bare identifier in declaration order — analogue of the State class's `initState()` materialization (§4.7). The synthesized constructor takes the place a widget lifecycle would otherwise serve, activating each `late final` Effect at construction time so its autorun fires once with the initial Signal values and subscribes to subsequent changes. `@SolidQuery` fields are NOT materialized in the synthesized constructor — they are lazy by default and initialize on first thin-accessor invocation (Section 4.8). Plain classes with a user-defined constructor and `@SolidEffect` are not supported in this milestone — the generator rejects with a `CodeGenerationError`.

### 8.4 StatelessWidget with zero `@SolidState` annotations

Passes through unchanged to `lib/`.

---

## 9. Import Rules

The generated `lib/` file's imports are computed from the source's imports plus what the generator added:

- Add `import 'package:flutter_solidart/flutter_solidart.dart';` if the generated output references any of: `Signal`, `Computed`, `Effect`, `Resource`, `SignalBuilder`, `SolidartConfig`, `untracked`.
- Add `import 'package:provider/provider.dart' show ReadContext;` if the generated output references any `context.read<T>()` call site — i.e., when at least one `@SolidEnvironment` field exists in the file (Section 4.9). If the source already imports `package:provider`, no second import is added; the existing one already exposes `ReadContext`.
- Every other import in the source is preserved verbatim, including aliases and `show`/`hide` combinators.
- Unused imports left behind (e.g., `package:solid_annotations/...` when no annotation references remain in the generated output) are removed by running `dart fix --apply` on the generated file. The generator does NOT try to detect unused imports itself.

This is the fix for issue #8.

---

## 10. `dispose()` Contract

Every generated `Signal`, `Computed`, `Effect`, and `Resource` (including any synthesized `_<name>Source` Record-Computed wired into a multi-dep `@SolidQuery`'s `source:` for auto-tracking — Section 4.8 rule 3) must be disposed when its owning class is disposed. The merging algorithm below applies identically to every class kind; the per-kind sections (8.1–8.3) describe how the algorithm is triggered.

Algorithm: if the target class already has a `dispose()` body, prepend one `xxx.dispose()` call per reactive declaration to the top of the body and leave the rest untouched; if no `dispose()` exists, synthesize one. Emit `super.dispose()` at the end if and only if the class's supertype chain contains a `dispose()` method (e.g., `State<T>`, `ChangeNotifier`); the generator determines this via the analyzer's type resolution, not by name matching. For a plain class with no `dispose()` in the supertype chain, omit `super.dispose()`.

Disposal order is **reverse declaration order**: dependents are disposed before their dependencies. Because a `Computed` must always be declared after the `Signal`s it reads, an `Effect` must always be declared after the `Signal`s/`Computed`s it reads, and a `Resource` whose fetcher reads other reactive declarations must be declared after those declarations (those declarations are the dependents' dependencies), reverse declaration order guarantees a dependent (`Effect`, `Computed`, or `Resource`) is disposed first and a dependency (`Signal`, `Computed`, or another `Resource`) is never disposed while a live subscriber still holds a subscription to it. When a synthesized `_<name>Source` Record-Computed is emitted (multi-dep `@SolidQuery` only — see Section 4.8 rule 3), it is emitted immediately before the `_<name>` Resource it feeds, so reverse-order disposal tears the Resource down first, then the source Computed, then the underlying Signals.

`@SolidEnvironment` fields (Section 3.6) are NOT included in the dispose-name list. The host class never owns the injected instance — the providing `Provider<T>` (via its own `dispose:` callback) is responsible for cleanup when the providing scope tears down.

### `Disposable` marker interface (plain classes)

Solid-lowered plain classes (Section 8.3) — every class with reactive declarations that gets a synthesized `dispose()` — declare `implements Disposable` in their lowered output and annotate the synthesized `dispose()` with `@override`. `Disposable` is exported from `solid_annotations` (Section 3.6). The marker is added BY THE GENERATOR: it appears only in the lowered `lib/` output, never in the user's source class. So the user does not see `implements Disposable` on their own source declaration and cannot rely on it for compile-time resolution inside source code.

Practical consequence: a user who wants to wire `Provider<Counter>(dispose: (_, c) => c.dispose())` (or the `.environment<T>()` extension's `dispose:` argument) MUST manually declare a `void dispose()` method on the source-side `Counter` class, because the source-layer analyzer cannot see the generator-synthesized `dispose()`. The empty-body convention is fine — the dispose-body merge rule below prepends the synthesized reactive disposals to whatever the user wrote:

```dart
// source/
class Counter {
  @SolidState()
  int value = 0;

  void dispose() {}
}
```

After lowering, the merged dispose body contains the prepended `value.dispose();` plus the user's empty body. At runtime, calling `c.dispose()` from the Provider callback runs the merged body.

Merge rule for the implements clause:

1. If the source class has NO `implements` clause, the lowering appends `implements Disposable` after any existing `extends` / `with` clauses (and before the class body).
2. If the source class has an `implements <T1>, <T2>, ...` clause, the lowering appends `, Disposable` to the end of that list.
3. If the source class already names `Disposable` (by simple identifier match) in its existing implements clause, no change is made; the synthesized `dispose()` still gets `@override`.

Source:

```dart
class Counter implements Comparable<Counter> {
  @SolidState() int value = 0;

  @override
  int compareTo(Counter other) => value - other.value;
}
```

Output:

```dart
class Counter implements Comparable<Counter>, Disposable {
  final value = Signal<int>(0, name: 'value');

  @override
  int compareTo(Counter other) => value.value - other.value.value;

  @override
  void dispose() {
    value.dispose();
  }
}
```

`extends` and `with` clauses are preserved verbatim; only the `implements` list grows. The `compareTo` body's `value` reads receive the §5.1 same-class `.value` rewrite.

### `dispose()` body merge (plain classes with user-defined dispose)

When the source plain class has reactive declarations AND a user-defined `void dispose()` method, the synthesized reactive disposals (in reverse-declaration order) are PREPENDED to the user's body; the user's body is preserved verbatim afterwards. This parallels Section 14 item 4's existing rule for `State<X>`.

When the user's source `dispose()` lacks an `@override` annotation, the generator prepends one — the merged dispose always overrides `Disposable.dispose()` (plain class) or the supertype's `dispose()` (`State<X>`). The typical user pattern is to write a plain `void dispose() { … }` in source (no `@override`, no `implements Disposable`); the generator adds both during lowering.

Source:

```dart
class Counter implements Disposable {
  @SolidState() int value = 0;

  final StreamSubscription<void> _ticker = Stream<void>.periodic(
    const Duration(seconds: 1),
  ).listen((_) {});

  @override
  void dispose() {
    unawaited(_ticker.cancel());
    print('counter cleanup');
  }
}
```

Output:

```dart
class Counter implements Disposable {
  final value = Signal<int>(0, name: 'value');

  final StreamSubscription<void> _ticker = Stream<void>.periodic(
    const Duration(seconds: 1),
  ).listen((_) {});

  @override
  void dispose() {
    value.dispose();
    unawaited(_ticker.cancel());
    print('counter cleanup');
  }
}
```

Plain classes have no `super.dispose()` to relocate (no superclass dispose chain unless the user wrote `extends Foo`, in which case the user's body already includes whatever super call they wrote, and the generator preserves it untouched).

---

## 11. File Layout on Disk

A consumer app using Solid looks like this:

```
my_app/
  source/
    main.dart             ← annotated; committed
    counter.dart          ← annotated; committed
  lib/
    main.dart             ← generated; committed
    counter.dart          ← generated; committed
  analysis_options.yaml   ← lint suppressions for source
  pubspec.yaml
  .gitignore              ← excludes .dart_tool/, build/
```

The `source/` tree mirrors `lib/` one-to-one. Every file under `source/` has a counterpart at the mirrored path under `lib/` (`.dart` files with `@Solid*` annotations transformed per Sections 4–10; all other files copied verbatim per Section 2).

Third-party code generators (freezed, json_serializable, drift, etc.) may emit `.g.dart` or `.freezed.dart` files under `source/`. Solid copies those files verbatim to the mirrored path under `lib/`. Solid itself emits only plain `.dart` filenames — no `.g.dart` suffix for Solid's own output. (Test golden outputs inside Solid's generator package may use `.g.dart` for clarity; that is an internal convention.)

---

## 12. Hot Reload Contract

`dart run build_runner watch` regenerates `lib/foo.dart` when `source/foo.dart` changes. However, `flutter run` does NOT auto-detect that change: Flutter hot-reload is triggered by IDE save events, not by filesystem changes. When build_runner emits a new file, no IDE save event fires, so Flutter does not hot-reload on its own.

Two supported workflows (both require `dart run build_runner watch` in one terminal):

```bash
# terminal 1 (both options)
dart run build_runner watch

# Option A: manual reload
flutter run    # press r after build_runner emits

# Option B: dashmon (https://pub.dev/packages/dashmon)
dart pub global run dashmon    # wraps flutter run, auto-reloads on lib/ change
```

With Option A the developer saves `source/`, waits for build_runner to emit, then presses `r`. With Option B `dashmon` watches `lib/` for filesystem changes and sends the `r` keystroke to Flutter automatically.

---

## 13. Not yet shipped (deferred until later milestones, before v2 release)

The v2 annotation surface is fully specified by this SPEC: `@SolidState` (M1), `@SolidEffect` (M4), `@SolidQuery` (M5), and `@SolidEnvironment` (M6). No annotation remains deferred.

The provider-tree machinery uses `package:provider`'s `Provider<T>` directly (Section 3.6); Solid contributes only the `@SolidEnvironment` annotation, the `Disposable` marker interface, and a thin `.environment<T>()` extension on `Widget` that wraps in `Provider<T>` at runtime. Solid does NOT ship its own `SolidProvider` / `InheritedSolidProvider` widget, and does NOT codegen `context.watch<T>()` (Provider is used purely as DI plumbing — Solid's existing reactivity primitives own rebuild scope). Users install `package:provider` in their own app pubspec because their source code references `Provider<T>` / `MultiProvider` / `context.read<T>()` directly.

Permanent non-goals (never part of Solid) are defined in Section 3.3.

Deferred operational concerns (time-boxed, not semantic):

- CI workflow. Local-only testing until GitHub Actions budget permits.

---

## 14. Resolved Decisions

These were open questions during SPEC drafting and have been answered by the developer. Locked for M1:

1. **Plain (non-Widget) classes with `@SolidState` fields** — supported per Section 8.3.
2. **Compound-assignment operator list in Section 5.3** — complete.
3. **`@SolidState` on `final` fields** — rejected with a clear error (wrapping a never-reassigned value in a `Signal` is pointless).
4. **Custom `initState` / `didUpdateWidget` overrides in an existing State class (Section 8.2)** — preserved untouched, with one carve-out: when one or more `@SolidEffect` methods exist on the class, Effect-materialization reads (`<effectName>;`) are spliced into the existing `initState` body immediately after the `super.initState();` call (or after the opening brace if no super call is detected as the first statement). `@SolidQuery` fields are NOT spliced — they are lazy and materialize on first thin-accessor invocation (Section 4.8). `@SolidEnvironment` fields are NOT spliced either — they are lazy and materialize on first read in `build` / Effect / Computed / Query bodies (Section 4.9). If an existing `dispose()` is present, reactive disposals are merged into its body (this part applies to all `Signal` / `Computed` / `Effect` / `Resource` declarations and to any synthesized `_<name>Source` Computed for query auto-tracking; `@SolidEnvironment` injected instances are NOT in the dispose-name list — Section 10).
5. **User-facing packages** — two Solid packages plus two third-party runtime deps. `package:solid_annotations` (runtime dep) hosts the four annotation classes (`@SolidState`, `@SolidEffect`, `@SolidQuery`, `@SolidEnvironment`), the `Disposable` marker interface, the `@SolidQuery` source-time stub extensions, and the `.environment<T>()` extension on `Widget`. `package:solid_generator` (dev_dep) hosts the build_runner builder. There is no `package:solid` umbrella. Consumers run `flutter pub add solid_annotations flutter_solidart provider` and `dart pub add --dev solid_generator build_runner`. `flutter_solidart` and `provider` are listed in the user's own pubspec because the user's source code references their symbols directly (per the `depend_on_referenced_packages` lint). `solid_annotations` itself depends on `flutter` (the source-time stubs return `Widget`) and on `package:provider` (the `.environment<T>()` extension's body wraps in `Provider<T>`). It does NOT depend on `flutter_solidart` — the user's source layer never names solidart primitives directly; those types appear only in lowered `lib/` output where `flutter_solidart` is a separate user-listed runtime dep.
6. **Shadowing rule (Section 5.5)** — handled by type resolution. Because Section 5.1 is type-driven, a shadowed local of a non-`SignalBase` type is never rewritten. A dedicated shadowing test case is required in M1.
7. **`const` on the public widget constructor (Section 8.1)** — not added by the generator. Constructors round-trip verbatim from source. After the class split removes mutable `@SolidState` fields from the widget, the rewritten widget is usually const-eligible by Dart's own rules; `dart fix --apply` is the trusted lint pass that adds `const` (and removes unused imports — Section 9). The generator never emits `const` on its own.

---

## 15. Verification

Any change that alters user-observable behavior must be covered by a golden test (paired `inputs/*.dart` + `outputs/*.g.dart` files under the generator's test harness) AND a widget test on the example app (`flutter test`). The reviewer agent's rubric (defined separately in the plan, not here) uses this SPEC as the behavioral contract.

---

## 16. Issue References

This SPEC addresses the following real user-reported issues from the v1 repo:

- **#3** — `@SolidEnvironment` inside an existing `State<X>` was not transformed; the class-kind handling in Section 8.2 makes this impossible to regress.
- **#4** — untracked reads (`onPressed`) were wrapped in `SignalBuilder`, breaking compilation; Section 6 defines the untracked-context rules. *(resolved in M3)*
- **#6** — `Text(text)` did not receive `.value` because the rewriter missed bare identifier reads; Section 5.1 defines the rewrite rule exhaustively. *(resolved in M3)*
- **#8** — generated `main.dart` used `SolidartConfig` without importing `flutter_solidart`; Section 9 defines the import-addition rule.
- **#9** — hot reload required a double-save; Section 12 defines the two supported workflows: manual `r` after build_runner emits, or `dashmon` to bridge filesystem changes to Flutter's stdin automatically.

Issue #11 (build speed) and issue #1 (docs typo) are process concerns addressed outside this SPEC.
