# M2 — `@SolidState` on getters → `Computed`

**TODOS.md items:** M2-01, M2-01b, M2-02 → M2-04
**SPEC sections:** 3.1, 4.5, 4.6, 5.1, 7, 10
**Reviewer rubric:** `plans/features/reviewer-rubric.md`

## Purpose

M2 adds `@SolidState` on getters: a derived reactive value whose body references other reactive declarations. The getter becomes a `late final Computed<T>` whose body is wrapped in a function expression, with identifier rewrites applied per SPEC Section 5.1. Disposal order is already established by M1-01 via reverse declaration order; M2 exercises it.

A developer after M2 can:

1. Write `@SolidState() int get doubleCounter => counter * 2;` next to an existing `@SolidState() int counter = 0;`.
2. Read `doubleCounter` in `build()` and see `.value` appended + `SignalBuilder` wrapping.
3. See the `Computed` disposed BEFORE the `Signal` it depends on when the widget is torn down.
4. Get a clear build-time error if they write a Computed that reads no reactive state.

## TODO sequence

- **M2-01** — simple Computed with deps. Establishes the getter branch of the class visitor, the body rewrite, and the `late final Computed<T>(...)` shape. Expression-body form.
- **M2-01b** — block-body getter (Section 4.6). Wraps the original block verbatim in a function expression; reuses the Section 5.1 rewriter for identifiers inside.
- **M2-02** — zero-deps rejection. Validates that the generator emits the SPEC-specified error when a Computed has no reactive dependencies. The error message must match SPEC Section 4.5 exactly.
- **M2-03** — Computed read in `build()`. Confirms that `doubleCounter` is rewritten to `doubleCounter.value` and wrapped in `SignalBuilder` — the type-driven Section 5.1 rule already covers this, so M2-03 is a regression fence, not new logic.
- **M2-04** — explicit dispose-order golden. Validates reverse-declaration order emission in a class with both a Signal and a Computed.

## Cross-cutting concerns

- **Body rewriting reuses M1 machinery.** The Section 5.1 type-driven rewriter is already written by M1-05. M2's only new output is the `late final ... = Computed<T>(() => ..., name: '<n>')` wrapper + the dispose-order slot.
- **Block-body vs expression-body getters.** SPEC Section 4.6 shows the block case: `{ ... }` is wrapped in a closure preserved verbatim (with identifier rewrites). M2-01 covers expression body; M2-01b covers the block-body case explicitly.
- **No cross-class Computed in M1.** Per SPEC Section 4.5 (revised round 3): M1's rule is stated in terms of resolved type, so later `@SolidEnvironment` (M4+) adds cross-class deps without SPEC change. In M2 the only source of deps is same-class `@SolidState`.
- **Rejection path.** M2-02's error must be raised during the build, not at runtime. A `TransformationError` type should carry the SPEC-quoted message with the offending getter name substituted in.

## Exit criteria

- All M2-01 through M2-04 items marked DONE.
- `dart test packages/solid_generator/` passes.
- `dart analyze packages/solid_generator/test/golden/outputs/m2_*.g.dart` reports zero issues.
- M2-02's rejection test asserts the exact SPEC error message; reviewer cites Section 4.5.
- M2-04's golden `dispose()` body has `computed.dispose()` before `signal.dispose()` before `super.dispose()`.
- Reviewer rubric passes on the M2 PR.
