# Solid v2 — Atomic TODO List

This file is the committed, resume-safe task queue for the v2 rebuild. A fresh agent reading only a single TODO entry plus `SPEC.md` must be able to complete that item.

**How to use:**

1. Pick the lowest-numbered item whose `Status` is `TODO` and whose `Dependencies` are all `DONE`.
2. Read the referenced `SPEC.md` sections.
3. Implement per the item's `Acceptance` block.
4. Update `Status: DONE` in this file when the reviewer approves (8-point rubric in `plans/features/reviewer-rubric.md`).
5. Commit the status change alongside the implementation in one PR.

**Status legend:** `TODO` (not started) · `DOING` (in progress) · `DONE` (reviewer-approved + merged) · `BLOCKED` (explain in item).

**Conventions:**

- Golden file naming: `m<milestone>_<zero-padded-index>_<snake_case>.dart` for inputs; the paired output uses the same stem with a `.g.dart` suffix (e.g. inputs `m1_03_nullable_int_field.dart` ↔ outputs `m1_03_nullable_int_field.g.dart`). The `.g.dart` suffix is a test-harness-only convention per SPEC Section 11; production `lib/` output from the builder is plain `.dart`.
- SPEC references use the form `Section X.Y` (never `§X.Y`).
- Paired golden files live under `packages/solid_generator/test/golden/inputs/` and `packages/solid_generator/test/golden/outputs/`. Only the test harness uses the `.g.dart` suffix; production `lib/` output is plain `.dart`.
- Each TODO that introduces new generator behavior must ship paired golden files + an entry in `packages/solid_generator/test/integration/golden_test.dart`.

---

## M0 — Scaffolding

### TODO M0-01 — Workspace pubspec + analyzer + gitignore

**Goal:** Establish the workspace root so `dart pub get` succeeds.

**SPEC references:** None (operational).

**Files to create/modify:**

- `pubspec.yaml` (workspace root): workspace declaration listing all workspace members — two packages (`packages/solid_annotations`, `packages/solid_generator`) plus the `example/` Flutter app.
- `analysis_options.yaml` (workspace root): `include: package:very_good_analysis/analysis_options.yaml`.
- `.gitignore`: `.dart_tool/`, `.packages`, `build/`, `.flutter-plugins`, `.flutter-plugins-dependencies`. Do NOT ignore `source/**` or `lib/**`.

**Acceptance:**

- `dart pub get` at workspace root exits 0.
- `git status` shows `.dart_tool/` is ignored.

**Dependencies:** none.

**Status:** DONE

---

### TODO M0-02 — `solid_annotations` package trimmed to M1

**Goal:** Ship only the `@SolidState` annotation class; reserve the other names per SPEC Section 3.2.

**SPEC references:** Section 3.1, Section 3.2.

**Files to create/modify:**

- `packages/solid_annotations/pubspec.yaml` — package name `solid_annotations`, no runtime deps.
- `packages/solid_annotations/lib/solid_annotations.dart` — exports `src/annotations.dart`.
- `packages/solid_annotations/lib/src/annotations.dart` — `class SolidState` with one named `name:` parameter (nullable String). Add placeholder classes `SolidEffect`, `SolidQuery`, `SolidEnvironment` with a `// M1: reserved name, no fields yet.` comment and no fields.

**Expected API:**

```dart
class SolidState {
  const SolidState({this.name});
  final String? name;
}
class SolidEffect { const SolidEffect(); }
class SolidQuery { const SolidQuery(); }
class SolidEnvironment { const SolidEnvironment(); }
```

**Acceptance:**

- `dart analyze packages/solid_annotations` → zero issues.
- `dart test packages/solid_annotations` (empty suite) passes.

**Dependencies:** M0-01.

**Status:** DONE

---

### TODO M0-03 — `solid_generator` skeleton + build.yaml

**Goal:** Empty builder wired into `build_runner` with the `source/ → lib/` mapping.

**SPEC references:** Section 2, Section 11.

**Files to create/modify:**

- `packages/solid_generator/pubspec.yaml` — deps on `analyzer: ^13.0.0`, `build: ^4.0.5`, `build_config: ^1.3.0`, `dart_style: ^3.1.8`, `solid_annotations` (path: `../solid_annotations`); dev_deps on `build_runner: ^2.14.0`, `build_test`, `test`.
- `packages/solid_generator/build.yaml` — `build_extensions: {'^source/{{}}.dart': ['lib/{{}}.dart']}`, `build_to: source`, `auto_apply: dependents`, explicit `sources: [source/**, lib/**, pubspec.*, $package$]`.
- `packages/solid_generator/lib/builder.dart` — `Builder solidBuilder(BuilderOptions opts)` factory that returns a no-op builder (reads input, writes it unchanged to the mapped output path).
- `packages/solid_generator/test/.gitkeep`.

**Acceptance:**

- `dart analyze packages/solid_generator` → zero issues.
- `dart test packages/solid_generator` (empty suite) passes.
- Running `dart run build_runner build` from `example/` (after M0-05) copies source files to lib verbatim.

**Dependencies:** M0-01, M0-02.

**Status:** DONE

---

### TODO M0-05 — `example/` hello-world shell

**Goal:** Minimal Flutter app with `source/counter.dart` (hand-written) and `lib/main.dart` (entry point). Used as both M0 smoke-test and M1-05 canonical golden.

**SPEC references:** Section 2, Section 11, Section 12.

**Files to create/modify:**

- `example/pubspec.yaml` — Flutter app deps on `solid_annotations` (path `../packages/solid_annotations`) and `flutter_solidart: ^2.7.3`; dev_deps on `solid_generator` (path `../packages/solid_generator`) and `build_runner: ^2.14.0`.
- `example/analysis_options.yaml` — `include: package:very_good_analysis/analysis_options.yaml`, lint suppressions: `must_be_immutable: ignore`, `always_put_required_named_parameters_first: ignore`, `invalid_annotation_target: ignore`.
- `example/source/counter.dart` — hello-world stateful widget with no annotations (plain `Text('hello')`). Replaced by M1-05 golden source.
- `example/lib/main.dart` — `void main() => runApp(MaterialApp(home: Counter()));` importing `counter.dart`. Hand-written; must survive `dart run build_runner build` because M0-03 is a no-op for files without annotations.

**Acceptance:**

- `dart pub get` in `example/` succeeds.
- `dart run build_runner build --delete-conflicting-outputs` in `example/` exits 0; `example/lib/counter.dart` is identical to `example/source/counter.dart`.
- `flutter run -d chrome` (or any device) boots and shows "hello".

**Dependencies:** M0-03.

**Status:** DONE

---

### TODO M0-06 — Integration test harness

**Goal:** The `golden_test.dart` file that M1+ TODOs extend, even with zero cases registered.

**SPEC references:** None (infrastructure).

**Files to create/modify:**

- `packages/solid_generator/test/integration/golden_test.dart` — iterates a `_goldenNames` list (empty in M0), reads `inputs/<name>.dart` + `outputs/<name>.g.dart`, runs `testBuilder(solidBuilder(BuilderOptions.empty), {'a|source/$name.dart': input}, outputs: {'a|lib/$name.dart': expected})`. Supports `UPDATE_GOLDENS=1` env var to rewrite outputs.
- `packages/solid_generator/test/golden/inputs/.gitkeep`, `packages/solid_generator/test/golden/outputs/.gitkeep`.

**Acceptance:**

- `dart test packages/solid_generator/test/integration/golden_test.dart` passes with zero assertions.
- Docs: helper function signature is stable so M1 TODOs only add names.

**Dependencies:** M0-03.

**Status:** DONE

---

## M1 — `@SolidState` on fields → `Signal`

### TODO M1-01 — Golden: int field with initializer

**Goal:** Canonical case — `@SolidState() int counter = 0;` on a `StatelessWidget` becomes a `Signal<int>(0, name: 'counter')` on a generated `State<Counter>`.

**SPEC references:** Section 4.1, Section 8.1, Section 9, Section 10.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_01_int_field_with_initializer.dart`
- `packages/solid_generator/test/golden/outputs/m1_01_int_field_with_initializer.g.dart`
- entry in `packages/solid_generator/test/integration/golden_test.dart`

**Expected input content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected output content:** (The generator preserves every source import verbatim per SPEC Section 9 and appends `flutter_solidart`; `dart fix --apply` prunes the now-unused `solid_annotations` import at the consumer-app level.)

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

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
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected implementation change:** First real builder pass. Needs:

1. Parse AST via `package:analyzer`.
2. Detect `@SolidState` on a class field.
3. Class-kind dispatch (Section 8): StatelessWidget → split into StatefulWidget + State pair.
4. Emit `final <name> = Signal<T>(<init>, name: '<name>');` per SPEC Section 4.1.
5. Synthesize `dispose()` per SPEC Section 10.
6. Adjust imports per SPEC Section 9.

**Acceptance:**

- `dart test --name=m1_01` passes.
- `dart analyze packages/solid_generator/test/golden/outputs/m1_01_int_field_with_initializer.g.dart` → zero issues.
- Reviewer rubric passes.

**Dependencies:** M0-03, M0-06.

**Status:** DONE

---

### TODO M1-02 — Golden: late non-nullable field

**Goal:** `@SolidState() late String text;` becomes `late final text = Signal<String>.lazy(name: 'text');`. Validates SPEC Section 4.2 `Signal.lazy` emission + `late` preservation.

**SPEC references:** Section 4.2, Section 3.1 (valid targets).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_02_late_string_no_initializer.dart`
- `packages/solid_generator/test/golden/outputs/m1_02_late_string_no_initializer.g.dart`
- entry in `packages/solid_generator/test/integration/golden_test.dart`

**Expected input content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Greeting extends StatelessWidget {
  Greeting({super.key});

  @SolidState()
  late String text;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected output content:** (The generator preserves every source import verbatim per SPEC Section 9 and appends `flutter_solidart`; `dart fix --apply` prunes the now-unused `solid_annotations` import at the consumer-app level.)

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Greeting extends StatefulWidget {
  const Greeting({super.key});

  @override
  State<Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<Greeting> {
  late final text = Signal<String>.lazy(name: 'text');

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected implementation change:** Extend the field builder to emit `Signal<T>.lazy(name: '…')` when the source field is `late` with no initializer (SPEC Section 4.2). Preserve the `late` modifier verbatim on the emitted Dart field. Works uniformly for any declared type.

**Acceptance:**

- `dart test --name=m1_02` passes.
- `dart analyze` on the golden output → zero issues.

**Dependencies:** M1-01.

**Status:** DONE

---

### TODO M1-03 — Golden: nullable int field

**Goal:** `@SolidState() int? value;` becomes `final value = Signal<int?>(null, name: 'value');`. No `late` because nullable fields have a `null` default.

**SPEC references:** Section 4.3, Section 3.1 valid targets.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_03_nullable_int_field.dart`
- `packages/solid_generator/test/golden/outputs/m1_03_nullable_int_field.g.dart`
- entry in `packages/solid_generator/test/integration/golden_test.dart`

**Expected input content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Score extends StatelessWidget {
  Score({super.key});

  @SolidState()
  int? value;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected output content:**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Score extends StatefulWidget {
  const Score({super.key});

  @override
  State<Score> createState() => _ScoreState();
}

class _ScoreState extends State<Score> {
  final value = Signal<int?>(null, name: 'value');

  @override
  void dispose() {
    value.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected implementation change:** Extend the field builder to recognize the nullable branch (Section 4.3) and emit `null` as the default without the `late` keyword.

**Acceptance:** `dart test --name=m1_03` passes; golden analyzes clean.

**Dependencies:** M1-01.

**Status:** DONE

---

### TODO M1-04 — Golden: custom `name:` parameter

**Goal:** `@SolidState(name: 'myCounter') int counter = 0;` becomes `Signal<int>(0, name: 'myCounter')`.

**SPEC references:** Section 3.1, Section 4.4.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_04_custom_name_parameter.dart`
- `packages/solid_generator/test/golden/outputs/m1_04_custom_name_parameter.g.dart`
- entry in `golden_test.dart`

**Expected implementation change:** Extend the annotation parser to read the `name:` parameter from the annotation's argument list and thread it into the emitted `Signal(..., name: '<x>')` call.

**Acceptance:** `dart test --name=m1_04` passes; golden analyzes clean.

**Dependencies:** M1-01.

**Status:** DONE

---

### TODO M1-05 — Golden: blog-post canonical counter

**Goal:** End-to-end: blog-post Counter source transforms to a working counter widget with FAB write and Text read.

**SPEC references:** Section 4.1, Section 5.2 (interpolation), Section 5.3 (compound assignment), Section 6.0, Section 6.2 (onPressed), Section 7 (SignalBuilder placement), Section 8.1.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_05_counter_stateless_full.dart`
- `packages/solid_generator/test/golden/outputs/m1_05_counter_stateless_full.g.dart`
- entry in `golden_test.dart`

**Expected input content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class CounterPage extends StatelessWidget {
  CounterPage({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Counter is $counter')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

**Expected output content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }
}
```

**Expected implementation change:** Integration of field builder (M1-01), compound-assignment rewrite (Section 5.3), interpolation rewrite (Section 5.2), untracked-callback rule (Section 6.2), SignalBuilder minimum-subtree placement (Section 7.2). Build method uses a block body (`{ return ...; }`) — the Flutter idiom for build methods — to establish the house style for every later golden.

**Acceptance:**

- `dart test --name=m1_05` passes.
- Golden analyzes clean.
- Widget test `m1_05_widget` (TODO M1-10) renders, taps the FAB, and observes exactly one `Text` rebuild with `counter == 1`.

**Dependencies:** M1-01, M1-04 (for name handling wiring), and the visit-tree rewrite logic introduced here is reused by M3.

**Status:** DONE

---

### TODO M1-06 — Golden: plain class (no widget) with dispose

**Goal:** A non-widget class with `@SolidState` fields gets signals + synthesized `dispose()` (no `super.dispose()`; plain class's supertype chain is `Object` only).

**SPEC references:** Section 8.3, Section 10.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_06_plain_class_no_widget.dart`
- `packages/solid_generator/test/golden/outputs/m1_06_plain_class_no_widget.g.dart`
- entry in `golden_test.dart`

**Expected input content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int value = 0;

  @SolidState()
  String label = '';
}
```

**Expected output content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter {
  final value = Signal<int>(0, name: 'value');
  final label = Signal<String>('', name: 'label');

  void dispose() {
    label.dispose();
    value.dispose();
  }
}
```

(Per SPEC §9 the generator preserves every source import verbatim and never prunes; unused-import cleanup is `dart fix --apply`'s job.)

**Expected implementation change:** Class-kind dispatch adds "plain class" branch (Section 8.3). Dispose synthesis uses reverse declaration order (Section 10) and omits `super.dispose()` when the supertype chain has no `dispose()` method.

**Acceptance:** `dart test --name=m1_06` passes; golden analyzes clean.

**Dependencies:** M1-01.

**Status:** DONE

---

### TODO M1-07 — Golden: existing State<X> class (issue #3) + lifecycle preservation

**Goal:** A `StatefulWidget` whose existing `State<X>` subclass hosts `@SolidState` fields gets transformed in-place, not re-wrapped. Custom `initState` / `didUpdateWidget` overrides are preserved untouched; if an existing `dispose()` body is present, reactive disposals are prepended and the rest of the body is left alone. This is the fix for the v1 bug filed as issue #3 and locks SPEC Section 14 item 4.

**SPEC references:** Section 8.2, Section 10, Section 14 item 4, Section 16 (#3).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_07_existing_state_class.dart`
- `packages/solid_generator/test/golden/outputs/m1_07_existing_state_class.g.dart`
- entry in `golden_test.dart`

**Expected input content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  @SolidState()
  int counter = 0;

  final _subscription = Stream.periodic(const Duration(seconds: 1)).listen((_) {});

  @override
  void initState() {
    super.initState();
    debugPrint('init');
  }

  @override
  void didUpdateWidget(covariant Counter oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('update');
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected output content:**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  final counter = Signal<int>(0, name: 'counter');

  final _subscription = Stream.periodic(const Duration(seconds: 1)).listen((_) {});

  @override
  void initState() {
    super.initState();
    debugPrint('init');
  }

  @override
  void didUpdateWidget(covariant Counter oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('update');
  }

  @override
  void dispose() {
    counter.dispose();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected implementation change:** Class-kind dispatch detects the existing `State<X>` case by walking the `createState()` return type; applies reactive transformation in place instead of splitting the class. `initState` and `didUpdateWidget` bodies pass through untouched. The existing `dispose()` body has reactive disposals prepended; the existing `_subscription.cancel()` and `super.dispose()` remain at their original positions.

**Acceptance:** `dart test --name=m1_07` passes; golden analyzes clean; no new class is emitted (the `_CounterState` class count in the output equals the input); `initState` and `didUpdateWidget` bodies are byte-identical between input and output; the `dispose()` body has `counter.dispose();` prepended and nothing else added or removed.

**Dependencies:** M1-01.

**Status:** DONE

---

### TODO M1-08 — Golden: import rewrite (issue #8)

**Goal:** The generator adds `package:flutter_solidart/flutter_solidart.dart` to the output whenever any of its names are emitted, and relies on `dart fix --apply` to prune the unused `solid_annotations` import.

**SPEC references:** Section 9, Section 16 (#8).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_08_import_rewrite.dart`
- `packages/solid_generator/test/golden/outputs/m1_08_import_rewrite.g.dart`
- entry in `golden_test.dart`

**Expected input content:** Any class with a `@SolidState` field + an explicit `import 'package:solid_annotations/solid_annotations.dart';` in the source.

**Expected output content:** Output adds the `flutter_solidart` import. The `solid_annotations` import stays in the raw generator output — this test asserts the raw output. A sibling test (or a `dart fix --apply` invocation in the example app) verifies the end-state cleanup.

**Expected implementation change:** Import analysis in the generator: collect every identifier in the emitted AST, check each against the Section 9 list; if any match, prepend the import.

**Acceptance:** `dart test --name=m1_08` passes; golden analyzes clean.

**Dependencies:** M1-01.

**Status:** DONE

---

### TODO M1-09 — Idempotency: two-run byte equality

**Goal:** Running the generator twice on the same input produces byte-identical output.

**SPEC references:** None directly — this is a test of the Section 5.4 invariant ("once `counter.value` has been rewritten, the outer expression's type is `int` ... so the rule stops applying").

**Files to create:**

- `packages/solid_generator/test/integration/idempotency_test.dart` — runs each golden input through the builder twice and asserts the second output equals the first.

**Expected implementation change:** None (tests the invariant already produced by M1-01 through M1-08). If it fails, the generator has state or non-determinism that must be fixed.

**Acceptance:** Test passes for every golden currently listed.

**Dependencies:** M1-01 through M1-08.

**Status:** DONE

---

### TODO M1-10 — Widget test: FAB tap rebuilds only Text

**Goal:** With the M1-05 golden running inside `example/`, a FAB tap rebuilds only the `Text` widget; a sibling widget (e.g., an icon) does not rebuild.

**SPEC references:** Section 7 (SignalBuilder placement), Section 14 item 7.

**Files to create:**

- `example/test/counter_widget_test.dart` — uses `testWidgets` + a `BuildTracker` (test helper) to count rebuilds per widget. After the FAB tap: `Text` rebuild count == 1; sibling icon rebuild count == 0.

**Expected implementation change:** The `BuildTracker` helper may need to live in `example/test/helpers/build_tracker.dart` and wrap `Text` / `Container` in a tracking widget that increments a counter in its `build`.

**Acceptance:** `flutter test example/` passes; the test explicitly asserts sibling rebuild count is zero.

**Dependencies:** M1-05.

**Status:** DONE

---

### DONE M1-11 — Widget test: dispose on Navigator pop

**Goal:** When the page containing `@SolidState` signals is popped from `Navigator`, each signal's `dispose()` is invoked.

**SPEC references:** Section 10.

**Files to create:**

- `example/test/counter_dispose_test.dart` — pushes a test-local mirror of `_CounterPageState` onto the Navigator, registers a `signal.onDispose(...)` callback during `initState`, pops the route, asserts the callback fired exactly once.

**Expected implementation change:** None in the generator. The test observes the `SignalBase<T>.onDispose(VoidCallback)` hook (declared in `solidart`, exported by `flutter_solidart`) — the same public contract real user code uses. No `SpySignal` subclass is needed; subclassing `flutter_solidart.Signal` would tie the helper to the value-notifier wrapper layer and require a parallel `SpyComputed` for M2-04, whereas `onDispose` works on every `SignalBase` (Signal, Computed, all collection signals) unchanged.

**Acceptance:** Test passes; the `onDispose` callback records exactly one call per signal after Navigator pop.

**Dependencies:** M1-01, M1-10.

**Status:** DONE

---

### DONE M1-12 — Golden: class without annotations passes through

**Goal:** A `.dart` file under `source/` that contains NO `@Solid*` annotation is copied byte-for-byte to `lib/`. No transformation, no re-formatting, no import addition.

**SPEC references:** Section 2 (transformation-vs-verbatim-copy), Section 8.4.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_12_passthrough_no_annotations.dart`
- `packages/solid_generator/test/golden/outputs/m1_12_passthrough_no_annotations.g.dart` — byte-identical to the input.
- entry in `golden_test.dart`.

**Expected input content:** A plain `StatelessWidget` that does NOT import `solid` and has NO annotations:

```dart
import 'package:flutter/widgets.dart';

class Hello extends StatelessWidget {
  const Hello({super.key});

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected output content:** Identical to input.

**Expected implementation change:** The top-level pipeline checks for the `@Solid` substring (the `_solidAnnotationHint` guard in `packages/solid_generator/lib/builder.dart`) before invoking the parser/rewriter — SPEC Section 2 hot-path short-circuit. If absent, write input bytes to the output path unchanged. The post-parse fallback in `_collectAnnotatedClasses` covers the corner case where `@Solid` appears as a substring (e.g. inside a comment) but resolves to no fields; both paths preserve byte-identity.

**Acceptance:** `dart test --name=m1_12` passes; output bytes equal input bytes.

**Dependencies:** M1-01.

**Status:** DONE

---

### DONE M1-13 — Golden: multi-ctor + factory + init-list preservation

**Goal:** A `StatelessWidget` with multiple constructors — unnamed + named generative + factory — round-trips through the rewriter with every constructor preserved verbatim on the public widget class. `this.X` parameters and constructor-initializer-list field assignments are recognised as widget-bound bindings; init-list-bound fields stay on the widget alongside `this.X` props; everything else moves to the State class.

**SPEC references:** Section 8.1, Section 14 item 7, Section 9.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_13_multiple_constructors.dart` — `Counter` with an unnamed `this.title` ctor, a named generative ctor that binds `title` via init-list (`Counter.named({super.key}) : title = 'Named'`), and a factory ctor with a body (`factory Counter.fromInt(int value) { … }`); plus a `final String title;` widget prop and an `@SolidState() int counter = 0;`.
- `packages/solid_generator/test/golden/outputs/m1_13_multiple_constructors.g.dart` — all three constructors preserved verbatim on the rewritten `StatefulWidget`; `final String title;` stays on the widget; `counter` becomes the only Signal on the State class.
- entry in `golden_helpers.dart`.

**Expected implementation change:** The stateless rewriter walks **every** `ConstructorDeclaration` on the source class (not just the unnamed) and emits each one verbatim. `this.X` field parameters and `: field = expr` initializer-list assignments are unioned across every generative constructor (factory ctors are skipped — they construct via a body, never bind). Every non-`@SolidState` field is then partitioned: widget-bound (name in the union) → kept on the widget verbatim; everything else → moved to the State class. The generator does NOT add or remove `const` on any constructor; per SPEC §9, `dart fix --apply` is the trusted lint pass that adds `const` after the class split removes mutable fields from the widget. Goldens are accordingly pre-`dart fix`; `prefer_const_constructors_in_immutables` is suppressed in `test/golden/analysis_options.yaml` for the same reason `unused_import` is.

**Acceptance:** `dart test --name=m1_13_multiple_constructors` passes; `dart analyze --fatal-infos packages/solid_generator/` reports zero issues.

**Dependencies:** M1-01.

**Status:** DONE

---

### TODO M1-14 — Rejection: invalid `@SolidState` targets

**Goal:** The generator rejects `@SolidState` on every invalid target enumerated in SPEC Section 3.1 with a clear, per-case error message that identifies the offending declaration.

**SPEC references:** Section 3.1 "Invalid targets".

**Files to create:**

- `packages/solid_generator/test/rejections/m1_14_invalid_targets_test.dart` — parametric test over the six cases. Each case is a minimal source snippet that places `@SolidState` on the invalid target; each asserts the builder raises an error whose message contains the SPEC description of the case (e.g., `"@SolidState on a final field"`, `"@SolidState on a static member"`, etc.).
- One input file per case under `packages/solid_generator/test/golden/inputs/m1_14_*.dart`:
  - `m1_14_final_field.dart` — `@SolidState() final int x = 0;`
  - `m1_14_const_field.dart` — `@SolidState() static const int x = 0;` (use only `const` on a non-static field if Dart allows; otherwise keep the static+const pair and cover by the `const` clause)
  - `m1_14_static_field.dart` — `@SolidState() static int x = 0;`
  - `m1_14_static_getter.dart` — `@SolidState() static int get x => 0;`
  - `m1_14_top_level.dart` — top-level `@SolidState() int x = 0;`
  - `m1_14_method.dart` — `@SolidState() void doThing() {}`
  - `m1_14_setter.dart` — `@SolidState() set x(int v) {}`

**Expected implementation change:** Annotation-target validation runs before transformation. Any invalid target produces a `TransformationError` with a SPEC-quoted message that names the target kind and the enclosing class + member identifier.

**Acceptance:** The parametric test passes; every case produces a distinct error message that contains the SPEC description of the invalid-target category.

**Dependencies:** M1-01.

**Status:** DONE

---

### TODO M1-15 — Rejection: non-M1 annotations (`@SolidEffect`, `@SolidQuery`, `@SolidEnvironment`)

**Goal:** Per SPEC Section 3.2, any source file containing `@SolidEffect`, `@SolidQuery`, or `@SolidEnvironment` causes the build to fail with an error naming the annotation and stating `"not yet implemented; scheduled for a later v2 milestone"`.

**SPEC references:** Section 3.2, Section 13.

**Files to create:**

- `packages/solid_generator/test/rejections/m1_15_non_m1_annotations_test.dart` — three parametric cases, one per annotation.
- Input files under `packages/solid_generator/test/golden/inputs/`:
  - `m1_15_effect.dart` — `class Foo { @SolidEffect() void side() {} }`
  - `m1_15_query.dart` — `class Foo { @SolidQuery() Future<int> fetch() async => 0; }`
  - `m1_15_environment.dart` — `class Foo { @SolidEnvironment() late int injected; }`

**Expected implementation change:** The annotation-scanning pass recognizes each of the three reserved annotation classes from `package:solid_annotations`. Any detection emits `"@SolidEffect is not yet implemented; scheduled for a later v2 milestone"` (with the annotation name substituted).

**Acceptance:** All three cases produce the exact SPEC-quoted error with the correct annotation name.

**Dependencies:** M0-02, M1-01.

**Status:** DONE

---

## M2 — `@SolidState` on getters → `Computed`

### TODO M2-01 — Golden: simple Computed with deps

**Goal:** `@SolidState() int get doubleCounter => counter * 2;` becomes `late final doubleCounter = Computed<int>(() => counter.value * 2, name: 'doubleCounter');`.

**SPEC references:** Section 4.5, Section 5.1 (identifier rewrite).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m2_01_simple_computed_with_deps.dart`
- `packages/solid_generator/test/golden/outputs/m2_01_simple_computed_with_deps.g.dart`
- entry in `golden_test.dart`

**Expected input content:** Class with `@SolidState() int counter = 0;` plus `@SolidState() int get doubleCounter => counter * 2;`.

**Expected output content:**

```dart
final counter = Signal<int>(0, name: 'counter');
late final doubleCounter = Computed<int>(() => counter.value * 2, name: 'doubleCounter');

@override
void dispose() {
  doubleCounter.dispose();
  counter.dispose();
  super.dispose();
}
```

**Expected implementation change:** Getter-annotated branch in the class visitor: synthesize `late final` Computed, rewrite identifiers in the body per Section 5.1 type resolution, apply reverse-declaration dispose order (Section 10).

**Acceptance:** `dart test --name=m2_01` passes; golden analyzes clean; dispose body calls `doubleCounter.dispose()` BEFORE `counter.dispose()`.

**Dependencies:** M1-01.

**Status:** DONE

---

### TODO M2-01b — Golden: block-body getter → Computed

**Goal:** A `@SolidState` getter with a block body (`{ ... return ...; }`) becomes a `Computed<T>` whose function expression preserves the block body verbatim with reactive reads rewritten.

**SPEC references:** Section 4.6.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m2_01b_block_body_computed.dart`
- `packages/solid_generator/test/golden/outputs/m2_01b_block_body_computed.g.dart`
- entry in `golden_test.dart`.

**Expected input content:** Mirror the Section 4.6 SPEC example: a class with `@SolidState() int counter = 0;` and `@SolidState() String get summary { final c = counter; return 'count is $c'; }`.

**Expected output content:** Per Section 4.6:

```dart
final counter = Signal<int>(0, name: 'counter');
late final summary = Computed<String>(() {
  final c = counter.value;
  return 'count is $c';
}, name: 'summary');
```

**Expected implementation change:** The getter branch of the class visitor must handle both expression-body (`=> ...`) and block-body (`{ ... }`) forms. For block body, wrap the original block in a `() { ... }` function expression and apply Section 5.1 identifier rewriting inside.

**Acceptance:** `dart test --name=m2_01b` passes; golden analyzes clean.

**Dependencies:** M2-01.

**Status:** DONE

---

### TODO M2-02 — Rejection: Computed with zero deps

**Goal:** `@SolidState() int get constantFive => 5;` must be rejected at build time with SPEC's exact error message. A `Computed` with no deps is a plain constant.

**SPEC references:** Section 4.5 (rejection clause).

**Files to create:**

- `packages/solid_generator/test/rejections/.gitkeep` (if the directory does not yet exist).
- `packages/solid_generator/test/golden/inputs/m2_02_computed_no_deps_rejected.dart`
- `packages/solid_generator/test/rejections/m2_02_computed_no_deps_test.dart` — asserts the builder raises an error containing `"getter 'constantFive' has no reactive dependencies"`.

**Expected implementation change:** After visiting a getter body, check whether any identifier resolved to `SignalBase<T>`. If none, emit the SPEC-defined error.

**Acceptance:** Rejection test passes; error message text matches SPEC quote exactly.

**Dependencies:** M2-01.

**Status:** DONE

---

### TODO M2-03 — Golden: Computed read inside `build`

**Goal:** A read of the Computed inside `build()` receives `.value` and the enclosing subtree is wrapped in `SignalBuilder`.

**SPEC references:** Section 5.1, Section 7.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m2_03_computed_read_in_build.dart`
- `packages/solid_generator/test/golden/outputs/m2_03_computed_read_in_build.g.dart`
- entry in `golden_test.dart`

**Expected implementation change:** None beyond M2-01 + M1-05 — the Section 5.1 rule is type-driven and works for `Computed<T>` as well as `Signal<T>`.

**Acceptance:** `dart test --name=m2_03` passes; golden analyzes clean.

**Dependencies:** M2-01, M1-05.

**Status:** DONE

---

### TODO M2-04 — Golden: dispose order (Computed before Signal)

**Goal:** Confirm reverse-declaration disposal: a class with both a Signal and a Computed produces a `dispose()` that disposes the Computed first.

**SPEC references:** Section 10.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m2_04_dispose_order.dart`
- `packages/solid_generator/test/golden/outputs/m2_04_dispose_order.g.dart`
- entry in `golden_test.dart`

**Expected implementation change:** Already exercised by M2-01; this TODO is the explicit regression test if M2-01 hides ordering behind a single case.

**Acceptance:** `dart test --name=m2_04` passes; golden's `dispose()` body has `computed.dispose()` before `signal.dispose()`.

**Dependencies:** M2-01.

**Status:** DONE

---

## M3 — Untracked reads + fine-grained SignalBuilder

### TODO M3-01 — Golden: Text(counter) receives `.value` inside SignalBuilder (issue #6)

**Goal:** A bare identifier `counter` passed as a positional arg to `Text(...)` is rewritten to `counter.value` AND the `Text` is wrapped in `SignalBuilder`.

**SPEC references:** Section 5.1, Section 7, Section 16 (#6).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_01_text_arg_gets_value.dart`
- `packages/solid_generator/test/golden/outputs/m3_01_text_arg_gets_value.g.dart`
- entry in `golden_test.dart`

**Expected input content:** A minimal widget whose `build()` contains exactly one top-level `Text(counter)` and nothing else reactive — no FAB, no interpolation, no other reads. The isolated case forces the rewriter to handle a bare-identifier positional arg in a `Text` constructor without being helped by neighboring patterns.

**Expected implementation change:** Exercised by M1-05 at integration scale; this golden narrows the input to the exact shape v1 issue #6 failed on (bare identifier arg) so a regression shows up with a single-case failure.

**Acceptance:** `dart test --name=m3_01` passes; golden analyzes clean.

**Dependencies:** M1-05.

**Status:** DONE

---

### TODO M3-02 — Golden: onPressed write stays untracked (issue #4)

**Goal:** `onPressed: () => counter++` becomes `counter.value++` without `SignalBuilder` wrapping of the button. Compound-assignment writes never subscribe per SPEC Section 6.0.

**SPEC references:** Section 5.3, Section 6.0, Section 6.2, Section 16 (#4).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_02_onpressed_untracked.dart`
- `packages/solid_generator/test/golden/outputs/m3_02_onpressed_untracked.g.dart`
- entry in `golden_test.dart`

**Expected input content:** A minimal widget whose `build()` returns a single `FloatingActionButton` with `onPressed: () => counter++` and NO other reactive read. The isolated case forces the rewriter to recognize that the FAB must not be wrapped in `SignalBuilder` — a single-file failure pinpoints an over-wrap regression instantly.

**Expected implementation change:** Exercised by M1-05 at integration scale; this golden narrows the input to the exact shape v1 issue #4 failed on (write inside an untracked callback).

**Acceptance:** `dart test --name=m3_02` passes; the output `FloatingActionButton(...)` is NOT wrapped in `SignalBuilder`.

**Dependencies:** M1-05.

**Status:** DONE

---

### TODO M3-03 — Golden: ValueKey(counter) is tracked

**Goal:** A read inside `ValueKey(counter)` gets `.value` AND wraps the enclosing widget in `SignalBuilder` — the new default after dropping the v1-era SPEC 6.3 auto-untracking enumeration. Users opt out per-read via the `.untracked` extension once M3-12 lands.

**SPEC references:** Section 6.5 (everything else is tracked).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_03_value_key_tracked.dart`
- `packages/solid_generator/test/golden/outputs/m3_03_value_key_tracked.g.dart`
- entry in `golden_helpers.dart` `goldenNames`

**Expected implementation change:** Two deletions and one placement fix.

1. Remove SPEC Section 6.3 entirely; strip `_keyConstructors`, `_isKeyUntracked`, and the `visitInstanceCreationExpression` hook from `value_rewriter.dart`.
2. Patch `placement_visitor.dart` `_WidgetCollector` to skip constructor expressions used as the value of a `key:` named argument — Keys are not Widgets and cannot host a `SignalBuilder` wrapper. (SPEC 6.3 had been hiding this latent placement bug by untracking the read entirely. The KISS pivot makes the bug visible, so it ships its fix here.)

**Acceptance:** `dart test --name=m3_03` passes; output `SignalBuilder` wraps the enclosing `Container`, with `ValueKey(counter.value)` inside as the Key.

**Dependencies:** M1-05.

**Status:** DONE

---

### TODO M3-04 — Widget test: sibling isolation

**Goal:** Two sibling widgets each reading different signals. Mutating signal A rebuilds only widget A; widget B's rebuild count stays at zero.

**SPEC references:** Section 7.4 (siblings do not share wrappers).

**Files to create:**

- `example/test/sibling_isolation_test.dart` — two `@SolidState` fields, two sibling `Text` widgets each reading one field. Increment A, assert A rebuilt and B did not.

**Expected implementation change:** Validates that M1-05's minimum-subtree wrap rule (Section 7.2) produces sibling isolation.

**Acceptance:** Test passes; rebuild count for B is zero after mutating A.

**Dependencies:** M1-10.

**Status:** DONE

---

### DONE M3-05 — Type-aware no-double-append

**Goal:** `controller.value` in source (where `controller` is a `TextEditingController`, NOT a Solid signal) is left untouched. No `controller.value.value` regression.

**SPEC references:** Section 5.4.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_05_type_aware_no_double_append.dart`
- `packages/solid_generator/test/golden/outputs/m3_05_type_aware_no_double_append.g.dart`
- entry in `golden_test.dart`

**Expected input content:** A widget reading `controller.value` on a `TextEditingController` AND `counter` on a `@SolidState` field; only `counter` should receive `.value`.

**Expected implementation change:** The rewriter resolves the static type of every identifier via `package:analyzer` and only rewrites when it is a subtype of `SignalBase<T>` (Section 5.1 + 5.4).

**Acceptance:** `dart test --name=m3_05` passes; the `controller.value` in the output is unchanged; the `counter` is rewritten to `counter.value`.

**Dependencies:** M1-05.

**Status:** DONE

---

### DONE M3-06 — Golden: string interpolation

**Goal:** `'$counter'` becomes `'${counter.value}'`.

**SPEC references:** Section 5.2.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_06_string_interpolation_bare.dart`
- `packages/solid_generator/test/golden/outputs/m3_06_string_interpolation_bare.g.dart`
- entry in `golden_test.dart`

**Expected implementation change:** Already produced by M1-05; this is the focused regression case. Verify that already-wrapped `${counter.value}` stays untouched (double-rewrite prevention via Section 5.4 type rule).

**Acceptance:** `dart test --name=m3_06` passes; golden analyzes clean.

**Dependencies:** M1-05.

**Status:** DONE

---

### TODO M3-07 — Golden: explicit `untracked(() => ...)` opt-out

**Superseded by M3-12** (`.untracked` extension replaces the function-call form). Keep this entry as a roadmap stub so cross-references resolve; do not ship.

**Goal (historical):** `Text('snapshot: ${untracked(() => counter)}')` keeps `.value` on `counter` (per Section 5.1) but does NOT wrap the enclosing `Text` in `SignalBuilder`.

**SPEC references:** Section 6.4 (subject to rewrite under M3-12).

**Status:** OBSOLETE — see M3-12.

---

### TODO M3-08 — Golden: Builder-style closures stay tracked

**Goal:** `Builder(builder: (context) => Text(counter))` is wrapped in `SignalBuilder`. `builder:` is not an untracked-callback name (Section 6.2).

**SPEC references:** Section 6.6.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_08_builder_closure_tracked.dart`
- `packages/solid_generator/test/golden/outputs/m3_08_builder_closure_tracked.g.dart`
- entry in `golden_test.dart`

**Expected implementation change:** The untracked-callback detector uses the Section 6.2 enumerated list. Any parameter name NOT on that list (e.g. `builder`, `itemBuilder`, `separatorBuilder`) does not mark reads as untracked.

**Acceptance:** `dart test --name=m3_08` passes; output wraps the inner widget in `SignalBuilder`.

**Dependencies:** M1-05.

**Status:** DONE

---

### TODO M3-09 — Golden: shadowing

**Goal:** A local variable named the same as a reactive field, bound to a non-SignalBase type, shadows the field correctly. The inner read is NOT rewritten.

**SPEC references:** Section 5.5.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_09_shadowing.dart`
- `packages/solid_generator/test/golden/outputs/m3_09_shadowing.g.dart`
- entry in `golden_test.dart`

**Expected input content:**

```dart
@SolidState() int counter = 0;

@override
Widget build(BuildContext context) {
  return Builder(builder: (context) {
    final counter = 'local'; // shadows the field; type is String
    return Text(counter);    // stays as `counter`
  });
}
```

**Expected output content:** The inner `Text(counter)` is NOT rewritten; the outer field reference (absent in this case because the build body is an expression that starts with `Builder(...)`) is not re-introduced. Outer `Builder` is wrapped per M3-08 only if it contains a tracked read — here it does not (inner is shadowed), so NO wrapper is added.

**Expected implementation change:** Validates that the Section 5.1 type-driven rule handles shadowing automatically — no extra generator logic.

**Acceptance:** `dart test --name=m3_09` passes; output analyzes clean; no `.value` added to the shadowed identifier; no `SignalBuilder` around the `Builder`.

**Dependencies:** M3-05, M3-08.

**Status:** DONE

---

### TODO M3-10 — Golden: hand-written SignalBuilder is not double-wrapped

**Goal:** If source already contains `SignalBuilder(builder: ...)` around a tracked read, the generator does NOT add a second wrapper.

**SPEC references:** Section 7.3.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_10_existing_signalbuilder.dart`
- `packages/solid_generator/test/golden/outputs/m3_10_existing_signalbuilder.g.dart`
- entry in `golden_test.dart`.

**Expected input content:** A class whose `build()` body manually wraps a tracked read in `SignalBuilder(builder: (context, child) => Text('$counter'))`.

**Expected output content:** Identical `SignalBuilder` shape — only `$counter` becomes `${counter.value}`. The enclosing widget tree gains NO additional `SignalBuilder` wrapper.

**Expected implementation change:** The placement rule (Section 7.1 clause 3) checks the ancestor chain for an existing `SignalBuilder` before wrapping. If one is present, skip.

**Acceptance:** `dart test --name=m3_10` passes; output has exactly one `SignalBuilder` (the hand-written one).

**Dependencies:** M1-05.

**Status:** DONE

---

### TODO M3-11 — Golden: nested tracked reads — only inner wraps

**Goal:** When an outer widget expression and an inner widget expression both contain tracked reads, only the inner expression is wrapped. The outer expression relies on the inner `SignalBuilder` to trigger its rebuild.

**SPEC references:** Section 7.5.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_11_nested_tracked_reads.dart`
- `packages/solid_generator/test/golden/outputs/m3_11_nested_tracked_reads.g.dart`
- entry in `golden_test.dart`.

**Expected input content:** A widget whose `build()` returns a column with a top-level tracked read (e.g., `Text('$counter')`) and a nested `Text('$counter')` inside a child subtree. Both read the same signal.

**Expected output content:** Only the innermost `Text` is wrapped in `SignalBuilder`. The outer `Text` is also wrapped because it is itself a leaf; the Column is NOT wrapped. The rule is "smallest subtree per read"; equal-depth independent reads each get their own wrapper.

**Expected implementation change:** The placement visitor walks bottom-up. For each tracked read, it identifies the smallest enclosing widget-constructor expression and marks it for wrapping. Parent wrappers are suppressed for any subtree already covered by a descendant wrapper.

**Acceptance:** `dart test --name=m3_11` passes; the golden has zero `SignalBuilder` wrappers around the outer Column.

**Dependencies:** M1-05.

**Status:** DONE

---

### TODO M3-12 — `.untracked` extension replaces `untracked()` opt-out

**Goal:** Replace `untracked(() => counter)` with `counter.untracked` as the single, canonical opt-out marker for read tracking. Supersedes M3-07.

**Why:** KISS — one mechanism, no closure boilerplate, reads naturally at the call site. `Container(key: ValueKey(counter.untracked))` is the migration story for users who actually want the v1-era SPEC 6.3 auto-untracking behavior that M3-03 dropped.

**SPEC references:** Section 6.4 (full rewrite).

**Files to modify / create:**

- `packages/solid_annotations/lib/solid_annotations.dart` — add `extension Untracked<T> on T { T get untracked => this; }` (or scoped equivalent — design to be finalized in this TODO).
- `packages/solid_generator/lib/src/value_rewriter.dart` — detect `.untracked` `PropertyAccess` on a reactive field; emit the untracked-read primitive (e.g., `Signal.peek()`) and exclude the offset from `trackedReadOffsets`. Remove the existing `untracked()` function-call special-case in `visitMethodInvocation`.
- `SPEC.md` Section 6.4 — rewrite around the extension form.
- New goldens: `m3_12_untracked_extension` input/output pair.

**Open questions to resolve in this TODO:**

- Exact untracked-read primitive name on `flutter_solidart`'s Signal API (`peek()`, `untracked` getter, etc.) — verify against the package source.
- Extension scope: on `T`, on a marker mixin, or on a sentinel? Tradeoff is API-surface pollution vs source-typecheck friction.
- Migration policy for users on `untracked(() => ...)` — silent drop of generator special-casing, or a generator warning?

**Acceptance:** `dart test --name=m3_12` passes; `Text('${counter.untracked}')` produces an untracked-read output (no `SignalBuilder` wrap).

**Dependencies:** M1-05.
**Supersedes:** M3-07.

**Status:** DONE

---

## M4 — `@SolidEffect`

### TODO M4-01 — Golden: simple `@SolidEffect` method with one Signal dep

**Goal:** `@SolidEffect() void logCounter() { print('Counter changed: $counter'); }` on a `StatelessWidget` (next to `@SolidState() int counter = 0;`) becomes `late final logCounter = Effect(() { print('Counter changed: ${counter.value}'); }, name: 'logCounter');` on the synthesized State class. Establishes the M4 lowering pipeline: `EffectModel`, `readSolidEffectMethod`, `emitEffectField`, and the non-getter `MethodDeclaration` branch in `_collectAnnotatedClasses`.

**SPEC references:** Section 3.4, Section 4.7, Section 5.1 (identifier rewrite), Section 5.2 (string interpolation), Section 9 (import — `Effect` already on canonical list), Section 10 (dispose order).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m4_01_simple_effect_with_deps.dart`
- `packages/solid_generator/test/golden/outputs/m4_01_simple_effect_with_deps.g.dart`
- entry in `packages/solid_generator/test/integration/golden_helpers.dart` `goldenNames`
- `packages/solid_generator/lib/src/effect_model.dart` — new model file, parallel to `getter_model.dart`. Carries `methodName`, `bodyText` (already with `.value` rewrites applied), and `annotationName`.

**Files to modify:**

- `packages/solid_annotations/lib/src/annotations.dart` — replace the `SolidEffect` placeholder with `@Target({TargetKind.method}) class SolidEffect { const SolidEffect({this.name}); final String? name; }`.
- `packages/solid_generator/lib/src/annotation_reader.dart` — add `EffectModel? readSolidEffectMethod(MethodDeclaration decl, Set<String> reactiveFieldNames, String source)`; reuse `findSolidStateAnnotation` + `extractNameArgument` patterns (consider factoring a shared `findSolidAnnotation(String className, …)` helper if it tightens the code).
- `packages/solid_generator/lib/src/signal_emitter.dart` — add `String emitEffectField(EffectModel e)` returning the `late final … = Effect(() { … }, name: '…');` line (zero-param callback per SPEC §4.7). Extend `emitDispose`'s argument-list semantics so Effects join Signals/Computeds in the unified ordered name list.
- `packages/solid_generator/lib/builder.dart` — extend `_AnnotatedClass` to carry `final List<EffectModel> effects;`; extend `_collectAnnotatedClasses` to walk `MethodDeclaration` members where `!member.isGetter && !member.isSetter`; pass `effects` through `_rewriteClass` to all three rewriters.
- `packages/solid_generator/lib/src/stateless_rewriter.dart` — accept `solidEffects`; interleave Signal/Computed/Effect fields in source order; pass merged disposable-name list to `emitDispose`.
- `packages/solid_generator/lib/src/state_class_rewriter.dart`, `packages/solid_generator/lib/src/plain_class_rewriter.dart` — for now, reject `@SolidEffect` with a `CodeGenerationError("@SolidEffect on State<X>/plain class will land in M4-08")` until M4-08 ships them.

**Expected input content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidState()
  int counter = 0;

  @SolidEffect()
  void logCounter() {
    print('Counter changed: $counter');
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected output content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter extends StatefulWidget {
  Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  final counter = Signal<int>(0, name: 'counter');
  late final logCounter = Effect(() {
    print('Counter changed: ${counter.value}');
  }, name: 'logCounter');

  @override
  void dispose() {
    logCounter.dispose();
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Acceptance:** `dart test --name=m4_01` passes; golden analyzes clean; dispose body calls `logCounter.dispose()` BEFORE `counter.dispose()`; the upstream `Effect` constructor signature accepted by `flutter_solidart` matches what the golden emits (zero-param callback `() { … }` per SPEC §4.7 — verify the disposer-vs-`.dispose()` semantics against the package source at impl time and adjust the `dispose()` body if the upstream returns a function rather than an object).

**Dependencies:** M2-01 (body-rewrite pipeline + `MethodDeclaration` collection path), M2-01b (block-body precedent).

**Implementation note:** M4-01 also pulled in M4-06's three substeps because `validateReservedAnnotations` runs before the lowering pipeline — without removing `'SolidEffect'` from `_reservedAnnotations` and migrating the `m1_15_effect` rejection case in the same PR, the M4-01 golden could never go green. The bootstrap deviation is documented inline in `reserved_annotation_validator.dart` and in the M4-06 entry below. Zero-deps Effect rejection (SPEC §3.4 / TODOS M4-05) also landed here in `_rewriteEffectBody` so M4-05 is purely a regression-test PR.

**Status:** DONE

---

### TODO M4-02 — Golden: `@SolidEffect` co-exists with `@SolidState` field + getter

**Goal:** A class with all three annotated shapes — `@SolidState()` field, `@SolidState()` getter, `@SolidEffect()` method — produces a State class with Signal + Computed + Effect interleaved in source order, and a `dispose()` body in reverse-declaration order. Validates the unified ordered-name list under all three lowered shapes.

**SPEC references:** Section 4.1, Section 4.5, Section 4.7, Section 10.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m4_02_effect_with_signal_and_computed.dart`
- `packages/solid_generator/test/golden/outputs/m4_02_effect_with_signal_and_computed.g.dart`
- entry in `golden_helpers.dart` `goldenNames`

**Expected input content:** A `StatelessWidget` with (in source order) `@SolidState() int counter = 0;`, `@SolidState() int get doubleCounter => counter * 2;`, `@SolidEffect() void logBoth() { print('$counter / $doubleCounter'); }`.

**Expected output content:** State class declares `counter` (Signal), then `doubleCounter` (late final Computed), then `logBoth` (late final Effect) — all in source order. `dispose()` body calls `logBoth.dispose()`, then `doubleCounter.dispose()`, then `counter.dispose()`, then `super.dispose()` — reverse declaration order per SPEC Section 10.

**Expected implementation change:** None beyond M4-01 + M2-01 — this is a regression fence on the unified ordering rule, validating that the M4-01-extended `emitDispose` argument list correctly interleaves all three shapes.

**Acceptance:** `dart test --name=m4_02` passes; golden's `dispose()` body has Effect → Computed → Signal → super order verbatim.

**Dependencies:** M4-01.

**Status:** DONE

---

### TODO M4-03 — Golden: `@SolidEffect` block-body with multi-statement and shadowing

**Goal:** A `@SolidEffect` method with a block body that contains multiple statements and a local variable that shadows a reactive-field name produces an Effect whose body preserves the block verbatim with reactive reads rewritten and shadowed locals untouched. Validates that Sections 5.1 and 5.5 apply uniformly inside Effect bodies.

**SPEC references:** Section 4.7, Section 5.1, Section 5.5.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m4_03_effect_block_body_shadowing.dart`
- `packages/solid_generator/test/golden/outputs/m4_03_effect_block_body_shadowing.g.dart`
- entry in `golden_helpers.dart` `goldenNames`

**Expected input content:** Class with `@SolidState() int counter = 0;` plus `@SolidEffect() void logCounter() { final counter = 'shadowed'; final c = counter; print(c); print('field: $counter'); }`. The local `counter` shadows the field for the first two statements but the third statement re-references the local — and there's NO outer field read inside the block (the third statement is inside the same scope).

**Expected output content:** The Effect body has the local declarations preserved; the local `counter` reads stay as `counter` (no `.value`); there are no outer reactive reads at all (so the body does not subscribe to anything). This means the Effect would have ZERO reactive deps — therefore this case must instead exercise mixed shadowing: the outer scope reads `counter` (rewritten to `counter.value`) BEFORE the inner shadow scope rebinds it (stays as `counter`). Concretely: `void logCounter() { print('outer: $counter'); { final counter = 'shadowed'; print('inner: $counter'); } }`.

**Expected implementation change:** None beyond M4-01 + M2-01b — this is a regression fence on the shadowing rule applied to Effect bodies.

**Acceptance:** `dart test --name=m4_03` passes; golden analyzes clean; outer `$counter` becomes `${counter.value}`; inner `$counter` stays as `$counter`; the Effect has at least one reactive dep (the outer read), so M4-05's zero-dep rejection does not fire.

**Dependencies:** M4-01.

**Status:** DONE

---

### TODO M4-04 — Rejection: invalid `@SolidEffect` targets

**Goal:** The generator rejects `@SolidEffect` on every invalid target enumerated in SPEC Section 3.4 with a clear, per-case error message that identifies the offending declaration. Mirror of M1-14.

**SPEC references:** Section 3.4 "Invalid targets".

**Files to create:**

- `packages/solid_generator/test/rejections/m4_04_invalid_effect_targets_test.dart` — parametric test over the seven cases below. Each case is a minimal source snippet that places `@SolidEffect` on the invalid target; each asserts the builder raises an error whose message contains the SPEC description of the case.
- One input file per case under `packages/solid_generator/test/golden/inputs/`:
  - `m4_04_parameterized.dart` — `@SolidEffect() void doThing(int x) {}`
  - `m4_04_non_void_return.dart` — `@SolidEffect() int compute() => 0;`
  - `m4_04_static.dart` — `@SolidEffect() static void doThing() {}`
  - `m4_04_abstract.dart` — `@SolidEffect() void doThing();` on an abstract class member.
  - `m4_04_getter.dart` — `@SolidEffect() int get x => 0;`
  - `m4_04_setter.dart` — `@SolidEffect() set x(int v) {}`
  - `m4_04_top_level.dart` — top-level `@SolidEffect() void doThing() {}`
  - `m4_04_field.dart` — `@SolidEffect() int counter = 0;` (field, not method)

**Expected implementation change:** Extend `target_validator.dart` with a parallel `validateSolidEffectTargets` (or a unified validator that branches on which annotation is present). The check runs before transformation. Any invalid target produces a `ValidationError` with a SPEC-quoted message that names the target kind and the enclosing class + member identifier.

**Acceptance:** The parametric test passes; every case produces a distinct error message that contains the SPEC description of the invalid-target category from Section 3.4.

**Dependencies:** M4-01.

**Status:** DONE

---

### TODO M4-05 — Rejection: zero reactive deps in Effect body

**Goal:** `@SolidEffect() void doThing() { print('no signals here'); }` must be rejected at build time with the SPEC-defined error: `"effect 'doThing' has no reactive dependencies"`. An Effect with no deps is a one-shot function call; the user should call it explicitly instead. Mirror of M2-02.

**SPEC references:** Section 3.4 "Reactive-deps requirement", Section 4.7.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m4_05_effect_no_deps_rejected.dart` — class with `@SolidEffect() void doThing() { print('hello'); }` and no `@SolidState` fields.
- `packages/solid_generator/test/rejections/m4_05_effect_no_deps_test.dart` — asserts the builder raises an error containing `"effect 'doThing' has no reactive dependencies"`.

**Expected implementation change:** After visiting an Effect body, check whether any identifier resolved to `SignalBase<T>`. If none, emit the SPEC-defined error. Reuses the same pattern as M2-02's zero-dep Computed check; the only difference is the error message wording (`"effect"` vs `"getter"`).

**Acceptance:** Rejection test passes; error message text matches SPEC Section 3.4 quote exactly.

**Dependencies:** M4-01.

**Implementation note:** The runtime detection already shipped with M4-01 — `_readReactiveBody` in `packages/solid_generator/lib/src/annotation_reader.dart` throws the SPEC §3.4 error when `collectValueEdits(...).edits.isEmpty`, and `readSolidEffectMethod` already passes the SPEC-defined `emptyDepsError` string. M4-05 added the dedicated rejection fixture + test (`test/golden/inputs/m4_05_effect_no_deps_rejected.dart` + `test/rejections/m4_05_effect_no_deps_test.dart`) to pin this behavior independent of M4-01's regress.

**Status:** DONE

---

### TODO M4-06 — Migration: remove `@SolidEffect` from reserved-annotation list

**Goal:** Once M4-01 through M4-05 are green and `@SolidEffect` is fully transformed, the reserved-annotation rejection must stop firing on it. Remove `'SolidEffect'` from `_reservedAnnotations` and migrate the M1-15 `m1_15_effect` case to a golden (or delete it if M4-01 already covers the equivalent shape).

**SPEC references:** Section 3.2 (reserved-annotation list, post-M4 trim — already trimmed in the M4 design seed PR), Section 13 (deferred features).

**Files to modify:**

- `packages/solid_generator/lib/src/reserved_annotation_validator.dart` — remove `'SolidEffect'` from the `_reservedAnnotations` map at lines 9-13.
- `packages/solid_generator/test/rejections/m1_15_non_m1_annotations_test.dart` — delete the `m1_15_effect` case at lines 8-13 (or whatever the current line range is after M4-01 lands).
- `packages/solid_generator/test/golden/inputs/m1_15_effect.dart` — delete (no longer a rejection input).

**Expected implementation change:** A one-line trim in the validator; a small test deletion; an input-file deletion. No new code paths.

**Acceptance:** `dart test packages/solid_generator/` passes; the remaining `m1_15_query` and `m1_15_environment` rejection cases still fire; M4-01 through M4-05 all still pass.

**Dependencies:** M4-01, M4-02, M4-03, M4-04, M4-05.

**Implementation note:** All three substeps were pulled into M4-01 because `validateReservedAnnotations` (`builder.dart`) runs before `_collectAnnotatedClasses`; without trimming the reserved list and migrating the `m1_15_effect` case in the same PR, the M4-01 golden test could never go green. The dependency arrow above is therefore retroactive — M4-06 shipped *with* M4-01.

**Status:** DONE

---

### TODO M4-07 — Widget test: Effect fires on each tap

**Goal:** With an `@SolidEffect` method that increments a separate counter (or appends to a list-typed Signal), tapping the FAB three times causes the Effect body to run three times. The test reads the recorded values and asserts the count.

**SPEC references:** Section 4.7, Section 10 (Effect disposal on tear-down).

**Files to create:**

- `example/test/effect_widget_test.dart` — `testWidgets` test that:
  1. Pumps a widget with `@SolidState() int counter = 0;`, `@SolidState() List<int> history = [];`, and `@SolidEffect() void recordHistory() { history.value = [...history.value, counter]; }`. (Or a simpler shape using a non-Solid `List` field that the Effect mutates and the test inspects via a `GlobalKey`.)
  2. Taps the FAB three times.
  3. Asserts the Effect body ran three times by checking the recorded history.

**Expected implementation change:** None in the generator. The test exercises the runtime contract (Effect fires on dep change) end-to-end through the M4-01 lowered output.

**Acceptance:** `flutter test example/` passes; the recorded history has exactly three entries after three taps; on Navigator pop, the Effect's `dispose()` is invoked (assert via a `signal.onDispose` hook on a wrapper Signal, parallel to M1-11).

**Dependencies:** M4-01, M4-06 (Effect must no longer be reserved).

**Implementation note:** This PR also added a synthesized `initState()` block (`signal_emitter.dart::emitInitState`) and regenerated the M4-01/M4-02/M4-03 goldens. Without that fix, the `late final` Effect field is never materialized at mount time, so the Effect's autorun never fires during the widget's mounted lifetime — see SPEC §4.7. The widget-test's `recordHistory` Effect reads `history.untrackedValue` on the spread to avoid the self-dep loop where the Effect's own `history.value = …` write would re-fire it.

**Status:** DONE

---

### TODO M4-08 — Golden: `@SolidEffect` on existing `State<X>` class

**Goal:** A `StatefulWidget` whose existing `State<X>` subclass hosts `@SolidEffect` methods is transformed in-place, not re-wrapped. Custom `initState` / `didUpdateWidget` overrides are preserved untouched; if an existing `dispose()` body is present, Effect disposals are prepended and the rest of the body is left alone. Mirror of M1-07. Removes the `state_class_rewriter.dart` / `plain_class_rewriter.dart` guards that M4-01 added.

**SPEC references:** Section 4.7, Section 8.2, Section 8.3, Section 10.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m4_08_effect_on_state_class.dart`
- `packages/solid_generator/test/golden/outputs/m4_08_effect_on_state_class.g.dart`
- `packages/solid_generator/test/golden/inputs/m4_08_effect_on_plain_class.dart`
- `packages/solid_generator/test/golden/outputs/m4_08_effect_on_plain_class.g.dart`
- entries in `golden_helpers.dart` `goldenNames`

**Files to modify:**

- `packages/solid_generator/lib/src/state_class_rewriter.dart` — remove the M4-01 reject guard; route Effects through the same in-place lowering used by Signals/Computeds.
- `packages/solid_generator/lib/src/plain_class_rewriter.dart` — same.

**Expected implementation change:** Both rewriters interleave Effect emission with Signal/Computed emission per source order, and append Effect dispose calls to the unified ordered name list. The merge-into-existing-`dispose()` logic from M1-07 already handles the prepend-then-keep-existing-body shape.

**Acceptance:** `dart test --name=m4_08` passes; both goldens analyze clean; `initState` and `didUpdateWidget` bodies are byte-identical between input and output; the existing `dispose()` body has Effect/Computed/Signal disposal calls prepended in reverse-declaration order with nothing else added or removed.

**Dependencies:** M4-01, M1-07.

**Implementation note:** Three pieces beyond the simple guard removal:

1. New `emitConstructor(className, effectNames)` helper in `signal_emitter.dart` — the plain-class analogue of `emitInitState`. A plain class has no widget lifecycle, so the synthesized constructor body materializes Effects via bare-id reads at construction time; SPEC §8.3 was extended with a sentence describing this. The helper is only invoked when `effectNames` is non-empty, preserving byte-equality with the M1-06 Signal-only plain-class golden.
2. New `_mergeInitState` in `state_class_rewriter.dart`, mirroring `_mergeDispose` — when Effects exist on a `State<X>` subclass that also declares `initState`, materialization reads (`<effectName>;`) are spliced in immediately after the `super.initState();` call (or after the opening brace if the user's body lacks the super call). SPEC §14 item 4 was extended with this carve-out. When no `initState` exists and Effects are present, a fresh one is synthesized via `emitInitState`.
3. Both in-place rewriters now extend their `solidartNames` set with `'Effect'` when at least one Effect is present, so the import-rewriter adds `package:flutter_solidart/flutter_solidart.dart` for the Effect symbol used in the body. The walk in `state_class_rewriter` was refactored to build `disposeNames` incrementally during the member walk so Signal field names and Effect method names interleave by source-declaration order — required for SPEC §10's reverse-disposal correctness when Signals and Effects coexist. User-defined constructors on plain classes remain rejected: the synthesized constructor and a user constructor are mutually exclusive in this milestone.

**Status:** DONE

---

## M5 — `@SolidQuery`

### TODO M5-01 — Golden: simple `@SolidQuery` Future-method on `StatelessWidget` (no upstream signals)

**Goal:** `@SolidQuery() Future<String> fetchData() async => 'fetched';` on a `StatelessWidget` becomes a single `late final fetchData = Resource<String>(...)` field — no underscore prefix, no thin-accessor wrapper. The user's source-side `fetchData()` calls and `fetchData.refresh()` tear-offs are byte-identical in lowered output: at runtime, `fetchData()` invokes the upstream `Resource<T>.call() => state;` operator (returning `ResourceState<T>` for `.when` chains), and `fetchData.refresh()` resolves to the upstream `Resource<T>.refresh()` direct method. No body rewrite mutates the call sites. Establishes the M5 lowering pipeline: `QueryModel`, `readSolidQueryMethod`, `emitResourceField` (Future branch only, no auto-tracking), the non-getter `MethodDeclaration` branch in `_collectAnnotatedClasses` keyed on `Future<T>` return type, and a SignalBuilder-placement detection rule that records `<queryName>()` call offsets in the tracked-read set (so the enclosing widget subtree gets wrapped). Also performs the M4-06-style migration: removes `'SolidQuery'` from `_reservedAnnotations` and migrates the `m1_15_query` rejection case to a positive golden. Adds the source-time stub extensions to `solid_annotations`.

**SPEC references:** Section 3.5, Section 4.8 (single-field lowering + rule 3 SignalBuilder-placement detection), Section 5.1 (identifier rewrite — note the rewrite does NOT apply to query call expressions per §5.1's clarification), Section 7 (SignalBuilder placement around tracked reads), Section 9 (import — `Resource` already on canonical list), Section 10 (dispose order), Section 14 item 4 (queries are NOT spliced into `initState`).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m5_01_simple_query_with_future.dart`
- `packages/solid_generator/test/golden/outputs/m5_01_simple_query_with_future.g.dart`
- entry in `packages/solid_generator/test/integration/golden_helpers.dart` `goldenNames`
- `packages/solid_generator/lib/src/query_model.dart` — new model file, parallel to `effect_model.dart`. Carries `methodName`, `bodyText` (already with `.value` rewrites applied; auto-tracking source-list lands in M5-10), `innerTypeText` (the `T` peeled from `Future<T>`), `isStream` (false in M5-01; reserved for M5-02), `debounce` (null in M5-01; reserved for M5-11), `useRefreshing` (null in M5-01; reserved for M5-11), `annotationName`.
- `packages/solid_annotations/lib/src/query_extensions.dart` — copy verbatim from the v1 reference at `solid_annotations-1.0.0/lib/extensions.dart`: `extension FutureWhen<T> on Future<T>` (`.when` / `.maybeWhen` returning `Widget`), `extension StreamWhen<T> on Stream<T>` (same surface), `extension RefreshFuture<T> on Future<T> Function()` (`.refresh()` returning `Future<void>`), `extension RefreshStream<T> on Stream<T> Function()` (same), `extension IsRefreshingFuture<T> on Future<T>` (`.isRefreshing` returning `bool`), `extension IsRefreshingStream<T> on Stream<T>` (same). Every method body throws `Exception('This is just a stub for code generation.')`. Exported from `solid_annotations.dart`. NOTE: there are NO runtime extensions on `Resource<T>` or `ResourceState<T>` in `solid_annotations` — the body rewriter turns `fetchData()` into `fetchData.state` so the chain resolves to upstream `flutter_solidart` extensions on `ResourceState<T>` directly (SPEC §4.8 rule 2).

**Files to modify:**

- `packages/solid_annotations/lib/src/annotations.dart` — replace the `SolidQuery` placeholder with `@Target({TargetKind.method}) class SolidQuery { const SolidQuery({this.name, this.debounce, this.useRefreshing = true}); final String? name; final Duration? debounce; final bool useRefreshing; }`. The `debounce:` and `useRefreshing:` fields are wired in M5-11; M5-01 only asserts the field shape.
- `packages/solid_annotations/lib/solid_annotations.dart` — re-export the new `query_extensions.dart`.
- `packages/solid_annotations/pubspec.yaml` — add `flutter` as a runtime dep (the source-side stubs return `Widget`, requiring `flutter`). `flutter_solidart` is NOT added: `solid_annotations` references no flutter_solidart symbols; the user's source never names `Resource<T>` or `ResourceState<T>` (those types appear only in lowered `lib/` output, where `flutter_solidart` is already a runtime dep of the consumer app). M0-02 originally kept `solid_annotations` deps-free; M5 introduces only `flutter` because the source-time typecheck contract (SPEC §3.5 "Source-time typechecking") requires Widget-typed return signatures on the stubs.
- `packages/solid_generator/lib/src/annotation_reader.dart` — add `QueryModel? readSolidQueryMethod(MethodDeclaration decl, Set<String> reactiveFieldNames, String source)`; reuse `findSolidStateAnnotation` / `extractNameArgument` patterns. Peel `Future<T>` from `decl.returnType` to produce `innerTypeText`. Critically, this reader does NOT call the zero-deps check — a query body with no reactive reads is valid (SPEC §3.5 "No reactive-deps requirement").
- `packages/solid_generator/lib/src/signal_emitter.dart` — add `String emitResourceField(QueryModel q)` returning `late final <methodName> = Resource<T>(() async => …, name: '…');` (public name, no underscore prefix). The string is emitted in source-declaration order alongside Signal/Computed/Effect declarations. Extend `emitDispose`'s argument-list semantics so the `<methodName>` name joins Signals/Computeds/Effects in the unified ordered name list.
- `packages/solid_generator/lib/src/value_rewriter.dart` (or its visitor module) — extend `collectValueEdits`'s visitor to detect zero-argument `MethodInvocation` nodes whose target is a `SimpleIdentifier` matching a `@SolidQuery` method name on the enclosing class (with no receiver and no shadowing local) and add the call-expression's offset to the existing `trackedReadOffsets` set. NO edit is emitted for the call itself — at runtime `<queryName>()` invokes the upstream `Resource<T>.call() => state;` operator and the trailing `.when(...)` / `.maybeWhen(...)` / `.isRefreshing` chain resolves to upstream extensions on `ResourceState<T>` directly. The query-name set is passed alongside the existing `reactiveFieldNames` set. The `<queryName>.refresh()` form (tear-off + member-call) is also left unchanged — `Resource<T>.refresh()` is a direct upstream method.
- `packages/solid_generator/lib/builder.dart` — extend `_AnnotatedClass` to carry `final List<QueryModel> queries;`; extend `_collectAnnotatedClasses` to walk `MethodDeclaration` members where `!member.isGetter && !member.isSetter && carriesSolidQuery && returnType is Future<T>`. Pass the query-name set into `collectValueEdits` so the call-expression rewrite has the data it needs.
- `packages/solid_generator/lib/src/stateless_rewriter.dart` — accept `solidQueries`; for each query, emit the public `<methodName>` Resource field interleaved with Signal/Computed/Effect declarations in source order; pass the merged disposable-name list to `emitDispose` (the public `<methodName>` participates).
- `packages/solid_generator/lib/src/state_class_rewriter.dart`, `packages/solid_generator/lib/src/plain_class_rewriter.dart` — for now, reject `@SolidQuery` with a `CodeGenerationError("@SolidQuery on State<X>/plain class will land in M5-08/M5-09")` until those TODOs ship them.
- `packages/solid_generator/lib/src/reserved_annotation_validator.dart` — remove `'SolidQuery'` from the `_reservedAnnotations` map.
- `packages/solid_generator/test/rejections/m1_15_non_m1_annotations_test.dart` — delete the `m1_15_query` case.
- `packages/solid_generator/test/golden/inputs/m1_15_query.dart` — delete (no longer a rejection input).

**Expected input content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Greeter extends StatelessWidget {
  Greeter({super.key});

  @SolidQuery()
  Future<String> fetchData() async {
    await Future.delayed(const Duration(seconds: 1));
    return 'fetched';
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected output content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Greeter extends StatefulWidget {
  Greeter({super.key});

  @override
  State<Greeter> createState() => _GreeterState();
}

class _GreeterState extends State<Greeter> {
  late final fetchData = Resource<String>(
    () async {
      await Future.delayed(const Duration(seconds: 1));
      return 'fetched';
    },
    name: 'fetchData',
  );

  @override
  void dispose() {
    fetchData.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Acceptance:** `dart test --name=m5_01` passes; golden analyzes clean; the State class has NO `initState()` override (queries are lazy and not materialized — SPEC §4.8 / §14 item 4) AND NO underscore-prefixed Resource field (single public `<name>` field per query); `dispose()` calls `fetchData.dispose()` before `super.dispose()`; `m1_15_query` rejection test no longer runs (case deleted); `dart analyze packages/solid_generator/test/golden/outputs/m5_01_*.g.dart` reports zero issues; source-side `solid_annotations` stubs allow `Greeter`'s source to compile if a build body invokes `fetchData().when(...)` (added as a smoke check in M5-04).

**Dependencies:** M4-01 (body-rewrite pipeline + non-getter `MethodDeclaration` collection path), M4-06 (reserved-list trim pattern).

**Implementation note:** Like M4-01, M5-01 also pulls in the M4-06-style migration (remove from `_reservedAnnotations`, migrate `m1_15_query`) because the reserved-annotation guard runs before lowering — without removing `'SolidQuery'` and migrating the rejection case in the same PR, the M5-01 golden could never go green. Document this inline in `reserved_annotation_validator.dart` similar to the M4-01 comment. The new `flutter` dep on `solid_annotations` is unavoidable: SPEC §3.5 "Source-time typechecking" requires the source-side stubs to return `Widget`. `flutter_solidart` is NOT added as a `solid_annotations` dep because the user's source layer does not name `Resource<T>`. The M0-02 "no runtime deps" rule is therefore amended in M5-01 (only `flutter`). The SignalBuilder-placement detection (visitor records `<queryName>()` offsets in `trackedReadOffsets`) is registered in M5-01 even though M5-01's golden has no call sites to exercise it (the build body is `const Placeholder()`); the detection is exercised end-to-end in M5-04's golden where SignalBuilder wraps the `fetchData().when(...)` chain.

**Status:** TODO

---

### TODO M5-02 — Golden: `@SolidQuery` Stream-method form

**Goal:** `@SolidQuery() Stream<int> watchTicks() => Stream.periodic(const Duration(seconds: 1), (i) => i);` on a `StatelessWidget` becomes `late final _watchTicks = Resource<int>.stream(() => Stream.periodic(...), name: 'watchTicks');` plus `Resource<int> watchTicks() => _watchTicks;`. Adds the `Resource<T>.stream(...)` branch in `emitResourceField`, the `isStream` discriminator in `QueryModel`, and the Stream-form body handling in `readSolidQueryMethod` (plain-bodied returning a Stream, OR `async*` block-bodied).

**SPEC references:** Section 3.5, Section 4.8 (Stream form).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m5_02_simple_query_with_stream.dart`
- `packages/solid_generator/test/golden/outputs/m5_02_simple_query_with_stream.g.dart`
- entry in `golden_helpers.dart` `goldenNames`

**Files to modify:**

- `packages/solid_generator/lib/src/query_model.dart` — confirm `isStream` flag is consumed.
- `packages/solid_generator/lib/src/annotation_reader.dart` — extend `readSolidQueryMethod` to detect `Stream<T>` return type and either body shape (synchronous returning a `Stream<T>`, OR `async*` block); set `isStream: true`.
- `packages/solid_generator/lib/src/signal_emitter.dart` — extend `emitResourceField` to emit `Resource<T>.stream(...)` instead of `Resource<T>(...)` when `isStream` is true.

**Expected input content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Ticker extends StatelessWidget {
  Ticker({super.key});

  @SolidQuery()
  Stream<int> watchTicks() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected output content:** State class with `late final _watchTicks = Resource<int>.stream(() => Stream.periodic(const Duration(seconds: 1), (i) => i), name: 'watchTicks');` plus `Resource<int> watchTicks() => _watchTicks;`. Standard `dispose()` body.

**Expected implementation change:** Stream-form branch in `emitResourceField` plus `isStream` detection in the reader. No changes to dispose / accessor / import paths beyond what M5-01 already established.

**Acceptance:** `dart test --name=m5_02` passes; golden analyzes clean; emitted code uses `Resource<T>.stream(...)` named constructor; the thin-accessor's return type is `Resource<int>`.

**Dependencies:** M5-01.

**Status:** TODO

---

### TODO M5-03 — Golden: `@SolidQuery` co-exists with `@SolidState` field + getter + `@SolidEffect`

**Goal:** A class with all four annotated shapes — `@SolidState()` field, `@SolidState()` getter, `@SolidEffect()` method, `@SolidQuery()` method — produces a State class with all four lowered shapes interleaved in source order, and a `dispose()` body in reverse-declaration order. `initState()` materializes ONLY the Effect (queries are lazy per §4.8). Validates the unified ordered-name list under all four lowered shapes.

**SPEC references:** Section 4.1, Section 4.5, Section 4.7, Section 4.8, Section 10, Section 14 item 4.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m5_03_query_with_signal_computed_effect.dart`
- `packages/solid_generator/test/golden/outputs/m5_03_query_with_signal_computed_effect.g.dart`
- entry in `golden_helpers.dart` `goldenNames`

**Expected input content:** A `StatelessWidget` with (in source order) `@SolidState() int counter = 0;`, `@SolidState() int get doubleCounter => counter * 2;`, `@SolidEffect() void logBoth() { print('$counter / $doubleCounter'); }`, `@SolidQuery() Future<int> fetchSnapshot() async => 0;` (no upstream signals — auto-tracking lands in M5-10).

**Expected output content:** State class declares `counter` (Signal), then `doubleCounter` (late final Computed), then `logBoth` (late final Effect), then `_fetchSnapshot` (late final Resource) + `fetchSnapshot()` thin-accessor — all in source order. `initState()` materializes ONLY `logBoth` after `super.initState();`. `dispose()` body calls `_fetchSnapshot.dispose()`, then `logBoth.dispose()`, then `doubleCounter.dispose()`, then `counter.dispose()`, then `super.dispose()` — reverse declaration order per SPEC Section 10.

**Expected implementation change:** None beyond M5-01 + M4-02 — this is a regression fence on the unified dispose-ordering rule across all four shapes AND a regression fence proving Effects (always materialized) and queries (NEVER materialized) coexist correctly.

**Acceptance:** `dart test --name=m5_03` passes; golden's `dispose()` body has Resource → Effect → Computed → Signal → super order verbatim; `initState()` body is `super.initState(); logBoth;` (no `_fetchSnapshot;`).

**Dependencies:** M5-01, M4-02.

**Status:** TODO

---

### TODO M5-04 — Golden: `fetchData().when(ready:..., loading:..., error:...)` byte-identical, wrapped in SignalBuilder

**Goal:** A widget whose `build` body invokes `fetchData().when({ready, loading, error})` is lowered such that (a) the build method is wrapped in a `SignalBuilder` (the SignalBuilder-placement detection rule fires on the `fetchData()` call expression — SPEC §4.8 rule 3) and (b) the `fetchData().when(...)` chain is byte-identical between input and output. At runtime, `fetchData()` invokes the upstream `Resource<T>.call() => state;` operator returning `ResourceState<T>`, and `.when(...)` resolves to upstream `flutter_solidart`'s extension on `ResourceState<T>` directly. Validates the source-time typecheck contract (`fetchData().when(...)` typechecks against the `Future<T>.when` stub in `solid_annotations`) AND the runtime contract (lowered `fetchData()` is the upstream callable on a `Resource<String>` field). Critical regression fence for the SPEC §4.8 rule 3 detection rule and §7 SignalBuilder placement.

**SPEC references:** Section 3.5 "Read pattern", Section 3.5 "Source-time typechecking", Section 4.8 (single-field lowering, rule 2 byte-identical call expressions, rule 3 SignalBuilder-placement detection), Section 5.1 (rewrite does not apply to query call expressions per §5.1's clarification), Section 7 (SignalBuilder placement around tracked reads).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m5_04_query_when_in_build.dart`
- `packages/solid_generator/test/golden/outputs/m5_04_query_when_in_build.g.dart`
- entry in `golden_helpers.dart` `goldenNames`

**Expected input content:**

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class UserScreen extends StatelessWidget {
  UserScreen({super.key});

  @SolidQuery()
  Future<String> fetchName() async => 'Alice';

  @override
  Widget build(BuildContext context) {
    return fetchName().when(
      ready: (name) => Text(name),
      loading: () => const CircularProgressIndicator(),
      error: (e, _) => Text('error: $e'),
    );
  }
}
```

**Expected output content:** State class with `late final fetchName = Resource<String>(() async => 'Alice', name: 'fetchName');` (single public field, no underscore-prefixed wrapper). The `build` method wraps the byte-identical chain in a `SignalBuilder`:

```dart
@override
Widget build(BuildContext context) {
  return SignalBuilder(
    builder: (context, child) {
      return fetchName().when(
        ready: (name) => Text(name),
        loading: () => const CircularProgressIndicator(),
        error: (e, _) => Text('error: $e'),
      );
    },
  );
}
```

The `fetchName().when(...)` chain is byte-identical between input and output — at runtime `fetchName()` invokes `Resource<String>.call()` (defined upstream as `ResourceState<T> call() => state;`), and `.when(...)` resolves to upstream `flutter_solidart`'s extension on `ResourceState<T>`.

**Expected implementation change:** The M5-01 SignalBuilder-placement detection rule (§4.8 rule 3) fires here: the `fetchName()` call offset is added to `trackedReadOffsets`, triggering §7 to wrap the `Center`/`Text` subtree containing the call in a `SignalBuilder`. No mutation to the call expression itself. If the detection misses, no SignalBuilder is emitted and the widget never rebuilds when the Resource emits new state.

**Acceptance:** `dart test --name=m5_04` passes; golden analyzes clean; the `fetchName().when(...)` chain is byte-identical input/output; the chain is wrapped in a `SignalBuilder`. The source under `source/` typechecks against the `Future<T>.when` stub extension from `solid_annotations`; the lowered output typechecks because `Resource<String>.call()` returns `ResourceState<String>` and `.when` is an upstream extension on `ResourceState<T>`.

**Dependencies:** M5-01.

**Status:** TODO

---

### TODO M5-05 — Rejection: invalid `@SolidQuery` targets

**Goal:** The generator rejects `@SolidQuery` on every invalid target enumerated in SPEC Section 3.5 with a clear, per-case error message that identifies the offending declaration. Mirror of M4-04.

**SPEC references:** Section 3.5 "Invalid targets".

**Files to create:**

- `packages/solid_generator/test/rejections/m5_05_invalid_query_targets_test.dart` — parametric test over the cases below. Each case is a minimal source snippet that places `@SolidQuery` on the invalid target; each asserts the builder raises an error whose message contains the SPEC description of the case.
- One input file per case under `packages/solid_generator/test/golden/inputs/`:
  - `m5_05_non_future_return.dart` — `@SolidQuery() int fetchCount() => 0;` (sync return).
  - `m5_05_future_without_async.dart` — `@SolidQuery() Future<int> fetchCount() => Future.value(0);` (Future return without `async` keyword).
  - `m5_05_parameterized.dart` — `@SolidQuery() Future<int> fetchOne(int id) async => id;`.
  - `m5_05_static.dart` — `@SolidQuery() static Future<int> fetchCount() async => 0;`.
  - `m5_05_abstract.dart` — `@SolidQuery() Future<int> fetchCount();` on an abstract class member.
  - `m5_05_getter.dart` — `@SolidQuery() Future<int> get fetchCount async => 0;`.
  - `m5_05_setter.dart` — `@SolidQuery() set fetchCount(int v) {}`.
  - `m5_05_top_level.dart` — top-level `@SolidQuery() Future<int> fetchCount() async => 0;`.
  - `m5_05_field.dart` — `@SolidQuery() Future<int> fetchCount = Future.value(0);` (field, not method).

**Files to modify:**

- `packages/solid_generator/lib/src/target_validator.dart` — extend with a parallel `validateSolidQueryTargets` (or branch in the unified validator). The check runs before transformation. Any invalid target produces a `ValidationError` with a SPEC-quoted message that names the target kind and the enclosing class + member identifier.

**Expected implementation change:** New per-case branches in `target_validator.dart`. Return-type / body-keyword checks use `decl.returnType` and `decl.body.keyword?.lexeme` ('async' / 'async\*'). The async-mismatch case (Future without `async`) produces an error that quotes SPEC §3.5 "Method whose body keyword does not match the return type".

**Acceptance:** The parametric test passes; every case produces a distinct error message that contains the SPEC description of the invalid-target category from Section 3.5.

**Dependencies:** M5-01.

**Status:** TODO

---

### TODO M5-06 — Golden: explicit `fetchData.refresh()` (tear-off form) call inside `onPressed`

**Goal:** A widget that calls `fetchData.refresh()` inside an `onPressed` callback emits the call verbatim — the source uses the method tear-off form (no `()` after `fetchData`), which after lowering naturally resolves to `Resource<T>.refresh()` (a direct upstream instance method). No body rewrite fires for this shape because the receiver is already a bare `SimpleIdentifier`, not a zero-arg `MethodInvocation`. The FAB is NOT wrapped in `SignalBuilder` (SPEC §6.2 untracked-context rule applies inside `onPressed`).

**SPEC references:** Section 3.5 "Read pattern" (refresh-tear-off shape), Section 3.5 "Source-time typechecking" (`RefreshFuture<T> on Future<T> Function()` extension), Section 4.8 rule 2 (the rewrite fires on zero-arg call form, NOT on tear-off form), Section 6.2 (untracked-context rules in `on*` callbacks).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m5_06_query_refresh_in_onpressed.dart`
- `packages/solid_generator/test/golden/outputs/m5_06_query_refresh_in_onpressed.g.dart`
- entry in `golden_helpers.dart` `goldenNames`

**Expected input content:** A widget with `@SolidQuery() Future<int> fetchCount() async => 0;` and a `FloatingActionButton(onPressed: () => fetchCount.refresh(), child: const Icon(Icons.refresh))` inside `build`. Note: source uses tear-off `fetchCount.refresh()`, NOT call form `fetchCount().refresh()` — see SPEC §3.5's "Refresh" pattern and the `RefreshFuture<T> on Future<T> Function()` source-time stub extension.

**Expected output content:** The `onPressed: () => fetchCount.refresh()` is emitted verbatim — byte-identical input/output. The FAB is NOT wrapped in `SignalBuilder`.

**Expected implementation change:** None beyond M5-01 — the call-expression rewrite (rule 2) fires only on zero-arg `MethodInvocation` shapes (`fetchCount()`), NOT on the tear-off-then-method-call shape (`fetchCount.refresh()`). The receiver `fetchCount` here is a bare `SimpleIdentifier`, and after lowering it resolves to the `Resource<int>` field; `.refresh()` chains to the upstream direct method on Resource. This golden is a regression fence proving the rewrite is shape-specific.

**Acceptance:** `dart test --name=m5_06` passes; golden analyzes clean; the source `() => fetchCount.refresh()` is byte-identical to the output `() => fetchCount.refresh()`.

**Dependencies:** M5-01.

**Status:** TODO

---

### TODO M5-07 — Widget test: tap reload three times, assert fetcher fires three times

**Goal:** With a `@SolidQuery` whose fetcher increments a test-controlled counter, tapping a "Reload" FAB three times causes the fetcher to run three times. The test asserts via the recorded count and via `fetchCount().when(ready: ...)` re-emitting each time.

**SPEC references:** Section 3.5 "Refresh", Section 4.8, Section 10 (Resource disposal on tear-down).

**Files to create:**

- `example/test/query_widget_test.dart` — `testWidgets` test that:
  1. Pumps a widget with `@SolidQuery() Future<int> fetchCount() async => _testCounter++;` (where `_testCounter` is a top-level closure-captured int reset per test).
  2. Reads `fetchCount().when(ready: (v) => Text('$v'), …)` in build.
  3. Taps the Reload FAB three times, awaiting `pumpAndSettle()` between taps so the Future resolves.
  4. Asserts the Resource's ready state ends with the correct value and the fetcher ran the expected number of times (initial subscribe + N refreshes).
  5. On Navigator pop, asserts `_fetchCount.dispose()` is invoked (parallel to M1-11 / M4-07's `signal.onDispose` hook).

**Expected implementation change:** None in the generator. The test exercises the runtime contract (Resource fetcher fires on `.refresh()`) end-to-end through the M5-01 / M5-02 lowered output.

**Acceptance:** `flutter test example/` passes; the recorded counter equals the expected fetcher-invocation count (verify against upstream `flutter_solidart` semantics: lazy-subscribe-on-first-when fires once; each `.refresh()` fires once); the `dispose()` hook fires exactly once per test.

**Dependencies:** M5-01, M5-02.

**Status:** TODO

---

### TODO M5-08 — Golden: `@SolidQuery` on existing `State<X>` class

**Goal:** A `StatefulWidget` whose existing `State<X>` subclass hosts `@SolidQuery` methods is transformed in-place, not re-wrapped. Each annotated method declaration is replaced by a single `late final <name> = Resource<T>(...)` field. Custom `initState` / `didUpdateWidget` overrides are preserved untouched (queries are lazy and not spliced into `initState` per SPEC §14 item 4); if an existing `dispose()` body is present, the `<methodName>` Resource disposal is prepended and the rest of the body is left alone. Mirror of M4-08's State-class path. Removes the `state_class_rewriter.dart` reject guard that M5-01 added.

**SPEC references:** Section 3.5, Section 4.8 (single-field lowering), Section 8.2, Section 10, Section 14 item 4.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m5_08_query_on_state_class.dart`
- `packages/solid_generator/test/golden/outputs/m5_08_query_on_state_class.g.dart`
- entry in `golden_helpers.dart` `goldenNames`

**Files to modify:**

- `packages/solid_generator/lib/src/state_class_rewriter.dart` — remove the M5-01 reject guard; route Resources through the same in-place lowering used by Signals/Computeds/Effects for the dispose-name list and import set. Extend the `solidartNames` set with `'Resource'` when at least one query is present so the import-rewriter adds `package:flutter_solidart/flutter_solidart.dart`. The existing `_mergeDispose` helper handles the public `<methodName>` name alongside other dispose names. The user-supplied query method declaration is replaced by the emitted `late final <methodName>` field (the original method body becomes the Resource fetcher closure). Any `<queryName>()` call sites inside reactive contexts have their offsets added to `trackedReadOffsets` by the body-rewrite pipeline (the M5-01 detection rule), so SignalBuilder placement wraps the surrounding subtree.

**Expected implementation change:** State class rewriter walks the user's existing class, identifies `@SolidQuery` method declarations, replaces each with the single Resource field (interleaved with Signal/Computed/Effect emissions in source order), and extends the dispose name list. No changes to `_mergeInitState` (queries don't enter the materialization list). The body-rewrite pipeline runs over every reactive context in the State class (build, Effect bodies, Computed bodies); query call expressions stay byte-identical but are tracked for SignalBuilder placement.

**Acceptance:** `dart test --name=m5_08` passes; golden analyzes clean; existing `initState` body is byte-identical between input and output (no Resource splice); existing `dispose` body has `<methodName>.dispose()` calls prepended in reverse-declaration order with nothing else added or removed; the user-supplied query-method declaration is replaced by the single Resource field; any `<queryName>()` call sites in `build` / Effect / Computed bodies are byte-identical between input and output, with SignalBuilder wrapping where applicable.

**Dependencies:** M5-01, M4-08.

**Status:** TODO

---

### TODO M5-09 — Golden: `@SolidQuery` on plain class

**Goal:** A plain class (no Widget superclass) hosting `@SolidQuery` methods is transformed in-place. Each annotated method is replaced by a single `late final <name> = Resource<T>(...)` field; disposal is added to the synthesized (or merged) `dispose()` body in reverse-declaration order. Queries do NOT trigger the M4-08 synthesized constructor (queries are lazy); a plain class with ONLY queries has no synthesized constructor. Mirror of M4-08's plain-class path. Removes the `plain_class_rewriter.dart` reject guard that M5-01 added.

**SPEC references:** Section 3.5, Section 4.8 (single-field lowering), Section 8.3, Section 10.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m5_09_query_on_plain_class.dart`
- `packages/solid_generator/test/golden/outputs/m5_09_query_on_plain_class.g.dart`
- entry in `golden_helpers.dart` `goldenNames`

**Files to modify:**

- `packages/solid_generator/lib/src/plain_class_rewriter.dart` — remove the M5-01 reject guard; route Resources through the same in-place lowering used by Signals/Computeds/Effects for the dispose-name list and import set. Extend the `solidartNames` set with `'Resource'`. The user-supplied query method declaration is replaced by the single `late final <methodName>` Resource field. Queries do NOT enter the synthesized-constructor materialization list (per SPEC §8.3). Any `<queryName>()` call sites inside reactive contexts have their offsets added to `trackedReadOffsets` by the body-rewrite pipeline (the M5-01 detection rule); the call expressions themselves are byte-identical between input and output.

**Expected implementation change:** Plain-class rewriter walks the user's existing class, identifies `@SolidQuery` method declarations, replaces each with the single Resource field, and extends the dispose-name list. The user-defined-constructor rejection from M4-08 still applies when Effects are present; for plain classes with ONLY queries (no Effects), a user-defined constructor is permitted (no synthesized constructor needed; the late-final lazy queries co-exist with the user's constructor).

**Acceptance:** `dart test --name=m5_09` passes; golden analyzes clean; the synthesized constructor (if present, due to existing Effects) does NOT have query-materialization reads; `dispose()` body has `<methodName>.dispose()` calls in reverse declaration order before `super.dispose()` (or no `super.dispose()` if the plain class has no `dispose()` in supertype chain — analyzer-driven, per SPEC §10); the user-supplied query-method declaration is replaced by the single Resource field.

**Dependencies:** M5-01, M4-08.

**Status:** TODO

---

### TODO M5-10 — Auto-tracking: query body reads upstream reactive declarations

**Goal:** When a query body reads one or more `@SolidState` field / getter identifiers, the generator wires those reads into the lowered Resource's `source:` argument. **One read** is passed directly (no synthesized field — wrapping a single `Signal` / `Computed` in a Computed that just returns its `.value` would be a no-op). **Two or more reads** synthesize a `late final _<methodName>Source = Computed<(T1, T2, …)>(() => (s1.value, s2.value, …), name: '<methodName>_source')` Record-Computed field that is passed as the source. The synthesized field, when present, is emitted IMMEDIATELY BEFORE the `_<methodName>` Resource it feeds, so reverse-declaration disposal tears the Resource down before the Computed.

**SPEC references:** Section 3.5 "Auto-tracking of upstream reactive reads", Section 4.8 rule 3, Section 10.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m5_10_query_with_one_signal_dep.dart` — query body reads ONE Signal; output passes the Signal directly as `source:`.
- `packages/solid_generator/test/golden/outputs/m5_10_query_with_one_signal_dep.g.dart`
- `packages/solid_generator/test/golden/inputs/m5_10_query_with_multi_signal_deps.dart` — query body reads TWO Signals; output synthesizes a Record-Computed.
- `packages/solid_generator/test/golden/outputs/m5_10_query_with_multi_signal_deps.g.dart`
- entries in `golden_helpers.dart` `goldenNames`.

**Files to modify:**

- `packages/solid_generator/lib/src/query_model.dart` — add `final List<String> trackedSignalNames;` field (populated from body analysis) and a derived `bool get needsSourceComputed => trackedSignalNames.length >= 2;`. Single-dep queries store the single name; the emitter passes it directly.
- `packages/solid_generator/lib/src/annotation_reader.dart` — `readSolidQueryMethod` extends body analysis to record which identifiers resolved to `SignalBase<T>` (this list already exists internally for the `.value` rewrite — surface it on the model).
- `packages/solid_generator/lib/src/signal_emitter.dart` — add `String? emitQuerySourceField(QueryModel q)` that returns `null` for `q.trackedSignalNames.length < 2` (no synthesized field needed) and emits `late final _<name>Source = Computed<(T1, T2, …)>(() => (<signal1>.value, <signal2>.value, …), name: '<name>_source');` for `length >= 2`. Extend `emitResourceField` to add `source: <signalName>,` when `length == 1` (direct pass) and `source: _<name>Source,` when `length >= 2`.
- `packages/solid_generator/lib/src/stateless_rewriter.dart`, `state_class_rewriter.dart`, `plain_class_rewriter.dart` — for each query with `length >= 2`, emit the source Computed field immediately before the Resource field; add the `_<name>Source` name to the dispose-name list (immediately before `_<name>` so reverse-disposal disposes the Resource first, then the source Computed). For `length == 1`, no extra field or dispose entry.

**Expected implementation change:** New `trackedSignalNames` field on `QueryModel`; new `emitQuerySourceField` emitter that returns null for ≤1-dep queries; per-rewriter tweaks to emit-and-dispose the source Computed only when synthesized. The Computed's type argument is a `Record` of the resolved Signal-inner-types of the tracked names (e.g., `(int, String?)` for two signals of types `int` and `String?`).

**Acceptance:** `dart test --name=m5_10` passes; both goldens analyze clean. Single-signal golden emits `source: <signalName>,` with NO synthesized field and NO extra dispose entry. Multi-signal golden emits `late final _<name>Source = Computed<(T1, T2)>(() => (signal1.value, signal2.value), …);` immediately before the Resource, and `source: _<name>Source,` on the Resource. Dispose order for multi: `_<name>.dispose()`, then `_<name>Source.dispose()`, then the underlying Signals (reverse declaration order). Single-dep dispose: `_<name>.dispose()` then the Signal directly (no source-Computed in between).

**Dependencies:** M5-01.

**Status:** TODO

---

### TODO M5-11 — Annotation parameters: `debounce:` and `useRefreshing:`

**Goal:** `@SolidQuery(debounce: Duration(seconds: 1))` propagates to the emitted Resource's `debounceDelay:` argument. `@SolidQuery(useRefreshing: false)` propagates to `useRefreshing: false` on the Resource (the upstream default `useRefreshing: true` is omitted to keep generated lines short). Both parameters are independent and may be combined.

**SPEC references:** Section 3.5 (`debounce:` and `useRefreshing:` parameter docs), Section 4.8 rule 7 (annotation parameters propagate).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m5_11_query_with_debounce.dart` — `@SolidQuery(debounce: Duration(milliseconds: 300))`.
- `packages/solid_generator/test/golden/outputs/m5_11_query_with_debounce.g.dart`
- `packages/solid_generator/test/golden/inputs/m5_11_query_with_use_refreshing_false.dart` — `@SolidQuery(useRefreshing: false)`.
- `packages/solid_generator/test/golden/outputs/m5_11_query_with_use_refreshing_false.g.dart`
- entries in `golden_helpers.dart` `goldenNames`.

**Files to modify:**

- `packages/solid_generator/lib/src/query_model.dart` — `debounce` and `useRefreshing` fields are wired (added in M5-01's stub model; M5-11 surfaces them in the emitted output).
- `packages/solid_generator/lib/src/annotation_reader.dart` — extract `debounce:` (parsing the `Duration(...)` constant expression) and `useRefreshing:` (boolean literal) from the annotation arguments.
- `packages/solid_generator/lib/src/signal_emitter.dart` — extend `emitResourceField` to include `debounceDelay: <const Duration(…)>,` when `debounce != null` and `useRefreshing: false,` when `useRefreshing == false` (omit when `useRefreshing == true` since that's the upstream default).

**Expected implementation change:** Three small surface changes: model fields, reader extraction, emitter argument injection. No changes to dispose / accessor / import paths.

**Acceptance:** `dart test --name=m5_11` passes; the `debounce` golden emits `debounceDelay: const Duration(milliseconds: 300),` in the Resource constructor; the `useRefreshing: false` golden emits `useRefreshing: false,`; a default `@SolidQuery()` (no params) emits neither argument.

**Dependencies:** M5-01.

**Status:** TODO

---
