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

**Status:** TODO

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

**Status:** TODO

---

### TODO M0-03 — `solid_generator` skeleton + build.yaml

**Goal:** Empty builder wired into `build_runner` with the `source/ → lib/` mapping.

**SPEC references:** Section 2, Section 11.

**Files to create/modify:**

- `packages/solid_generator/pubspec.yaml` — deps on `analyzer`, `build`, `build_config`, `dart_style`, `solid_annotations` (path: `../solid_annotations`); dev_deps on `build_runner`, `build_test`, `test`.
- `packages/solid_generator/build.yaml` — `build_extensions: {'^source/{{}}.dart': ['lib/{{}}.dart']}`, `build_to: source`, `auto_apply: dependents`, explicit `sources: [source/**, lib/**, pubspec.*, $package$]`.
- `packages/solid_generator/lib/builder.dart` — `Builder solidBuilder(BuilderOptions opts)` factory that returns a no-op builder (reads input, writes it unchanged to the mapped output path).
- `packages/solid_generator/test/.gitkeep`.

**Acceptance:**

- `dart analyze packages/solid_generator` → zero issues.
- `dart test packages/solid_generator` (empty suite) passes.
- Running `dart run build_runner build` from `example/` (after M0-05) copies source files to lib verbatim.

**Dependencies:** M0-01, M0-02.

**Status:** TODO

---

### TODO M0-05 — `example/` hello-world shell

**Goal:** Minimal Flutter app with `source/counter.dart` (hand-written) and `lib/main.dart` (entry point). Used as both M0 smoke-test and M1-05 canonical golden.

**SPEC references:** Section 2, Section 11, Section 12.

**Files to create/modify:**

- `example/pubspec.yaml` — Flutter app deps on `solid_annotations` (path `../packages/solid_annotations`) and `flutter_solidart`; dev_deps on `solid_generator` (path `../packages/solid_generator`) and `build_runner`.
- `example/analysis_options.yaml` — `include: package:very_good_analysis/analysis_options.yaml`, lint suppressions: `must_be_immutable: ignore`, `always_put_required_named_parameters_first: ignore`, `invalid_annotation_target: ignore`.
- `example/source/counter.dart` — hello-world stateful widget with no annotations (plain `Text('hello')`). Replaced by M1-05 golden source.
- `example/lib/main.dart` — `void main() => runApp(MaterialApp(home: Counter()));` importing `counter.dart`. Hand-written; must survive `dart run build_runner build` because M0-03 is a no-op for files without annotations.

**Acceptance:**

- `dart pub get` in `example/` succeeds.
- `dart run build_runner build --delete-conflicting-outputs` in `example/` exits 0; `example/lib/counter.dart` is identical to `example/source/counter.dart`.
- `flutter run -d chrome` (or any device) boots and shows "hello".

**Dependencies:** M0-03.

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

---

### TODO M1-02 — Golden: late non-nullable field

**Goal:** `@SolidState() late String text;` becomes `late final text = Signal<String>('', name: 'text');`. Validates SPEC Section 4.2 default-value table + `late` preservation.

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

**Expected output content:**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Greeting extends StatefulWidget {
  const Greeting({super.key});

  @override
  State<Greeting> createState() => _GreetingState();
}

class _GreetingState extends State<Greeting> {
  late final text = Signal<String>('', name: 'text');

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**Expected implementation change:** Extend the field builder to look up default values from the Section 4.2 table when no initializer exists, and preserve the `late` keyword verbatim per SPEC Section 4.2.

**Acceptance:**

- `dart test --name=m1_02` passes.
- `dart analyze` on the golden output → zero issues.

**Dependencies:** M1-01.

**Status:** TODO

---

### TODO M1-02b — Rejection: `late` field with unknown-default type

**Goal:** A `late` non-nullable field whose declared type has no entry in the Section 4.2 defaults table is rejected with the SPEC's exact error string.

**SPEC references:** Section 4.2 (last bullet in the defaults table).

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_02b_late_unknown_type_rejected.dart`
- `packages/solid_generator/test/rejections/m1_02b_late_unknown_type_test.dart` — asserts the builder raises an error with the exact SPEC quote: `"field 'foo' of type 'MyType' has no initializer and no default is known; add '= MyType(...)' or declare 'MyType?'"` (with `foo` and `MyType` substituted).

**Expected input content:** A class with `@SolidState() late MyType foo;` where `MyType` is a user-defined class with no defaults-table entry.

**Expected implementation change:** The default-value resolver (introduced in M1-02) returns a `Result.err` when the declared type does not match any defaults-table entry. The pipeline propagates the error with `foo` and the type name substituted.

**Acceptance:** Rejection test passes; error message text matches the SPEC quote exactly (modulo the substituted identifier and type).

**Dependencies:** M1-02.

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

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
  Widget build(BuildContext context) => Scaffold(
    body: Center(child: Text('Counter is $counter')),
    floatingActionButton: FloatingActionButton(
      onPressed: () => counter++,
      child: const Icon(Icons.add),
    ),
  );
}
```

**Expected output content:**

```dart
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
  Widget build(BuildContext context) => Scaffold(
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
```

**Expected implementation change:** Integration of field builder (M1-01), compound-assignment rewrite (Section 5.3), interpolation rewrite (Section 5.2), untracked-callback rule (Section 6.2), SignalBuilder minimum-subtree placement (Section 7.2).

**Acceptance:**

- `dart test --name=m1_05` passes.
- Golden analyzes clean.
- Widget test `m1_05_widget` (TODO M1-10) renders, taps the FAB, and observes exactly one `Text` rebuild with `counter == 1`.

**Dependencies:** M1-01, M1-04 (for name handling wiring), and the visit-tree rewrite logic introduced here is reused by M3.

**Status:** TODO

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

**Expected implementation change:** Class-kind dispatch adds "plain class" branch (Section 8.3). Dispose synthesis uses reverse declaration order (Section 10) and omits `super.dispose()` when the supertype chain has no `dispose()` method.

**Acceptance:** `dart test --name=m1_06` passes; golden analyzes clean.

**Dependencies:** M1-01.

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

---

### TODO M1-09 — Idempotency: two-run byte equality

**Goal:** Running the generator twice on the same input produces byte-identical output.

**SPEC references:** None directly — this is a test of the Section 5.4 invariant ("once `counter.value` has been rewritten, the outer expression's type is `int` ... so the rule stops applying").

**Files to create:**

- `packages/solid_generator/test/integration/idempotency_test.dart` — runs each golden input through the builder twice and asserts the second output equals the first.

**Expected implementation change:** None (tests the invariant already produced by M1-01 through M1-08). If it fails, the generator has state or non-determinism that must be fixed.

**Acceptance:** Test passes for every golden currently listed.

**Dependencies:** M1-01 through M1-08.

**Status:** TODO

---

### TODO M1-10 — Widget test: FAB tap rebuilds only Text

**Goal:** With the M1-05 golden running inside `example/`, a FAB tap rebuilds only the `Text` widget; a sibling widget (e.g., an icon) does not rebuild.

**SPEC references:** Section 7 (SignalBuilder placement), Section 14 item 7.

**Files to create:**

- `example/test/counter_widget_test.dart` — uses `testWidgets` + a `BuildTracker` (test helper) to count rebuilds per widget. After the FAB tap: `Text` rebuild count == 1; sibling icon rebuild count == 0.

**Expected implementation change:** The `BuildTracker` helper may need to live in `example/test/helpers/build_tracker.dart` and wrap `Text` / `Container` in a tracking widget that increments a counter in its `build`.

**Acceptance:** `flutter test example/` passes; the test explicitly asserts sibling rebuild count is zero.

**Dependencies:** M1-05.

**Status:** TODO

---

### TODO M1-11 — Widget test: dispose spy on Navigator pop

**Goal:** When the page containing `@SolidState` signals is popped from `Navigator`, each signal's `dispose()` is invoked.

**SPEC references:** Section 10.

**Files to create:**

- `example/test/counter_dispose_test.dart` — wraps the `Signal<int>` in a `SpySignal` subclass that records `dispose()` calls. Pushes the `Counter` page, pops it, asserts the counter was disposed.

**Expected implementation change:** A `SpySignal<T>` helper in `example/test/helpers/spy_signal.dart`; the generated `_CounterState.dispose()` calls `counter.dispose()` and the spy records it.

**Acceptance:** Test passes; spy records exactly one dispose call per signal.

**Dependencies:** M1-01, M1-10.

**Status:** TODO

---

### TODO M1-12 — Golden: class without annotations passes through

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

**Expected implementation change:** The top-level pipeline scans the parsed file for any `@Solid*` annotation before invoking the rewriter. If none, write input bytes to the output path unchanged.

**Acceptance:** `dart test --name=m1_12` passes; output bytes equal input bytes.

**Dependencies:** M1-01.

**Status:** TODO

---

### TODO M1-13 — Golden: `const` on public widget constructor

**Goal:** When the public `StatefulWidget` constructor (emitted per Section 8.1) has all-`const`-compatible fields and defaults, the generator emits `const` on that constructor. When a field's default is not `const`-compatible, `const` is omitted.

**SPEC references:** Section 8.1, Section 14 item 7.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m1_13_const_ctor_eligible.dart` — a class whose non-`@SolidState` fields are all `final` and all default values are `const`-compatible.
- `packages/solid_generator/test/golden/outputs/m1_13_const_ctor_eligible.g.dart` — public ctor is `const Counter({super.key})`.
- `packages/solid_generator/test/golden/inputs/m1_13_const_ctor_ineligible.dart` — a class with a non-`const` default (e.g., `final Stopwatch watch = Stopwatch();`).
- `packages/solid_generator/test/golden/outputs/m1_13_const_ctor_ineligible.g.dart` — public ctor is `Counter({super.key})` (no `const`).
- entries in `golden_test.dart` for both.

**Expected implementation change:** When emitting the public `StatefulWidget` constructor, walk the original class's fields; if every non-`@SolidState` field is `final` and every default-value expression evaluates at compile time (type system judgment), emit `const`. Otherwise omit.

**Acceptance:** Both goldens pass; eligible ctor has `const`, ineligible does not.

**Dependencies:** M1-01.

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

---

### TODO M3-03 — Golden: ValueKey(counter) is untracked

**Goal:** A read inside `ValueKey(counter)` gets `.value` but does NOT wrap the enclosing widget in `SignalBuilder`.

**SPEC references:** Section 6.3.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_03_value_key_untracked.dart`
- `packages/solid_generator/test/golden/outputs/m3_03_value_key_untracked.g.dart`
- entry in `golden_test.dart`

**Expected implementation change:** The untracked-context detector adds Key constructor names (Section 6.3) to its enumerated list. Reads inside these `InstanceCreationExpression`s get `.value` but do not trigger wrapping.

**Acceptance:** `dart test --name=m3_03` passes; output `Container(key: ValueKey(counter.value), child: ...)` is NOT wrapped.

**Dependencies:** M1-05.

**Status:** TODO

---

### TODO M3-04 — Widget test: sibling isolation

**Goal:** Two sibling widgets each reading different signals. Mutating signal A rebuilds only widget A; widget B's rebuild count stays at zero.

**SPEC references:** Section 7.4 (siblings do not share wrappers).

**Files to create:**

- `example/test/sibling_isolation_test.dart` — two `@SolidState` fields, two sibling `Text` widgets each reading one field. Increment A, assert A rebuilt and B did not.

**Expected implementation change:** Validates that M1-05's minimum-subtree wrap rule (Section 7.2) produces sibling isolation.

**Acceptance:** Test passes; rebuild count for B is zero after mutating A.

**Dependencies:** M1-10.

**Status:** TODO

---

### TODO M3-05 — Type-aware no-double-append

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

**Status:** TODO

---

### TODO M3-06 — Golden: string interpolation

**Goal:** `'$counter'` becomes `'${counter.value}'`.

**SPEC references:** Section 5.2.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_06_string_interpolation_bare.dart`
- `packages/solid_generator/test/golden/outputs/m3_06_string_interpolation_bare.g.dart`
- entry in `golden_test.dart`

**Expected implementation change:** Already produced by M1-05; this is the focused regression case. Verify that already-wrapped `${counter.value}` stays untouched (double-rewrite prevention via Section 5.4 type rule).

**Acceptance:** `dart test --name=m3_06` passes; golden analyzes clean.

**Dependencies:** M1-05.

**Status:** TODO

---

### TODO M3-07 — Golden: explicit `untracked(() => ...)` opt-out

**Goal:** `Text('snapshot: ${untracked(() => counter)}')` keeps `.value` on `counter` (per Section 5.1) but does NOT wrap the enclosing `Text` in `SignalBuilder`.

**SPEC references:** Section 6.4.

**Files to create:**

- `packages/solid_generator/test/golden/inputs/m3_07_untracked_opt_out.dart`
- `packages/solid_generator/test/golden/outputs/m3_07_untracked_opt_out.g.dart`
- entry in `golden_test.dart`

**Expected implementation change:** The untracked-context detector recognizes calls to the top-level `untracked` function from `package:flutter_solidart/flutter_solidart.dart` by resolved identifier (not name alone). Reads inside the closure passed to `untracked` are untracked.

**Acceptance:** `dart test --name=m3_07` passes; the golden output does NOT wrap the enclosing `Text` in `SignalBuilder`.

**Dependencies:** M1-05.

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO

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

**Status:** TODO
