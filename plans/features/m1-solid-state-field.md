# M1 — `@SolidState` on fields → `Signal`

**TODOS.md items:** M1-01 → M1-13
**SPEC sections:** 3.1, 4.1–4.4, 5.1–5.5, 6.0, 6.2, 7, 8.1–8.4, 9, 10, 14 items 4 and 7, 16 (#3, #4, #6, #8)
**Reviewer rubric:** `plans/features/reviewer-rubric.md`

## Purpose

M1 is the first real implementation milestone: annotate a field with `@SolidState()`, get a reactive `Signal<T>` on a State class, with correct `.value` rewriting in `build()`, correct `SignalBuilder` placement around tracked reads, correct dispose ordering, and correct imports. Zero getters (that's M2); zero nuance beyond the minimal-subtree wrap rule for the canonical counter (finer granularity + untracked contexts are M3).

A developer after M1 can:

1. Write `@SolidState() int counter = 0;` on a `StatelessWidget`, `StatefulWidget`'s `State`, or a plain class.
2. Read `counter` in `build()` as if it were an `int` — the generator adds `.value` and wraps the subtree in `SignalBuilder`.
3. Write `counter++` in `onPressed` — the generator adds `.value` without wrapping the button.
4. Hot-reload (via `dashmon` or manual `r`) between edits.
5. Pop the page and see signals disposed.

## TODO sequence

### Stage A — field → Signal emission

- **M1-01** — int field with initializer (canonical case; establishes class split + dispose + imports).
- **M1-02** — `late` non-nullable field (default-value table + `late` preservation).
- **M1-03** — nullable field (null default, no `late`).
- **M1-04** — custom `name:` parameter (annotation arg plumbing).

### Stage B — class-kind dispatch

- **M1-06** — plain class (Section 8.3; synthesized `dispose()` without `super.dispose()`).
- **M1-07** — existing `State<X>` in-place transformation + lifecycle preservation + existing-dispose merge (Section 8.2 + Section 14 item 4; fix for issue #3).
- **M1-12** — passthrough for classes with zero `@Solid*` annotations (Section 8.4).
- **M1-13** — `const` on the public widget constructor when defaults are `const`-compatible (Section 14 item 7).

### Stage C — end-to-end counter

- **M1-05** — blog-post canonical counter. Integrates field emission with:
  - compound-assignment rewrite (Section 5.3)
  - interpolation rewrite (Section 5.2)
  - onPressed-callback untracked rule (Section 6.2)
  - SignalBuilder minimum-subtree placement (Section 7.2)

### Stage D — imports + idempotency

- **M1-08** — import rewrite (Section 9; fix for issue #8).
- **M1-09** — two-run byte equality (regression fence against accidental state).

### Stage E — widget tests (ship as part of M1, not deferred)

- **M1-10** — FAB tap rebuilds only `Text`, sibling does not.
- **M1-11** — Navigator pop disposes signals via `SpySignal`.

### Stage F — rejection paths

- **M1-14** — reject every invalid `@SolidState` target enumerated in Section 3.1 (`final`, `const`, `static`, top-level, method, setter) with a clear per-case error message.
- **M1-15** — reject `@SolidEffect` / `@SolidQuery` / `@SolidEnvironment` at build time with the Section 3.2 error ("not yet implemented; scheduled for a later v2 milestone").

Stages are sequential inside M1 (A → B → C → D → E), but items within a stage can run in parallel if two agents share a worktree.

## Cross-cutting concerns

- **AST rewriter uses analyzer, not regex.** Every identifier rewrite (Section 5.1) is gated on resolved static type being `SignalBase<T>` or a subtype. Reviewer rubric item 3 blocks any regex-based transformation.
- **Dispose ordering.** Reverse declaration order — `Computed` disposes before `Signal` (Section 10). M1 has no `Computed` yet, but M2 depends on this invariant, so emit even single-field dispose bodies with the ordering rule encoded (easier to extend than retrofit).
- **Class-kind dispatch.** Implement as a visitor that walks the class declaration and returns one of four enum values: `statelessWidget`, `statefulWidget`, `stateClass`, `plainClass`. SPEC Section 8 is the truth table.
- **Test helpers.** `BuildTracker` lives in `example/test/helpers/` and is shared between M1-10 and M3-04. M1-11 does not need a helper: it observes dispose via `SignalBase<T>.onDispose(VoidCallback)` (the public contract exported by `flutter_solidart`), so a `SpySignal` subclass is unnecessary and the same hook composes for M2-04 (`Computed` dispose-order golden).
- **`dart fix --apply` is the import pruner.** Per SPEC Section 9, the generator adds `flutter_solidart` but does NOT remove `solid_annotations`. The expectation is that users run `dart fix --apply` (or their IDE does). M1-08 asserts the raw generator output; the example app's CI (when it lands post-M1) will assert the post-`dart fix` state.
- **Goldens are canonical.** If SPEC and a golden output disagree, SPEC wins and the golden is regenerated. Never modify SPEC to match a bug.

## Exit criteria

- All M1-01 through M1-15 items marked DONE.
- `dart test packages/solid_generator/` passes: every golden + `idempotency_test.dart`.
- `flutter test example/` passes: `counter_widget_test.dart` (M1-10) + `counter_dispose_test.dart` (M1-11).
- `dart analyze --fatal-infos` across all packages reports zero issues.
- `dart analyze packages/solid_generator/test/golden/outputs/` reports zero issues.
- `dart format --set-exit-if-changed .` reports zero diff.
- End-to-end smoke: run `example/` in a simulator, tap FAB, `Text` updates, sibling Container rebuild count stays at 0 (verify via Flutter DevTools inspector).
- Reviewer rubric passes on every milestone PR.
