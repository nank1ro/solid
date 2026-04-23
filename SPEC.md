# Solid — Product Specification (v2)

**Status:** DRAFT — under review
**Scope of this SPEC:** defines the user-facing contract for `@SolidState`. All other annotations are listed only to pin the v1 boundary; their full contract lives in a future SPEC revision.

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

Rules:

- **Input path**: any `.dart` file under `source/` at any depth.
- **Output path**: same relative path under `lib/`. No suffix change. `source/foo/bar.dart` becomes `lib/foo/bar.dart`.
- **Both are committed to git.** Source is the review artifact for intent. Lib is the review artifact for correctness — every PR that changes `source/` must include the regenerated `lib/` diff so reviewers catch generator regressions.
- **No `.g.dart` files are emitted.** Neither under `source/` nor under `lib/`.
- **The example app's `main.dart`** lives in `lib/` (or `source/` if itself annotated) and imports from `lib/` using normal Flutter imports (`import 'counter.dart';`).
- **Source is analyzed** with a couple of lint suppressions (notably `must_be_immutable`) so that a `StatelessWidget` with a mutable `@SolidState` field does not trip the analyzer. Source remains valid Dart at all times; any real error (typo, type error, undefined symbol) fails analysis.
- **Hot reload works normally.** `dart run build_runner watch` regenerates `lib/` as the developer edits `source/`; `flutter run` hot-reloads from `lib/`. This is the whole flow; there is no separate CLI. (Addresses issue #9.)

---

## 3. Annotations

### 3.1 v1 scope: `@SolidState`

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

- Instance field with or without an initializer.
- Instance getter with an expression body (`=> ...`) or a block body (`{ return ...; }`).

#### Invalid targets (the generator must reject with a clear error)

- `final` field (a `Signal` wrapping a never-reassigned value is a static constant — pointless).
- `const` field (same reason plus a type-system impossibility).
- `static` field or getter (class-level, not instance; out of v1 scope).
- Top-level variable or getter.
- Method (not a getter).
- Setter.

### 3.2 Out of v1 scope

The following annotations are defined by the blog-post vision but are NOT implemented in v1. If the developer uses them, the generator must fail with a clear error that names the annotation and says "not implemented in v1."

- `@SolidEffect()` — reactive side effect (method)
- `@SolidQuery({Duration? debounce, bool? useRefreshing})` — async reactive source (method)
- `@SolidEnvironment()` — dependency injection (field)

### 3.3 Permanent non-goals

Solid will never:

- Replace `flutter_solidart`. Signal / Computed / Effect / Resource / SignalBuilder come from the upstream package.
- Ship its own reactive runtime.
- Use Dart Macros, Dart augmentations, or part-file patterns.
- Support multi-file generation (one source file → one lib file).

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

Output (excerpt, see §8 for the full class transform):

```dart
final counter = Signal<int>(0, name: 'counter');
```

Rules:

- Declared type of the field → type argument of `Signal`.
- Initializer expression → first positional argument of `Signal`.
- Field name → `name:` argument, unless `@SolidState(name: '…')` overrides.

### 4.2 Field with no initializer

Input:

```dart
@SolidState()
String text;
```

Output:

```dart
final text = Signal<String>('', name: 'text');
```

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

### 4.5 Getter → Computed (no dependencies on other reactive state)

Input:

```dart
@SolidState()
String get label => 'hello';
```

Output:

```dart
final label = Computed<String>(() => 'hello', name: 'label');
```

Rule: when the getter body does not read any reactive identifier defined on the same class, the field is declared `final` (not `late final`).

### 4.6 Getter → Computed (with dependencies)

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

- Identifiers in the body that match other reactive declarations on the same class are rewritten with `.value` (see §5).
- The resulting `Computed` field is declared `late final` (not `final`), because it references other `final` instance fields whose initialization order is not guaranteed.

### 4.7 Getter with block body

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

When a generated piece of code (anything under `lib/`) references a name that was declared reactive in the source, the reference is rewritten to read through the reactive primitive.

### 5.1 Identifier rewrite

Every bare `SimpleIdentifier` whose name matches a `@SolidState` field or getter on the enclosing class is rewritten to `<name>.value`.

Source:

```dart
Text(counter.toString())
```

Output (inside a SignalBuilder — see §7):

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

Source:

```dart
onPressed: () => counter++
onPressed: () { counter = counter + 1; }
onPressed: () { counter += 5; }
```

Output (see §6 for why these are not wrapped in SignalBuilder):

```dart
onPressed: () => counter.value++
onPressed: () { counter.value = counter.value + 1; }
onPressed: () { counter.value += 5; }
```

Supported operators: `=`, `+=`, `-=`, `*=`, `/=`, `~/=`, `%=`, `??=`, `<<=`, `>>=`, `|=`, `&=`, `^=`, `++` (prefix/postfix), `--` (prefix/postfix).

### 5.4 Double-append protection

If the source already has `name.value`, the generator must NOT rewrite it to `name.value.value`. The rewriter is idempotent.

### 5.5 Shadowing

If a local variable or parameter inside a function shadows a reactive-field name, the generator does NOT rewrite the shadowed use.

Source:

```dart
@SolidState() int counter = 0;

Widget build(BuildContext context) {
  return Builder(builder: (context) {
    final counter = 'local'; // shadows the field
    return Text(counter);     // stays as `counter`, not `counter.value`
  });
}
```

Output: the inner `counter` stays untouched. (The outer field reference remains reactive if present.)

This is determined by analyzer scope resolution, not by name alone. v1 implementation may use a name-set heuristic because v1 scope is simple — but the SPEC contract is scope-aware; v2 tests must include a shadowing case and it must pass.

---

## 6. Untracked-Context Rules

A read is **tracked** if the widget subtree that contains it must rebuild when the signal changes. A read is **untracked** if the expression reads the current value but must NOT cause its enclosing widget subtree to subscribe.

Untracked reads still get `.value` appended (so they typecheck). They just do NOT trigger `SignalBuilder` wrapping of their parent widget subtree (§7). This fixes issues #4 and #6.

### 6.1 Callbacks on widget constructors

A read is untracked when the identifier appears inside a function expression that is the value of a named argument to a widget constructor and that named argument is a user-interaction callback.

Callback parameter names treated as untracked:

- `onPressed`, `onTap`, `onLongPress`, `onDoubleTap`
- `onChanged`, `onSubmitted`, `onEditingComplete`, `onFieldSubmitted`, `onSaved`
- `onHorizontalDragUpdate`, `onVerticalDragUpdate`, `onPanUpdate`, `onScaleUpdate` (and their `Start`/`End`/`Cancel`/`Down` variants)
- `onHover`, `onExit`, `onEnter`, `onFocusChange`
- `onDismissed`, `onClosing`, `onAccept`, `onWillAccept`, `onLeave`, `onMove`
- Future reviewers may add to this list. The list is maintained in this SPEC.

Source:

```dart
FloatingActionButton(
  onPressed: () => counter++,
  child: const Icon(Icons.add),
)
```

Output:

```dart
FloatingActionButton(
  onPressed: () => counter.value++,  // `.value` appended
  child: const Icon(Icons.add),
)
// NOT wrapped in SignalBuilder
```

### 6.2 Key constructor arguments

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

### 6.3 Everything else is tracked

If an identifier is neither under an untracked callback nor under a Key constructor, it is tracked. The containing widget subtree must be wrapped in `SignalBuilder` (§7).

### 6.4 Nested cases

Tracking is determined by the innermost enclosing AST ancestor that matches a rule. A `Text(counter)` inside an `onPressed` callback is untracked. A `Text(counter)` outside any callback is tracked.

---

## 7. SignalBuilder Placement Rules

`SignalBuilder` is the wrapper from `flutter_solidart` that subscribes to signals read inside its builder callback and rebuilds only the enclosed subtree.

### 7.1 Where to wrap

A widget subtree needs `SignalBuilder` wrapping if and only if all three hold:

1. The subtree is a widget expression (an `InstanceCreationExpression` that constructs a widget, or a reference to one) used as the return value of the `build` method, or as the value of a child/children parameter of another widget.
2. The subtree contains at least one **tracked** reactive read (§6.3).
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
    onPressed: () => counter++,           // untracked, no wrap
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

If the developer has already declared a `dispose()` method, the generator merges: the generated disposal calls are prepended to the existing body, then `super.dispose()` is called only if the class `extends` a class that has its own `dispose()` (heuristic: if the source class extends anything other than `Object`, emit `super.dispose()` at the end; otherwise omit).

### 8.4 StatelessWidget with zero `@SolidState` annotations

Passes through unchanged to `lib/`.

---

## 9. Import Rules

The generated `lib/` file's imports are computed from the source's imports plus what the generator added:

- Remove any `import 'package:solid_annotations/solid_annotations.dart';` — the generated code never uses it.
- Add `import 'package:flutter_solidart/flutter_solidart.dart';` if the generated output references any of: `Signal`, `Computed`, `Effect`, `Resource`, `SignalBuilder`, `SolidartConfig`. (Effect and Resource appear in future scope; they are listed here so the rule is future-proof.)
- Every other import in the source is preserved verbatim, including aliases and `show`/`hide` combinators.

This is the fix for issue #8.

---

## 10. `dispose()` Contract

Every generated `Signal` and `Computed` must be disposed when its owning class is disposed.

- On a StatefulWidget's State (§8.1): the generator emits a `dispose()` override that calls `xxx.dispose()` for each reactive declaration in declaration order, then `super.dispose()`.
- On an existing State (§8.2): if the developer wrote a `dispose()`, the generator inserts the reactive disposals at the top, preserves the rest, and keeps the existing `super.dispose()` call. If no `dispose()` existed, the generator emits one.
- On a plain class (§8.3): `void dispose()` is synthesized per §8.3 merging rules.

Disposal order: declaration order. A `Computed` that depends on a `Signal` is disposed before the `Signal` it depends on (declarations are emitted in source order, so Signal comes first; dispose in the same order, so Computed depending on Signal is disposed before Signal if declared before — matches the rule since Computed always follows its dependencies in source).

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

The `source/` tree mirrors `lib/` one-to-one. Every `.dart` file under `source/` has a counterpart under `lib/`; nothing else.

No `.g.dart` files are emitted anywhere visible to the developer. (Test golden outputs inside the generator package may use `.g.dart` for clarity; that is an internal convention, not a user-facing one.)

---

## 12. Hot Reload Contract

Running the generator in watch mode alongside Flutter:

```bash
# terminal 1
dart run build_runner watch

# terminal 2
flutter run
```

When the developer saves a file under `source/`, the generator rewrites the corresponding file under `lib/`, and Flutter's file watcher picks up the `lib/` change and hot-reloads. The developer saves once. (Fixes issue #9.)

---

## 13. Out of Scope for v1

- `@SolidEffect`
- `@SolidQuery` (Future and Stream forms; `.when`, `.maybeWhen`, `.refresh`, `.isRefreshing`; debounce; useRefreshing)
- `@SolidEnvironment`
- `SolidProvider` / `InheritedSolidProvider` / `.environment()` widget extension / `context.read` / `context.watch`
- Multi-file generation (one source file produces two or more lib files)
- Dart Macros / augmentations / part-file patterns
- CI workflow (local test only until Actions budget permits)

A v1 build that encounters any of these in source code must fail with a clear error naming the unsupported feature.

---

## 14. Open Questions for the Developer

These are marked for explicit resolution before M1 implementation begins. Default answers are provided; the developer confirms or overrides.

1. **Plain (non-Widget) classes with `@SolidState` fields** — the blog post shows a `Counter` PODO passed via `SolidProvider.create`. SPEC default: support them per §8.3. **Confirm: yes/no.**
2. **`++`, `+=`, and other compound-assignment operators on fields** — SPEC default: rewrite all operators listed in §5.3. **Confirm the operator list is complete.**
3. **`@SolidState` on `final` fields** — SPEC default: reject with a clear error (pointless). **Confirm.**
4. **Custom `initState` / `didUpdateWidget` overrides in an existing State class (§8.2)** — SPEC default: preserve them untouched; insert reactive disposals into the existing `dispose()` only. **Confirm.**
5. **User-facing package name** — current choice is to keep `solid_annotations` as the import root and add an umbrella `package:solid/solid.dart` that re-exports the annotations plus a pre-curated subset of `flutter_solidart` symbols. **Confirm name or rename.**
6. **Shadowing rule (§5.5)** — SPEC says scope-aware; v1 implementation may use a name-set heuristic because the v1 scope is simple. **Confirm it's acceptable if v1 does not fully implement scope-aware shadowing, provided there is a test case that fails correctly when shadowing is added later.**
7. **`const` on the public widget constructor (§8.1)** — SPEC default: add `const` when all fields and default values are `const`-compatible. **Confirm.**

---

## 15. Verification

Any change that alters user-observable behavior must be covered by a golden test (paired `inputs/*.dart` + `outputs/*.g.dart` files under the generator's test harness) AND a widget test on the example app (`flutter test`). The reviewer agent's rubric (defined separately in the plan, not here) uses this SPEC as the behavioral contract.

---

## 16. Issue References

This SPEC addresses the following real user-reported issues from the v1 repo:

- **#3** — `@SolidEnvironment` inside an existing `State<X>` was not transformed; the class-kind handling in §8.2 makes this impossible to regress.
- **#4** — untracked reads (`ValueKey`, `onPressed`) were wrapped in `SignalBuilder`, breaking compilation; §6 defines the untracked-context rules.
- **#6** — `Text(text)` did not receive `.value` because the rewriter missed bare identifier reads; §5.1 defines the rewrite rule exhaustively.
- **#8** — generated `main.dart` used `SolidartConfig` without importing `flutter_solidart`; §9 defines the import-addition rule.
- **#9** — hot reload required a double-save; §12 defines the expected single-save flow via `build_runner watch` + `flutter run`.

Issue #11 (build speed) and issue #1 (docs typo) are process concerns addressed outside this SPEC.
