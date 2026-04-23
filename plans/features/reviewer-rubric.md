# Reviewer Rubric (Solid v2)

Applied to every implementation diff before marking a `TODOS.md` item DONE. All 8 must pass; a single failure blocks approval.

## 8 checks

1. **Exact input → exact output.** Every public function has a test asserting a specific input produces a specific output. No `isNotEmpty`, `isTrue`, or smoke-only assertions.
2. **Paired golden files committed.** For every generator TODO, both `packages/solid_generator/test/golden/inputs/<name>.dart` and `packages/solid_generator/test/golden/outputs/<name>.g.dart` exist and are referenced from `packages/solid_generator/test/integration/golden_test.dart`.
3. **No regex for code transformation.** All rewrites go through `package:analyzer` AST APIs. Regex is acceptable only for operational concerns (e.g., config parsing, error message assertions).
4. **No `dynamic` casts.** Exception: analyzer APIs that genuinely return `dynamic` — preserved but narrowed as early as possible.
5. **Toolchain green.** `dart test` passes locally. `dart analyze --fatal-infos` reports zero issues. `dart format --set-exit-if-changed .` reports zero diff.
6. **Generated code is valid Dart.** `dart analyze packages/solid_generator/test/golden/outputs/` reports zero issues on every generated golden.
7. **SPEC fidelity.** Output matches `SPEC.md` behavior for the relevant scenario. Reviewer cites the section number that justifies the behavior; if SPEC is silent or ambiguous, the reviewer blocks until SPEC is amended.
8. **Discipline.** No debug prints. No file > 400 lines. No function > 50 lines. No new abstractions introduced beyond what the TODO requires.

## Reviewer agent loop

```
round 1: implementer writes test + impl + /simplify pass → reviewer runs rubric
round 2: implementer addresses CHANGES → reviewer re-runs rubric
round 3: last chance — if reviewer still returns CHANGES, escalate to user
```

Reviewer verdict format:

```
VERDICT: APPROVED
```

OR

```
VERDICT: CHANGES

1. [blocker] ...
2. [nit] ...
```

Nits may be deferred with user approval; blockers may not.
