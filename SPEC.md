# Solid — Product Specification (v2)

**Status:** DRAFT — under review
**Scope of this SPEC:** defines the user-facing contract for `@SolidState` (the first implementation milestone, M1). The other annotations shipped before v2 release — `@SolidEffect`, `@SolidQuery`, `@SolidEnvironment` — are reserved names only; their full contract lives in a future SPEC revision.

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
- **Transformation vs verbatim copy.** Solid reads every `.dart` file under `source/`. If a file contains at least one `@Solid*` annotation (`@SolidState` today; `@SolidEffect`, `@SolidQuery`, `@SolidEnvironment` in later milestones), Solid transforms it. Otherwise the file is copied verbatim to the mirrored path under `lib/`. Non-`.dart` files (assets, configs, etc.) are always copied verbatim. The key is annotation presence, not file extension.
- **Both are committed to git.** Source is the review artifact for intent. Lib is the review artifact for correctness — every PR that changes `source/` must include the regenerated `lib/` diff so reviewers catch generator regressions.
- **Solid emits no `.g.dart` files of its own.** Third-party generators (freezed, json_serializable, drift) may emit `.g.dart` or `.freezed.dart` files under `source/`; Solid copies those verbatim to the mirrored path under `lib/`.
- **The example app's `main.dart`** lives in `lib/` (or `source/` if itself annotated) and imports from `lib/` using normal Flutter imports (`import 'counter.dart';`).
- **Source is analyzed** with a couple of lint suppressions (notably `must_be_immutable`) so that a `StatelessWidget` with a mutable `@SolidState` field does not trip the analyzer. Source remains valid Dart at all times; any real error (typo, type error, undefined symbol) fails analysis.
- **Hot reload requires a bridge.** `dart run build_runner watch` regenerates `lib/` as the developer edits `source/`, but `flutter run` does not auto-detect that filesystem change because no IDE save event fires. The developer must either press `r` in the `flutter run` terminal after build_runner emits, or use `dashmon` (https://pub.dev/packages/dashmon) to bridge the filesystem change to Flutter's stdin automatically. See Section 12 for the full workflow.

---

## 3. Annotations

> **Milestones vs v2.** The v2 public release ships the full annotation set: `@SolidState`, `@SolidEffect`, `@SolidQuery`, `@SolidEnvironment`. Implementation is split into internal milestones. M1 implements `@SolidState` only. Later milestones add the remaining annotations before v2 ships. The user-facing API of every annotation is fixed in this SPEC; no source-code change is required when a later milestone lands.

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

The following annotations are part of the v2 public release but land in milestones after M1. Until each one ships, the generator must fail with a clear error that names the annotation and says "not yet implemented; scheduled for a later v2 milestone." Their names are reserved here; the full user-facing contract (parameters, valid targets, transformation rules) will be specified in a future SPEC revision before each lands.

- `@SolidEffect` — reactive side effect (method)
- `@SolidQuery` — async reactive source (method)
- `@SolidEnvironment` — dependency injection (field)

### 3.3 Permanent non-goals

Solid will never:

- Replace `flutter_solidart`. Signal / Computed / Effect / Resource / SignalBuilder come from the upstream package.
- Ship its own reactive runtime.
- Use Dart Macros, Dart augmentations, or part-file patterns.
- Split one source file into multiple lib files. Each `source/*.dart` produces exactly one `lib/*.dart` at the mirrored path.

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
late final text = Signal<String>('', name: 'text');
```

Rules:

- The generator preserves the `late` keyword — valid Dart that defers `Signal` construction until first access.
- Nullable fields (§4.3) do not require `late` because `null` is a valid default.

Default values by declared type:

- `int` → `0`
- `double` → `0.0`
- `num` → `0`
- `String` → `''`
- `bool` → `false`
- `T?` (any nullable type) → `null`
- `List<E>` → `<E>[]`
- `Map<K, V>` → `<K, V>{}`
- `Set<E>` → `<E>{}`
- Any other non-nullable type → **generator rejects with a clear error** ("field `foo` of type `MyType` has no initializer and no default is known; add `= MyType(...)` or declare `MyType?`").

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

---

## 5. Reactive-Read Rules

When a generated piece of code (anything under `lib/`) references a reactive value, the reference is rewritten to read through the reactive primitive. The decision is **type-driven**, not name-driven: the generator uses the Dart analyzer's resolved static type, not a name-set, to decide whether to append `.value`.

### 5.1 Identifier rewrite

A bare `SimpleIdentifier` is rewritten to `<name>.value` if and only if its resolved static type is `SignalBase<T>` (or a subtype: `Signal<T>`, `Computed<T>`, `ReadSignal<T>`, `Resource<T>`) from `package:flutter_solidart`.

In M1 the only way to introduce such an identifier is via `@SolidState` on the enclosing class, but the rule itself is expressed in terms of resolved type so later milestones (`@SolidEnvironment`, `@SolidQuery`) work without amendment.

Source:

```dart
Text(counter.toString())
```

Output (inside a SignalBuilder — see Section 7):

```dart
Text(counter.value.toString())
```

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

Callback parameter names treated as untracked:

- `onPressed`, `onTap`, `onLongPress`, `onDoubleTap`
- `onChanged`, `onSubmitted`, `onEditingComplete`, `onFieldSubmitted`, `onSaved`
- `onHorizontalDragUpdate`, `onVerticalDragUpdate`, `onPanUpdate`, `onScaleUpdate` (and their `Start`/`End`/`Cancel`/`Down` variants)
- `onHover`, `onExit`, `onEnter`, `onFocusChange`
- `onDismissed`, `onClosing`, `onAccept`, `onWillAccept`, `onLeave`, `onMove`
- The list is maintained in this SPEC.

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

### 6.3 Reads inside Key constructor arguments

A read is untracked when the identifier appears inside an `InstanceCreationExpression` whose constructor is `ValueKey`, `Key`, `ObjectKey`, `UniqueKey`, `GlobalKey`, `GlobalObjectKey`, or `PageStorageKey`, and that expression is passed to the `key:` parameter of a widget.

Source:

```dart
Container(
  key: ValueKey(counter),
  child: const Text('hi'),
)
```

Output:

```dart
Container(
  key: ValueKey(counter.value),
  child: const Text('hi'),
)
// NOT wrapped in SignalBuilder
```

### 6.4 Explicit opt-out via `untracked`

`flutter_solidart` exports a top-level function `untracked<T>(T Function() fn)` that reads signals without creating a subscription. Solid exposes this function as-is and recognizes it during transformation: reads inside an `untracked(() => ...)` callback are untracked.

Source:

```dart
Text('Static snapshot: ${untracked(() => counter)}')
```

Output:

```dart
Text('Static snapshot: ${untracked(() => counter.value)}')
// NOT wrapped in SignalBuilder
```

The generator recognizes `untracked` by resolved identifier (the top-level function from `package:flutter_solidart/flutter_solidart.dart`), not by name alone. A user-defined local `untracked` variable would not apply this rule.

### 6.5 Everything else is tracked

If a read is not in one of the contexts defined in Sections 6.2, 6.3, or 6.4, it is tracked. The containing widget subtree must be wrapped in `SignalBuilder` (Section 7).

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

The public constructor gains `const` where safe (all fields final and literal).

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

Every generated `Signal` and `Computed` must be disposed when its owning class is disposed. The merging algorithm below applies identically to every class kind; the per-kind sections (8.1–8.3) describe how the algorithm is triggered.

Algorithm: if the target class already has a `dispose()` body, prepend one `xxx.dispose()` call per reactive declaration to the top of the body and leave the rest untouched; if no `dispose()` exists, synthesize one. Emit `super.dispose()` at the end if and only if the class's supertype chain contains a `dispose()` method (e.g., `State<T>`, `ChangeNotifier`); the generator determines this via the analyzer's type resolution, not by name matching. For a plain class with no `dispose()` in the supertype chain, omit `super.dispose()`.

Disposal order is **reverse declaration order**: dependents are disposed before their dependencies. Because a `Computed` must always be declared after the `Signal`s it reads (those `Signal`s are the `Computed`'s dependencies), reverse declaration order guarantees the `Computed` is disposed first and a `Signal` is never disposed while a live `Computed` still holds a subscription to it.

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

## 13. Not in M1 (shipped before v2 release)

These features are part of the v2 public release but land in milestones after M1. An M1 build that encounters any of them in source code must fail with a clear error naming the unsupported feature and referencing this section.

- `@SolidEffect`
- `@SolidQuery` (Future and Stream forms; `.when`, `.maybeWhen`, `.refresh`, `.isRefreshing`; debounce; useRefreshing)
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
4. **Custom `initState` / `didUpdateWidget` overrides in an existing State class (Section 8.2)** — preserved untouched. If an existing `dispose()` is present, reactive disposals are merged into its body.
5. **User-facing package name** — keep the current layout: `package:solid_annotations` holds the annotations and `package:solid` is the umbrella package that re-exports the annotations plus the curated subset of `flutter_solidart` symbols Solid programs need.
6. **Shadowing rule (Section 5.5)** — handled by type resolution. Because Section 5.1 is type-driven, a shadowed local of a non-`SignalBase` type is never rewritten. A dedicated shadowing test case is required in M1.
7. **`const` on the public widget constructor (Section 8.1)** — added when all fields and default values are `const`-compatible.

---

## 15. Verification

Any change that alters user-observable behavior must be covered by a golden test (paired `inputs/*.dart` + `outputs/*.g.dart` files under the generator's test harness) AND a widget test on the example app (`flutter test`). The reviewer agent's rubric (defined separately in the plan, not here) uses this SPEC as the behavioral contract.

---

## 16. Issue References

This SPEC addresses the following real user-reported issues from the v1 repo:

- **#3** — `@SolidEnvironment` inside an existing `State<X>` was not transformed; the class-kind handling in Section 8.2 makes this impossible to regress.
- **#4** — untracked reads (`ValueKey`, `onPressed`) were wrapped in `SignalBuilder`, breaking compilation; Section 6 defines the untracked-context rules.
- **#6** — `Text(text)` did not receive `.value` because the rewriter missed bare identifier reads; Section 5.1 defines the rewrite rule exhaustively.
- **#8** — generated `main.dart` used `SolidartConfig` without importing `flutter_solidart`; Section 9 defines the import-addition rule.
- **#9** — hot reload required a double-save; Section 12 defines the two supported workflows: manual `r` after build_runner emits, or `dashmon` to bridge filesystem changes to Flutter's stdin automatically.

Issue #11 (build speed) and issue #1 (docs typo) are process concerns addressed outside this SPEC.
