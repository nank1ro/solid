# M4 — `@SolidEffect` on methods → `Effect`

**TODOS.md items:** M4-01 → M4-08
**SPEC sections:** 3.4, 4.7, 5.1, 5.2, 5.4, 5.5, 6.0, 6.2, 6.4, 9, 10
**Reviewer rubric:** `plans/features/reviewer-rubric.md`

## Purpose

M4 adds `@SolidEffect` on methods: a side-effecting function whose body reads one or more reactive declarations and re-runs whenever those declarations change. The method becomes a `late final Effect(() { … }, name: '<n>')` field (zero-param callback per the upstream `flutter_solidart` API), with identifier rewrites applied per SPEC Section 5.1. Disposal joins the existing reverse-declaration order. This is the smallest infrastructural delta of the three reserved annotations: the body-rewrite pipeline and the `MethodDeclaration` collection path were both made future-proof in M2.

A developer after M4 can:

1. Write `@SolidEffect() void logCounter() { print('Counter changed: $counter'); }` next to an existing `@SolidState() int counter = 0;`.
2. See the Effect re-run automatically when `counter` changes (no manual subscription, no widget rebuild).
3. See the Effect disposed BEFORE the Signal it depends on when the widget is torn down.
4. Get a clear build-time error if they write an Effect that reads no reactive state, or annotate an invalid target (parameterized method, non-void return, static method, getter, setter, top-level function, field).

## TODO sequence

- **M4-01** — Golden: simple `@SolidEffect` method with one Signal dep on `StatelessWidget`. Mirror of M2-01 for getters. Establishes the `EffectModel` model file, `readSolidEffectMethod` reader, `emitEffectField` emitter, the `MethodDeclaration` non-getter discrimination in `_collectAnnotatedClasses`, and the `late final ... = Effect(() { ...; }, name: '<n>')` shape (zero-param callback). Expression-body form first.
- **M4-02** — Golden: `@SolidEffect` co-exists with `@SolidState` field + `@SolidState` getter on the same class. Validates that the unified dispose ordering across all three lowered shapes (Signal/Computed/Effect) is correct under the existing reverse-declaration rule.
- **M4-03** — Golden: `@SolidEffect` block-body with multi-statement and shadowing. Validates that Sections 5.1 and 5.5 rules apply inside Effect bodies same as Computed bodies (parallel to M2-01b).
- **M4-04** — Rejection: invalid `@SolidEffect` targets. Parametric test mirroring M1-14: getter, setter, static method, top-level function, parameterized method, non-void return, abstract method.
- **M4-05** — Rejection: zero reactive deps in Effect body. Mirror of M2-02. Error: `"effect '<name>' has no reactive dependencies"`.
- **M4-06** — Migration: remove `@SolidEffect` from `_reservedAnnotations` (`reserved_annotation_validator.dart:9–13`) and migrate the `m1_15_effect` rejection-test case to a golden. Trivial flip-the-bit PR — depends on M4-01 through M4-05 being green.
- **M4-07** — Widget test: tap FAB three times, assert the Effect body fires three times. Records emitted values into a list-typed Signal that the test reads. Parallel to M1-10 / M3-04.
- **M4-08** — Golden: `@SolidEffect` on existing `State<X>` class (lifecycle co-existence with hand-written `initState` / `dispose`). Mirror of M1-07.

## Cross-cutting concerns

- **Body-rewrite pipeline reuse.** `value_rewriter.dart`'s `collectValueEdits` was generalized in M2-01 to take any `AstNode`. M4-01 calls it with the Effect's body block, exactly mirroring M2-01b's block-body Computed handling. No rewriter changes needed.
- **`MethodDeclaration` getter/non-getter discriminator.** The M2-01 path keys on `decl.isGetter` (true → Computed). The M4 path keys on `!decl.isGetter && !decl.isSetter && carriesSolidEffect` (→ Effect). Both branches share the `_collectAnnotatedClasses` member walk in `builder.dart`.
- **Imports already future-proofed.** SPEC Section 9 (line ~596) already lists `Effect` on the canonical `flutter_solidart` import-add list as future-proofing — the M1-08 rule fires unchanged.
- **Disposal in source-declaration order, reversed in `dispose()`.** Effects are appended to the unified ordered name list in `signal_emitter.dart:emitDispose`. Reverse-declaration order naturally puts the Effect (declared after the Signals/Computeds it reads) ahead of the Signal/Computed in the dispose body — the same algorithm Computed already exercises.
- **Cross-cutting reactive rules apply uniformly.** Sections 5.1, 5.2, 5.4, 5.5, 6.0, 6.2, 6.4 all hold inside Effect bodies with no amendment. Effect bodies are reactive code in the same sense as `Computed` bodies and `build` bodies.
- **Untracked-callback context inside Effect bodies.** An Effect body that itself constructs widgets with `onPressed: () => …` callbacks still applies Section 6.2 untracked-context detection inside those callbacks. Effect-body reads are tracked by default (the Effect IS the subscription); the Section 6.4 `.untracked` extension still works as a per-read opt-out.

## Exit criteria

- All M4-01 through M4-08 items marked DONE.
- `dart test packages/solid_generator/` passes: every M4 golden + every prior golden + every prior rejection test.
- `flutter test example/` passes: M4-07 widget test + every prior widget test.
- `dart analyze --fatal-infos` and `dart analyze packages/solid_generator/test/golden/outputs/` both report zero issues.
- `dart format --set-exit-if-changed .` reports zero diff.
- `m1_15_effect` rejection case removed from `packages/solid_generator/test/rejections/m1_15_non_m1_annotations_test.dart` (M4-06).
- `_reservedAnnotations` map in `reserved_annotation_validator.dart` no longer lists `'SolidEffect'` (M4-06).
- Reviewer rubric passes on each M4 PR.
- After M4 is green: `@SolidEffect` is the second fully-shipped annotation; SPEC Section 13 lists only `@SolidQuery` and `@SolidEnvironment` as deferred.
