# M6 — `@SolidEnvironment` on fields → `Provider`-backed DI

**TODOS.md items:** M6-01 → M6-10
**SPEC sections:** 3.6, 4.9, 5.1 (full-chain amendment), 8.1, 8.2, 8.3 (rejection), 9, 10, 14 items 4 & 5
**Reviewer rubric:** `plans/features/reviewer-rubric.md`

## Purpose

M6 adds `@SolidEnvironment` on fields: a SwiftUI-style dependency-injection annotation that reads its value once, on host-widget mount, from the nearest ancestor `Provider<T>` in the widget tree. The user-facing surface mirrors SwiftUI's `@Environment` property wrapper exactly: type-keyed lookup, invisible call sites (no `.read(context)` boilerplate the user must write), transparent reactivity (the injected type's own `@SolidState` fields reach the consumer's `build` via the existing fine-grained Signal subscription).

The runtime DI plumbing is `package:provider`'s `Provider<T>` directly — Solid does NOT ship a `SolidProvider` wrapper. `solid_annotations` adds three small surfaces: (a) the `@SolidEnvironment()` annotation class (no parameters), (b) the `Disposable` marker interface, (c) the `.environment<T>()` extension on `Widget` that wraps in `Provider<T>` at runtime with a default `dispose:` callback that auto-cleans Solid-lowered types via the marker. No `context.watch<T>()` codegen ever — `Provider` is used purely as DI plumbing; reactivity stays in Solid's own primitives.

The lowering for `@SolidEnvironment late T name;` is one line: `late final name = context.read<T>();` on the synthesized State (or in place on an existing `State<X>`). No `initState()` materialization splice — env fields are lazy and naturally trigger on first read in `build` or any other reactive body, unlike `@SolidEffect` (no consumer → must be force-materialized). The host class never disposes the injected instance — the providing `Provider<T>`'s `dispose:` callback owns that.

The §5.1 type-driven identifier rewrite, deferred since M1, finally lands here in full-chain form: `a.b.c.d` chains where any prefix resolves to `SignalBase<T>` get `.value` appended at every such position. This handles cross-class reactive reads (`counter.value` where `counter` is `@SolidEnvironment late Counter` and `Counter.value` is `@SolidState`) and lets the consumer's source code stay SwiftUI-shaped.

A developer after M6 can:

1. Annotate a `late <T> field;` (or `late final <T> field;`) with `@SolidEnvironment()` on a `StatelessWidget` or existing `State<X>` — the field is auto-bound to the nearest ancestor `Provider<T>`.
2. Provide an instance via `child.environment((_) => Counter())` for the SwiftUI-flavored low-code path with auto-dispose for Solid types, OR via `Provider<Counter>(create: ..., dispose: ..., child: ...)` from `package:provider` directly.
3. Read a `@SolidState` field on the injected type with the same syntax they'd use in v1 (`counter.value`), and have the §5.1 cross-class rewrite produce the correct lowered access (`counter.value.value`) automatically wrapped in a `SignalBuilder`.
4. Get a clear build-time error for invalid targets (non-`late` field, field with initializer, `final`/`const`/`static`, method/getter/setter/top-level, `SignalBase`-typed field, plain-class host) and for the same-class provide-and-consume anti-pattern (which traps at runtime in SwiftUI too).
5. Have the injected instance auto-disposed when the providing widget unmounts, when the type carries reactive state (Solid-lowered → implicitly `implements Disposable` → caught by the `.environment<T>()` default dispose callback).

## TODO sequence

- **M6-01** — `solid_annotations` package amendment: `@SolidEnvironment()` annotation, `Disposable` marker interface, `.environment<T>()` extension on `Widget`. `provider` runtime dep added. Removes `'SolidEnvironment'` from `_reservedAnnotations` (last entry) and migrates `m1_15_environment` rejection case to a no-op marker test. Mirror of M4-06 / M5-01's reserved-list-trim pattern.
- **M6-02** — Generator amendment to plain-class lowering: emits `implements Disposable` (merged into existing `implements` clause if any) and `@override` on the synthesized `dispose()`. Extends Section 14 item 4's State<X> dispose-body merge rule to plain classes (when the source has a user-defined `dispose()` body AND reactive declarations, synthesized disposals are prepended; user body preserved verbatim). Regression-fence PR: every existing plain-class golden (M1-06, M4-08, M5-09) regenerated; four new sub-case goldens (existing-implements, extends+with+implements, user-already-Disposable, user-dispose-body).
- **M6-03** — First `@SolidEnvironment` golden on `StatelessWidget` injecting a NON-Solid plain type. Establishes `EnvironmentModel`, `readSolidEnvironmentField`, the `late final ... = context.read<T>();` field synthesis (no initState splice), the StatelessWidget→Stateful split forced by the field, and the `package:provider` import-add. Cross-class type-driven rewrite NOT yet active.
- **M6-04** — Type-driven §5.1 full-chain rewrite: `PrefixedIdentifier` / `PropertyAccess` chains where any prefix resolves to `SignalBase<T>` get `.value` appended at every such position. Existing same-class goldens are a regression fence — they MUST round-trip unchanged. New golden: `@SolidEnvironment late Counter counter;` reading `counter.value` (where `Counter.value` is `@SolidState`) → `counter.value.value` in lowered output, wrapped in `SignalBuilder`.
- **M6-05** — Golden: `@SolidEnvironment` on existing `State<X>` (mirror of M1-07 / M4-08). Existing `initState` body is byte-identical (env never spliced); existing `dispose` body has only `@SolidState` disposals prepended (env never disposed by host).
- **M6-06** — Golden: multiple `@SolidEnvironment` fields on the same widget. Two independent `late final ... = context.read<T>();` field declarations in source-declaration order; cross-class rewrite applied per-field.
- **M6-07** — Rejection: invalid `@SolidEnvironment` targets. Parametric test mirroring M5-05 / M4-04: field with initializer, non-`late` field, `final`/`const`/`static`, method/getter/setter, top-level, `SignalBase`-typed, plain class.
- **M6-08** — Rejection: same-class provide-and-consume. Detection walks `build` body for `Provider<T>(...)` constructor calls and `.environment(...)` extension calls; matches by the resolved closure return type against the class's `@SolidEnvironment` field types.
- **M6-09** — Widget test: end-to-end app exercising `.environment<T>()` + `@SolidEnvironment` + a tap that mutates the provided `Counter`'s `@SolidState` and asserts the consumer rebuilds. Includes a pump-and-settle assertion that disposing the provider unmounts and invokes `Counter.dispose()` via the `Disposable` marker auto-dispose path. Parallel to M5-07 / M4-07 / M3-04.
- **M6-10** — Documentation cleanup: README annotation list (now four shipped, none deferred); `docs/src/content/docs/guides/environment.mdx` rewritten to v2 idioms (`Provider<T>` instead of v1 `SolidProvider`, `.environment<T>()` extension with type inference, `Disposable` marker, same-class provide-and-consume restriction).

## Cross-cutting concerns

- **Body-rewrite pipeline reuse.** `value_rewriter.dart::collectValueEdits` already accepts any `AstNode` (M2-01). M6-04 extends the visitor to handle `PrefixedIdentifier` and `PropertyAccess` in addition to `SimpleIdentifier`, using the analyzer's `staticType` API to detect cross-class `SignalBase` reads. Existing same-class behavior is preserved as a regression fence on every prior M-series golden.
- **`FieldDeclaration` discriminator.** The M1 path keys on `carriesSolidState`. The M6-03 path keys on `carriesSolidEnvironment` and validates: `late` modifier present, no initializer, type is non-`SignalBase`, host class is widget/state. Both reader branches share the `_collectAnnotatedClasses` member walk in `builder.dart`.
- **No materialization for environments.** Environment fields are pure `late final` reads — anyone using them (build, an Effect, a Computed, a Query body) triggers the lazy initializer. Effects always materialize from initState (no consumer); environments never need to. Default `initState()` materializes only Effects; environments never enter the materialization-name list. This is the second key design decision (after queries' lazy lowering) that differentiates an annotation from `@SolidEffect`.
- **No host-side disposal.** Environment fields are NEVER added to the dispose-name list (Section 10). The injected instance is owned by the providing `Provider<T>`'s `dispose:` callback. Section 14 item 4's State-class dispose-merge rule explicitly excludes environments.
- **`Disposable` marker auto-dispose.** Solid-lowered classes (any class with reactive declarations and a synthesized `dispose()`) implicitly `implements Disposable` from M6-02 onward. The `.environment<T>()` extension's default `dispose:` callback runs `if (instance is Disposable) instance.dispose();` so users get auto-cleanup for free in the recommended extension form. The bare `Provider<T>(...)` widget form is `package:provider`'s own surface and follows its conventions (user passes `dispose:` explicitly).
- **`solid_annotations` runtime deps amendment.** M0-02's "no runtime deps" rule was first amended in M5-01 to add `flutter` (the source-time stubs return `Widget`). M6-01 adds `provider` (the `.environment<T>()` extension wraps in `Provider<T>`). `flutter_solidart` remains NOT a `solid_annotations` dep — the user's source layer never names solidart primitives directly (those live in lowered `lib/`).
- **Cross-cutting reactive rules apply uniformly.** Sections 5.1 (now full-chain), 5.2, 5.4, 5.5, 6.0, 6.2, 6.4 all hold inside any reactive context. Cross-class `.value` chains in `build` / Effect / Computed / Query bodies receive the §5.1 rewrite at every `SignalBase` chain position. SignalBuilder placement (§7) records the OUTERMOST tracked chain position so wrapping happens once, not at every chain hop.
- **No `context.watch` codegen, ever.** Provider is wired purely as DI plumbing in v2; reactivity is owned by `@SolidState` / `@SolidEffect` / `@SolidQuery` and the SignalBuilder placement rule. Users who want `context.watch<T>()` for non-Solid reasons import `package:provider` and use it directly outside the Solid lowering. SPEC §3.6 documents this stance explicitly.

## Exit criteria

- All M6-01 through M6-10 items marked DONE.
- `dart test packages/solid_generator/` passes: every M6 golden + every prior golden + every prior rejection test (the M6-02 regenerated plain-class goldens included).
- `flutter test example/` passes: M6-09 widget test + every prior widget test.
- `dart analyze --fatal-infos` and `dart analyze packages/solid_generator/test/golden/outputs/` both report zero issues.
- `dart format --set-exit-if-changed .` reports zero diff.
- `dart analyze packages/solid_annotations` reports zero issues with the new `provider` runtime dep.
- `m1_15_environment` rejection case removed from `packages/solid_generator/test/rejections/m1_15_non_m1_annotations_test.dart` (M6-01); the `_reservedAnnotations` map is empty and a marker test asserts that.
- Reviewer rubric passes on each M6 PR.
- After M6 is green: all four v2 annotations are fully shipped. SPEC Section 13 lists only operational concerns (CI workflow). v2 annotation surface is closed; remaining work is operational + documentation polish.
