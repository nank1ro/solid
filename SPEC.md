# Solid — Product Specification (v2)

**Status:** DRAFT — under review
**Scope of this SPEC:** defines the user-facing contract for `@SolidState`, `@SolidEffect`, and `@SolidQuery` (M1, M4, and M5 milestones). The remaining annotation shipped before v2 release — `@SolidEnvironment` — is a reserved name only; its full contract lives in a future SPEC revision.

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
- **Transformation vs verbatim copy.** Solid reads every `.dart` file under `source/`. If a file contains at least one `@Solid*` annotation (`@SolidState`, `@SolidEffect`, and `@SolidQuery` today; `@SolidEnvironment` in a later milestone), Solid transforms it. Otherwise the file is copied verbatim to the mirrored path under `lib/`. Non-`.dart` files (assets, configs, etc.) are always copied verbatim. The key is annotation presence, not file extension.
- **Both are committed to git.** Source is the review artifact for intent. Lib is the review artifact for correctness — every PR that changes `source/` must include the regenerated `lib/` diff so reviewers catch generator regressions.
- **Solid emits no `.g.dart` files of its own.** Third-party generators (freezed, json_serializable, drift) may emit `.g.dart` or `.freezed.dart` files under `source/`; Solid copies those verbatim to the mirrored path under `lib/`.
- **The example app's `main.dart`** lives in `lib/` (or `source/` if itself annotated) and imports from `lib/` using normal Flutter imports (`import 'counter.dart';`).
- **Source is analyzed** with a couple of lint suppressions (notably `must_be_immutable`) so that a `StatelessWidget` with a mutable `@SolidState` field does not trip the analyzer. Source remains valid Dart at all times; any real error (typo, type error, undefined symbol) fails analysis.
- **Hot reload requires a bridge.** `dart run build_runner watch` regenerates `lib/` as the developer edits `source/`, but `flutter run` does not auto-detect that filesystem change because no IDE save event fires. The developer must either press `r` in the `flutter run` terminal after build_runner emits, or use `dashmon` (https://pub.dev/packages/dashmon) to bridge the filesystem change to Flutter's stdin automatically. See Section 12 for the full workflow.

---

## 3. Annotations

> **Milestones vs v2.** The v2 public release ships the full annotation set: `@SolidState`, `@SolidEffect`, `@SolidQuery`, `@SolidEnvironment`. Implementation is split into internal milestones. M1 implements `@SolidState`; M4 adds `@SolidEffect`; M5 adds `@SolidQuery`. A later milestone adds `@SolidEnvironment` before v2 ships. The user-facing API of every annotation is fixed in this SPEC; no source-code change is required when a later milestone lands.

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

The following annotation is part of the v2 public release but lands in a milestone after the SPEC's currently-specified set (`@SolidState` in M1, `@SolidEffect` in M4, `@SolidQuery` in M5). Until it ships, the generator must fail with a clear error that names the annotation and says "not yet implemented; scheduled for a later v2 milestone." Its name is reserved here; the full user-facing contract (parameters, valid targets, transformation rules) will be specified in a future SPEC revision before it lands.

- `@SolidEnvironment` — dependency injection (field)

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

`@SolidQuery` declares an async reactive source on a class. It attaches to an instance method whose body fetches data from a `Future` or `Stream` and exposes the result as a `Resource<T>`. The annotated method's body is wrapped in a parameterless function expression that becomes the `Resource<T>`'s fetcher. The resulting `Resource<T>` re-fetches when the user calls `.refresh()` on it; for advanced upstream-binding scenarios the user constructs a hand-written `Resource<T>` directly without `@SolidQuery`.

```dart
@SolidQuery()
Future<User> fetchUser() async => api.getUser();

@SolidQuery()
Stream<int> watchTicker() async* {
  yield* tickerStream;
}
```

Optional `name:` parameter overrides the auto-derived debug name:

```dart
@SolidQuery(name: 'currentUser')
Future<User> fetchUser() async => api.getUser();
```

Optional `lazy:` parameter (default `true`) controls when the fetcher first runs. With the default `lazy: true`, the fetcher fires when something first reads `<query>.state` (e.g., a `SignalBuilder`-wrapped `<query>.state.when(...)` chain in `build`). With `lazy: false`, the fetcher fires immediately at mount time (State class) or construction time (plain class) — see Section 4.8 for the materialization mechanism.

```dart
@SolidQuery(lazy: false)
Future<User> fetchUser() async => api.getUser();
```

#### Valid target

- Instance method with one of two return-type / body-keyword pairings:
  1. `Future<T>` return type with an `async` body (expression or block).
  2. `Stream<T>` return type with an `async*` body (block only — Dart does not allow `async*` expression bodies).
- The method must take **no parameters** (see Section 14 item 8).

#### Invalid targets (the generator must reject with a clear error)

- Method with a non-`Future`/non-`Stream` return type (sync return cannot back a `Resource<T>`; for a sync reactive value use `@SolidState` on a getter).
- Method whose body keyword does not match the return type (a `Future<T>`-typed body that is not `async`, or a `Stream<T>`-typed body that is not `async*`).
- Method with one or more parameters (deferred per Section 14 item 8).
- `static` method (class-level, not instance — out of scope, parallel to `@SolidState` and `@SolidEffect`).
- `abstract` or `external` method (no body to lower).
- Getter (use `@SolidState` on a getter for a `Computed`).
- Setter.
- Top-level function.
- Field.

#### No reactive-deps requirement

Unlike `@SolidEffect` (Section 3.4) and `@SolidState` getter (Section 4.5), a `@SolidQuery` method body fetches from external sources (HTTP, database, Stream subscription, etc.) and may legitimately have zero reactive-field references. The Section 4.5 / Section 3.4 zero-deps rejection rule does NOT apply to queries. A query that does read reactive declarations behaves correctly under Section 5: the `.value` / `.state` rewrite fires on each identifier per its resolved type.

#### Read pattern

A reference to a `@SolidQuery` field elsewhere in the class (in a `build` method, a `@SolidEffect` body, or a `@SolidState` getter body) is canonically chained as `<query>.state.when(...)` — `.state` returns `ResourceState<T>` and `.when({required ready, required loading, required error})` is an extension method on `ResourceState<T>` from `package:flutter_solidart`. `.maybeWhen({orElse, ready, loading, error})` is the partial-match analogue.

```dart
@override
Widget build(BuildContext context) => fetchUser.state.when(
  ready: (user) => Text(user.name),
  loading: () => const CircularProgressIndicator(),
  error: (e, _) => Text('error: $e'),
);
```

The `.state` accessor is required in source because `.when` is not defined on `Resource<T>` itself (only on `ResourceState<T>`). The Section 5.1 `.state` rewrite handles the corner case of a *bare-identifier* read of a query field (an argument-position read or interpolation), where the user has not written `.state` explicitly; for method-call chains like `.when(...)` the user writes `.state` themselves so the source typechecks.

#### Refresh

`<query>.refresh()` is a direct upstream method on `Resource<T>` that re-runs the fetcher and emits a new `ResourceState<T>`. It survives the body-rewrite pipeline unchanged — `.refresh()` is a method call, not a bare-identifier read, so neither the Section 5.1 `.state` rewrite nor the Section 6 untracked-context rules amend its shape.

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
  Widget build(BuildContext context) => const Placeholder();
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
- In M1 the only source of such a declaration is a `@SolidState` field or getter on the same class. Later milestones add cross-class declarations via `@SolidEnvironment` (Section 13); the rule is stated in terms of resolved type so no SPEC change is required when they land.
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

Input (Future form):

```dart
@SolidQuery()
Future<User> fetchUser() async => api.getUser();
```

Output:

```dart
late final fetchUser = Resource<User>(
  () async => api.getUser(),
  name: 'fetchUser',
);
```

Input (Stream form):

```dart
@SolidQuery()
Stream<int> watchTicker() async* {
  yield* tickerStream;
}
```

Output:

```dart
late final watchTicker = Resource<int>.stream(
  () async* {
    yield* tickerStream;
  },
  name: 'watchTicker',
);
```

Rules:

- The method's body — expression body (Future form) or block body (Future or Stream form) — is wrapped in a parameterless function expression that preserves the `async` / `async*` keyword. Section 5.1 type-driven rewriting (both the `.value` form for `Signal` / `Computed` reads and the `.state` form for cross-`Resource` reads) is applied verbatim inside the body. A query body MAY read other reactive declarations — the rewrite still fires per resolved type — but no upstream-Signal subscription is wired automatically (an annotated query body is the fetcher closure only; advanced re-fetch triggers belong to a future SPEC revision).
- Future-returning methods lower to `Resource<T>(...)`; Stream-returning methods lower to `Resource<T>.stream(...)`. Type argument `T` is the inner type of the original `Future<T>` / `Stream<T>` return signature.
- The resulting field is always declared `late final`, parallel to `Computed` (Section 4.5) and `Effect` (Section 4.7): the initializer may read other reactive instance fields, so its evaluation must defer until `this` is in scope.
- Method-name → `name:` argument, unless `@SolidQuery(name: '…')` overrides — symmetric with the rules in Sections 4.1, 4.4, and 4.7.
- **Lazy by default.** A `@SolidQuery` field stays uninitialized until first read. Reading `<query>.state` (typically inside a `build` / `Effect` / `Computed` body, wrapped in `SignalBuilder` per Section 7) triggers the `late final` initializer, which constructs the `Resource<T>` and fires the fetcher on first state access. A `Resource` has a natural consumer (the body that reads `<query>.state`) so it does NOT use the forced-materialization pattern that Section 4.7 / Section 8.3 apply to `Effect` (an `Effect` has no natural consumer and must be materialized at mount / construction).
- **Eager start opt-in: `@SolidQuery(lazy: false)`.** When the user passes `lazy: false`, the generator emits `Resource<T>(..., lazy: false, name: '…')` so the upstream `Resource` constructor fires the fetcher immediately, AND extends the Section 4.7 / Section 8.3 forced-materialization list with the query's name. A bare-identifier read of the field at mount time (State class) or construction time (plain class) runs the `late final` initializer, which constructs the eager `Resource<T>`, which fires the fetcher synchronously. Default `@SolidQuery()` (`lazy: true`) emits no `lazy:` argument and is NOT materialized. Eagerness is per-field: a class may mix lazy and eager queries.

---

## 5. Reactive-Read Rules

When a generated piece of code (anything under `lib/`) references a reactive value, the reference is rewritten to read through the reactive primitive. The decision is **type-driven**, not name-driven: the generator uses the Dart analyzer's resolved static type, not a name-set, to decide whether to append `.value`.

### 5.1 Identifier rewrite

A bare `SimpleIdentifier` is rewritten to `<name>.value` if and only if its resolved static type is `SignalBase<T>` (or a subtype: `Signal<T>`, `Computed<T>`, `ReadSignal<T>`) from `package:flutter_solidart`. `Resource<T>` is special-cased: see the `Resource` paragraph below.

In M1 the only way to introduce such an identifier is via `@SolidState` on the enclosing class, but the rule itself is expressed in terms of resolved type so later milestones (`@SolidEnvironment`) work without amendment.

Source:

```dart
Text(counter.toString())
```

Output (inside a SignalBuilder — see Section 7):

```dart
Text(counter.value.toString())
```

#### `Resource<T>` accessor — `.state` instead of `.value`

`Resource<T>` is a subtype of `SignalBase<ResourceState<T>>`, not `SignalBase<T>`, and upstream `flutter_solidart` (≥ 2.7.3) deprecates `Resource<T>.value`. The rewriter therefore emits `<name>.state` (returning `ResourceState<T>`) for receivers whose resolved static type is `Resource<T>`, and `<name>.value` for every other `SignalBase<T>` subtype. The rule remains type-driven; the only difference is the accessor name.

Source (a bare-identifier read of `fetchUser` passed as an argument):

```dart
final ResourceState<User> snapshot = fetchUser;
```

Output:

```dart
final ResourceState<User> snapshot = fetchUser.state;
```

This rewrite fires only on bare `SimpleIdentifier` reads of a `Resource<T>`-typed receiver. Method-call chains (e.g., `fetchUser.state.when(...)`, `fetchUser.refresh()`) are unaffected — the source must already chain `.state` (or call a direct `Resource` method like `.refresh()`) for analyzer-level typechecking, and the rewriter does not edit method-call receivers.

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

`@SolidState` can appear on classes of four kinds. Each is transformed differently. If a class has no `@SolidState` annotations, it passes through unchanged.

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
  Widget build(BuildContext context) => Text('$counter');
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

Reactive declarations are applied in-place. A `dispose()` method is synthesized that disposes every generated Signal/Computed. No State wrapper.

Source:

```dart
class Counter {
  @SolidState()
  int value = 0;
}
```

Output:

```dart
class Counter {
  final value = Signal<int>(0, name: 'value');

  void dispose() {
    value.dispose();
  }
}
```

If the developer has already declared a `dispose()` method, the generator merges: the generated disposal calls are prepended to the existing body, then `super.dispose()` is emitted if and only if the class's supertype chain contains a `dispose()` method (e.g., `State<T>`, `ChangeNotifier`). The generator determines this via the analyzer's type resolution, not by name matching. For a plain class with no `dispose()` in the supertype chain, `super.dispose()` is omitted.

When the plain class has one or more `@SolidEffect` methods, or one or more `@SolidQuery(lazy: false)` methods, the generator synthesizes a no-arg constructor whose body reads each materialized field by bare identifier in declaration order — analogue of the State class's `initState()` materialization (§4.7, §4.8). The synthesized constructor takes the place a widget lifecycle would otherwise serve, activating each `late final` Effect (or eager `Resource`) at construction time so its autorun fires once with the initial Signal values (or its fetcher fires once at construction) and subscribes to subsequent changes. Default `@SolidQuery()` (`lazy: true`) queries are NOT materialized — they remain `late final` and initialize on first read by a consumer body. Plain classes with a user-defined constructor and `@SolidEffect` or `@SolidQuery(lazy: false)` are not supported in this milestone — the generator rejects with a `CodeGenerationError`.

### 8.4 StatelessWidget with zero `@SolidState` annotations

Passes through unchanged to `lib/`.

---

## 9. Import Rules

The generated `lib/` file's imports are computed from the source's imports plus what the generator added:

- Add `import 'package:flutter_solidart/flutter_solidart.dart';` if the generated output references any of: `Signal`, `Computed`, `Effect`, `Resource`, `SignalBuilder`, `SolidartConfig`, `untracked`. (Effect, Resource, and `untracked` may appear via later milestones or opt-out rules in Section 6.4; they are listed here so the rule is future-proof.)
- Every other import in the source is preserved verbatim, including aliases and `show`/`hide` combinators.
- Unused imports left behind (e.g., `package:solid_annotations/...` when no annotation references remain in the generated output) are removed by running `dart fix --apply` on the generated file. The generator does NOT try to detect unused imports itself.

This is the fix for issue #8.

---

## 10. `dispose()` Contract

Every generated `Signal`, `Computed`, `Effect`, and `Resource` must be disposed when its owning class is disposed. The merging algorithm below applies identically to every class kind; the per-kind sections (8.1–8.3) describe how the algorithm is triggered.

Algorithm: if the target class already has a `dispose()` body, prepend one `xxx.dispose()` call per reactive declaration to the top of the body and leave the rest untouched; if no `dispose()` exists, synthesize one. Emit `super.dispose()` at the end if and only if the class's supertype chain contains a `dispose()` method (e.g., `State<T>`, `ChangeNotifier`); the generator determines this via the analyzer's type resolution, not by name matching. For a plain class with no `dispose()` in the supertype chain, omit `super.dispose()`.

Disposal order is **reverse declaration order**: dependents are disposed before their dependencies. Because a `Computed` must always be declared after the `Signal`s it reads, an `Effect` must always be declared after the `Signal`s/`Computed`s it reads, and a `Resource` whose fetcher reads other reactive declarations must be declared after those declarations (those declarations are the dependents' dependencies), reverse declaration order guarantees a dependent (`Effect`, `Computed`, or `Resource`) is disposed first and a dependency (`Signal`, `Computed`, or another `Resource`) is never disposed while a live subscriber still holds a subscription to it.

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

These features are part of the v2 public release but land in milestones after the SPEC's currently-specified set (`@SolidState` in M1, `@SolidEffect` in M4, `@SolidQuery` in M5). A build that encounters any of them in source code must fail with a clear error naming the unsupported feature and referencing this section.

- `@SolidEnvironment`
- `SolidProvider` / `InheritedSolidProvider` / `.environment()` widget extension / `context.read` / `context.watch`

Permanent non-goals (never part of Solid) are defined in Section 3.3.

Deferred operational concerns (time-boxed, not semantic):

- CI workflow. Local-only testing until GitHub Actions budget permits.

---

## 14. Resolved Decisions

These were open questions during SPEC drafting and have been answered by the developer. Locked for M1:

1. **Plain (non-Widget) classes with `@SolidState` fields** — supported per Section 8.3.
2. **Compound-assignment operator list in Section 5.3** — complete.
3. **`@SolidState` on `final` fields** — rejected with a clear error (wrapping a never-reassigned value in a `Signal` is pointless).
4. **Custom `initState` / `didUpdateWidget` overrides in an existing State class (Section 8.2)** — preserved untouched, with one carve-out: when one or more `@SolidEffect` methods or `@SolidQuery(lazy: false)` methods exist on the class, materialization reads (`<effectName>;` / `<queryName>;`) are spliced into the existing `initState` body immediately after the `super.initState();` call (or after the opening brace if no super call is detected as the first statement). Default `@SolidQuery()` (`lazy: true`) queries are NOT spliced — they materialize on first consumer read. If an existing `dispose()` is present, reactive disposals are merged into its body (this part applies to all `Signal` / `Computed` / `Effect` / `Resource` declarations regardless of laziness).
5. **User-facing packages** — two packages. `package:solid_annotations` (runtime dep) hosts the annotation classes (`@SolidState`, `@SolidEffect`, and `@SolidQuery` today; `@SolidEnvironment` in a later milestone). `package:solid_generator` (dev_dep) hosts the build_runner builder. There is no `package:solid` umbrella. Consumers add `solid_annotations` + `flutter_solidart` as runtime deps and `solid_generator` + `build_runner` as dev_deps, then import annotations and `flutter_solidart` primitives directly.
6. **Shadowing rule (Section 5.5)** — handled by type resolution. Because Section 5.1 is type-driven, a shadowed local of a non-`SignalBase` type is never rewritten. A dedicated shadowing test case is required in M1.
7. **`const` on the public widget constructor (Section 8.1)** — not added by the generator. Constructors round-trip verbatim from source. After the class split removes mutable `@SolidState` fields from the widget, the rewritten widget is usually const-eligible by Dart's own rules; `dart fix --apply` is the trusted lint pass that adds `const` (and removes unused imports — Section 9). The generator never emits `const` on its own.
8. **`@SolidQuery` parameter forwarding (Section 3.5)** — rejected in M5. An annotated query method must be parameterless. The upstream `Resource<T>` constructor accepts a closure with no parameters, so introducing parameters requires either a fetcher-factory shape (parameterized method → method that returns a `Resource<T>`, requiring per-call disposal management) or a separate annotation form (e.g., `@SolidQueryFamily`). A future SPEC revision may revisit if a concrete use case emerges; M5 ships without it.

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
