# M3 — Untracked reads + fine-grained `SignalBuilder` placement

**TODOS.md items:** M3-01 → M3-12 (M3-07 superseded by M3-12)
**SPEC sections:** 5.1, 5.2, 5.4, 5.5, 6.0, 6.2, 6.4, 6.5, 6.6, 7.1–7.5, 16 (#4, #6)
**Reviewer rubric:** `plans/features/reviewer-rubric.md`

## Purpose

M3 hardens the rewriter against the v1 bugs that SPEC Section 16 enumerates: untracked reads that should not wrap (#4), tracked reads that were missed (#6), double-appending `.value.value`, string interpolation regressions, and siblings that rebuild together when they should not. Every case is a focused regression test against a real v1 failure.

A developer after M3 can trust the generator in these scenarios:

- `Text(counter)` rebuilds only `Text`.
- `ValueKey(counter)` wraps the enclosing widget like any other tracked read; users opt out per-read via the `.untracked` extension (M3-12).
- `onPressed: () => counter++` never subscribes.
- `controller.value` (a `TextEditingController`) is left alone.
- `'$counter'` becomes `'${counter.value}'`.
- `untracked(() => counter)` reads once, no wrap.
- `Builder(builder: (ctx) => Text(counter))` wraps `Text` in `SignalBuilder`.
- A local shadowing a field is handled correctly.
- Two sibling reads of different signals do not interfere.

## TODO sequence

- **M3-01** — `Text(counter)` inside `build` (fix for issue #6). Regression fence; core logic is in M1-05.
- **M3-02** — `onPressed: () => counter++` (fix for issue #4). Regression fence; core logic is in M1-05.
- **M3-03** — `ValueKey(counter)` is tracked by default (drops the SPEC 6.3 auto-untracking enumeration that v1 carried). The opt-out story is M3-12's `.untracked` extension.
- **M3-05** — type-aware no-double-append. Validates Section 5.4. Includes a `TextEditingController.value` case.
- **M3-06** — string interpolation regression fence.
- **M3-07** — explicit `untracked(() => ...)` opt-out (Section 6.4). **Superseded by M3-12** (extension form replaces the function form).
- **M3-08** — Builder-style closures stay tracked (Section 6.6).
- **M3-09** — shadowing (Section 5.5). Depends on M3-05 + M3-08 because it exercises both rules simultaneously.
- **M3-10** — already-inside-SignalBuilder (Section 7.3). Hand-written `SignalBuilder` in source must not be double-wrapped.
- **M3-11** — nested tracked reads (Section 7.5). Outer + inner both tracked; only inner wraps.
- **M3-12** — `.untracked` extension replaces the `untracked()` function-call form (Section 6.4 rewrite). Single canonical opt-out marker for read tracking.
- **M3-04** — sibling isolation widget test (Section 7.4). Ships last because it validates the whole M3 pipeline against a real widget tree.

## Cross-cutting concerns

- **Untracked-context detector.** One AST visitor recognizes three contexts:
  1. user-interaction callbacks (Section 6.2 — enumerated parameter-name list).
  2. closures passed to the top-level `untracked<T>` function from `flutter_solidart` (Section 6.4). Slated for replacement by the `.untracked` extension in M3-12.
  3. writes (Section 6.0 — the assignment's LHS is always untracked; the RHS is a normal read per Section 5.3).
- **Builder closure non-rule.** SPEC Section 6.6 is the explicit non-rule: `builder:`, `itemBuilder:`, etc. are NOT in the Section 6.2 list. The visitor must NOT treat them as untracked. M3-08 is the regression test.
- **Sibling isolation.** M3-04 is a widget test, not a golden. Introduces a second `BuildTracker`-instrumented widget in the counter example; asserts both Text widgets each rebuild only when their respective signal changes.
- **Type-driven rule is the single source of truth for `.value`.** The cases in M3-05, M3-06, M3-09 all reduce to SPEC Section 5.1 — if the identifier's resolved static type is `SignalBase<T>` or subtype, rewrite; otherwise leave alone. No special-case code per scenario; the test matrix validates generality.

## Exit criteria

- All M3-01 through M3-11 items marked DONE.
- `dart test packages/solid_generator/` passes: every M3 golden + all prior goldens.
- `flutter test example/` passes: M3-04 `sibling_isolation_test.dart` + all prior widget tests.
- `dart analyze --fatal-infos` and `dart analyze packages/solid_generator/test/golden/outputs/` both zero.
- `dart format --set-exit-if-changed .` zero diff.
- End-to-end: sibling rebuild count in DevTools inspector is 0 while the signal being tapped rebuilds its own `Text` exactly once per tap.
- Reviewer rubric passes on the M3 PR.
- After M3 is green: SPEC Section 16 issue links (#4, #6) can be marked as resolved in the closing PR description.
