# M2-01 — `@SolidState` getter → `Computed`

## Context

PR #32 (M1-15: reject reserved annotations at build time) just merged on `main` (commit `8a0e253`). Per the workflow in `TODOS.md` ("pick the lowest-numbered item whose Status is TODO and whose Dependencies are all DONE") and the established one-TODO-per-PR cadence (commits #18 → #32 each map to a single milestone item), the next item is **M2-01 — Golden: simple Computed with deps** (`TODOS.md` lines 847-882).

M2 introduces the second `@SolidState` shape: the annotation on a class **getter** lowers to a `Computed<T>` whose body wraps the original getter's expression with the Section 5.1 reactive-read rewrite already used inside `build()`. M1-14 / M1-15 already validate that an instance getter is a valid annotation target (`target_validator.dart` line 65 explicitly comments "M2 emits Computed"), so the user-facing validation surface is already in place — the missing piece is the lowering itself.

After M2-01, a developer writing

```dart
@SolidState() int counter = 0;
@SolidState() int get doubleCounter => counter * 2;
```

on a `StatelessWidget` gets a `late final doubleCounter = Computed<int>(() => counter.value * 2, name: 'doubleCounter');` field on the synthesized State class plus a `dispose()` body that disposes `doubleCounter` before `counter` (reverse declaration order, SPEC §10).

**Scope (per user direction):** This PR delivers M2-01 only — StatelessWidget split with getter handling. `rewriteStateClass` and `rewritePlainClass` are extended only to **reject** `@SolidState` getters with a clear `CodeGenerationError`; full support lands in later TODOs as needed. M2-01b (block-body getter), M2-02 (zero-deps rejection), M2-03 (Computed read in `build`), and M2-04 (explicit dispose-order golden) are separate PRs.

## Approach

### 1. New model type: `GetterModel`

Add `packages/solid_generator/lib/src/getter_model.dart` (~30 lines, parallel to existing `field_model.dart`):

```dart
@immutable
class GetterModel {
  const GetterModel({
    required this.getterName,
    required this.typeText,
    required this.bodyExpressionText,
    required this.annotationName,
  });
  final String getterName;       // 'doubleCounter'
  final String typeText;          // 'int'
  final String bodyExpressionText; // 'counter * 2' — already with .value rewrites applied
  final String? annotationName;
}
```

`bodyExpressionText` is stored already-rewritten (Section 5.1 applied) so the emitter is purely string-template.

### 2. Reading getter annotations

Extend `packages/solid_generator/lib/src/annotation_reader.dart`:

- Add `GetterModel? readSolidStateGetter(MethodDeclaration decl, Set<String> reactiveFieldNames, String source)`.
- Reuse `findSolidStateAnnotation(decl.metadata)` (already exposed for the validator).
- Reuse `_extractNameArgument(annotation)` — refactor it from `_extractNameArgument` (currently private, line 60) to a top-level `extractNameArgument` helper so both readers share it.
- For an expression-body getter (`get x => <expr>;`), the body expression substring is `source.substring(expr.offset, expr.end)`. Apply the Section 5.1 rewriter to that range using a thin reuse of `value_rewriter.dart` (see step 4).
- For a block-body getter, throw `CodeGenerationError('@SolidState block-body getter not yet supported (M2-01b)', ...)`. M2-01 ships expression-body only.

### 3. Collecting getters

Extend `_collectAnnotatedClasses` in `packages/solid_generator/lib/builder.dart` (lines 107-123) to walk `MethodDeclaration` members alongside `FieldDeclaration`s. Extend `_AnnotatedClass`:

```dart
class _AnnotatedClass {
  _AnnotatedClass(this.decl, this.fields, this.getters);
  final ClassDeclaration decl;
  final List<FieldModel> fields;
  final List<GetterModel> getters;
}
```

Iterate members in source order, populating both lists. Reactive-name set passed to the body rewriter is the union of `fields.map((f) => f.fieldName)` plus all `getters.map((g) => g.getterName)` collected so far (a getter can read another getter declared earlier).

The pass-through guard (`builder.dart` line 81) becomes `annotatedClasses.every((c) => c.fields.isEmpty && c.getters.isEmpty)`.

### 4. Section 5.1 body rewrite for getter expressions

`packages/solid_generator/lib/src/value_rewriter.dart`'s `collectValueEdits` currently takes `MethodDeclaration buildMethod` (line 77) but its body just calls `buildMethod.accept(visitor)`. Generalise the entry to `AstNode node` (rename the parameter; the function shape doesn't change). Two callers update:

- `build_rewriter.dart` line 58 — passes the build method (no behaviour change).
- New caller inside `annotation_reader.dart` `readSolidStateGetter` — passes the getter's expression-body `Expression` node and the same `reactiveFields` set, then applies edits to `source.substring(expr.offset, expr.end)` to produce `bodyExpressionText`.

The visitor's untracked-context tracking (`_untrackedDepth`, `Key`-family, `untracked()` calls) and shadowing logic apply uniformly inside getter bodies — no code changes needed.

`trackedReadOffsets` from the getter's body are **discarded**; SignalBuilder placement is a `build()`-method concern, not a `Computed` body concern (the `Computed` itself subscribes via the runtime).

### 5. Computed emitter

Add `emitComputedField(GetterModel g)` to `packages/solid_generator/lib/src/signal_emitter.dart`:

```dart
String emitComputedField(GetterModel g) {
  final debugName = g.annotationName ?? g.getterName;
  return '  late final ${g.getterName} = '
      "Computed<${g.typeText}>(() => ${g.bodyExpressionText}, name: '$debugName');";
}
```

Always `late final` per SPEC §4.5: "the resulting Computed field is always declared `late final`".

### 6. Generalised dispose synthesis

`emitDispose(List<FieldModel> fields, {required bool inheritsDispose})` (`signal_emitter.dart` line 44) currently iterates `fields.reversed`. Replace the parameter with a unified ordered list of disposable names:

```dart
String emitDispose(
  List<String> disposeNamesInDeclarationOrder, {
  required bool inheritsDispose,
}) {
  // ... iterates `.reversed`
}
```

Callers compute the unified list themselves by interleaving fields and getters in source-declaration order. For `rewriteStatelessWidget`, the new helper `_orderedDisposeNames(fields, getters, classDecl)` reads each `ClassMember`'s offset (we already have the AST) and produces the names in source order. Reverse-declaration order then naturally puts the Computed (declared after the Signal it reads) ahead of the Signal in the dispose body.

### 7. Stateless-widget rewriter (the only one that fully supports getters in this PR)

`packages/solid_generator/lib/src/stateless_rewriter.dart`:

- New parameter on `rewriteStatelessWidget`: `List<GetterModel> solidGetters`.
- `_splitMembers` (line 68) drops annotated getters from the `fields` bucket (they aren't fields anyway — they're `MethodDeclaration`s). Only the `build` method goes to `buildMethod`. Annotated-getter `MethodDeclaration`s are not in any of the three buckets the rewriter cares about (we already have their `GetterModel`s) — but a non-annotated method we don't currently capture would be silently dropped. **Add a fourth bucket** `otherMethods` for completeness; M2-01's golden has none, so it's just defensive — a follow-up TODO can flesh out.
  
  *Decision for this PR:* keep `_splitMembers` returning only `(ctors, fields, buildMethod)` and verify the M1 cohort goldens still pass; non-annotated, non-`build` methods on a `StatelessWidget` were already dropped and are out of scope here.

- `_emitStateClass` (line 188) interleaves Signal fields and Computed fields in source order. Use the `ClassMember` offset of each backing declaration. Specifically:
  - Build a list of `(offset, emittedLine)` from `fields.map((f) => (originalFieldOffset, emitSignalField(f)))` and `getters.map((g) => (originalGetterOffset, emitComputedField(g)))`.
  - Sort by `offset`.
  - Join with `\n`.
- `dispose` is computed by `emitDispose(_orderedDisposeNames(fields, getters, classDecl), inheritsDispose: true)`.
- `solidartNames` returns `{'Signal', 'Computed', 'SignalBuilder'}` whenever `getters.isNotEmpty`; otherwise unchanged. (`Computed` is already in the canonical `solidartNames` set in `import_rewriter.dart` line 17, so the import-add rule fires correctly.)

### 8. Other rewriters: explicit "not yet supported"

- `rewritePlainClass` (`plain_class_rewriter.dart`): add a guard at the top — if any annotated getter exists for this class, throw `CodeGenerationError('plain class with @SolidState getter is not yet supported (will land in a later M2 TODO)', null, className)`. This keeps `target_validator` happy (instance getter is a valid target) without silently dropping.
- `rewriteStateClass` (`state_class_rewriter.dart`): same guard.

The dispatcher `_rewriteClass` in `builder.dart` (line 160) passes `getters` through to all three; the two non-stateless rewriters reject early. M1's existing goldens (which have no getters) round-trip unchanged.

### 9. Golden test wiring

Append to `goldenNames` in `packages/solid_generator/test/integration/golden_helpers.dart` (line 18):

```dart
'm2_01_simple_computed_with_deps',
```

The body of `golden_test.dart` does not change.

### 10. Golden fixtures

**`packages/solid_generator/test/golden/inputs/m2_01_simple_computed_with_deps.dart`** — `StatelessWidget` mirroring the M1-01 shape, with one Signal + one expression-body Computed getter:

```dart
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidState()
  int counter = 0;

  @SolidState()
  int get doubleCounter => counter * 2;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

**`packages/solid_generator/test/golden/outputs/m2_01_simple_computed_with_deps.g.dart`** — generated by `UPDATE_GOLDENS=1 dart test`, then hand-verified to match SPEC §4.5:

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
  late final doubleCounter = Computed<int>(
    () => counter.value * 2,
    name: 'doubleCounter',
  );

  @override
  void dispose() {
    doubleCounter.dispose();
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
```

Note: `dart_style` may break the long `Computed<int>(...)` line across multiple lines; the formatter pass in `_renderOutput` (`builder.dart` line 156) is the source of truth. The committed golden reflects the formatter's output verbatim.

### 11. Mark TODO done

Edit `TODOS.md` line 881 (the M2-01 entry's `Status`) from `TODO` to `DONE` in the same PR.

## Critical files

- `packages/solid_generator/lib/builder.dart` — extend `_collectAnnotatedClasses` and `_AnnotatedClass` to carry `getters` (lines 98-123); pass `getters` through `_rewriteClass` (line 160).
- `packages/solid_generator/lib/src/annotation_reader.dart` — add `readSolidStateGetter` and refactor `_extractNameArgument` to a shared top-level helper (lines 51-69).
- `packages/solid_generator/lib/src/getter_model.dart` — **new file**, parallel to `field_model.dart`.
- `packages/solid_generator/lib/src/signal_emitter.dart` — add `emitComputedField`; generalise `emitDispose` to take a unified ordered name list (lines 22-61).
- `packages/solid_generator/lib/src/value_rewriter.dart` — generalise `collectValueEdits` parameter from `MethodDeclaration buildMethod` to `AstNode node` (line 77). Body unchanged.
- `packages/solid_generator/lib/src/stateless_rewriter.dart` — accept `solidGetters`; interleave Signal + Computed fields in source order; pass merged disposable-name list to `emitDispose` (lines 14-56, 188-207).
- `packages/solid_generator/lib/src/state_class_rewriter.dart` — guard: reject `@SolidState` getters with `CodeGenerationError` until a future TODO.
- `packages/solid_generator/lib/src/plain_class_rewriter.dart` — same guard.
- `packages/solid_generator/lib/src/build_rewriter.dart` — call site for `collectValueEdits` updates the parameter name only (line 58).
- `packages/solid_generator/test/integration/golden_helpers.dart` — append `'m2_01_simple_computed_with_deps'` to `goldenNames` (line 28).
- `packages/solid_generator/test/golden/inputs/m2_01_simple_computed_with_deps.dart` — **new fixture**.
- `packages/solid_generator/test/golden/outputs/m2_01_simple_computed_with_deps.g.dart` — **new fixture** (generated, hand-verified).
- `TODOS.md` — flip M2-01 `Status: TODO` → `Status: DONE` at line 881.

## Verification

End-to-end run from the workspace root:

1. `dart pub get` (workspace).
2. From `packages/solid_generator/`:
   - `dart format --set-exit-if-changed lib test` — zero diff.
   - `dart analyze --fatal-infos lib test` — zero issues.
   - `UPDATE_GOLDENS=1 dart test --name=m2_01_simple_computed_with_deps` — regenerates the output fixture; commit only after manual diff against the SPEC §4.5 expected shape.
   - `dart test --name=m2_01_simple_computed_with_deps` — golden equality passes.
   - `dart test --name=golden` — every M1 golden still passes (regression check on the rewrite path).
   - `dart test test/rejections/` — both M1-14 and M1-15 rejection suites still pass.
   - `dart test test/integration/idempotency_test.dart` — two-run byte equality holds with the new fixture (the M1-09 invariant).
3. `dart analyze packages/solid_generator/test/golden/outputs/m2_01_simple_computed_with_deps.g.dart` — zero issues (rubric check #6).
4. From `example/`: `dart run build_runner build --delete-conflicting-outputs` exits 0 and `dart analyze` reports zero issues — confirms the change does not regress the consumer-app build path.

Reviewer rubric (`plans/features/reviewer-rubric.md`): paired golden committed, no regex, no `dynamic` casts, no file > 400 lines, no function > 50 lines, output cited against SPEC §4.5 + §5.1 + §10.
