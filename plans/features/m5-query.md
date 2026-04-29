# M5 — `@SolidQuery` on methods → `Resource`

**TODOS.md items:** M5-01 → M5-09
**SPEC sections:** 3.5, 4.8, 5.1, 5.2, 5.4, 5.5, 6.0, 6.2, 6.4, 9, 10
**Reviewer rubric:** `plans/features/reviewer-rubric.md`

## Purpose

M5 adds `@SolidQuery` on methods: an async reactive source whose body fetches from a `Future` or `Stream` and exposes the result as a `Resource<T>`. The method becomes a `late final Resource<T>(() async => …, name: '<n>')` field (Future form) or `late final Resource<T>.stream(() async* { … }, name: '<n>')` (Stream form), with identifier rewrites applied per SPEC Section 5.1. Disposal joins the existing reverse-declaration order alongside `Signal` / `Computed` / `Effect`. Materialization joins the existing Effect path: at mount time on a State class (via the synthesized `initState()`) and at construction time on a plain class (via the synthesized constructor).

The infrastructural delta over M4 is small: `Resource` is already in the canonical solidart-import list (M1-08 future-proofing), the body-rewrite pipeline already accepts any `AstNode` (M2-01), the non-getter `MethodDeclaration` collection branch already exists (M4-01), and the `late final` materialization helpers already exist (M4-06 / M4-08). The genuinely new pieces are: (a) return-type discrimination (`Future<T>` vs `Stream<T>`) with body-keyword consistency checks (`async` vs `async*`), (b) the SPEC §5.1 `.state` accessor for `Resource<T>`-typed receivers (vs `.value` for every other `SignalBase<T>` subtype), and (c) skipping the zero-deps rejection that applies to Effect / Computed bodies (a query body legitimately has no reactive reads).

A developer after M5 can:

1. Write `@SolidQuery() Future<User> fetchUser() async => api.getUser();` (Future form) or `@SolidQuery() Stream<int> watchTicker() async* { … }` (Stream form) on a `StatelessWidget`, an existing `State<X>`, or a plain class.
2. See the Resource auto-materialize at mount/construction time so the fetcher fires once with the initial values.
3. Read the resource's state via `<query>.state.when({ready, loading, error})` inside `build`, with a `SignalBuilder` automatically wrapping the `when`-result subtree.
4. Call `<query>.refresh()` inside an `onPressed` handler (untracked context per SPEC §6.2) to manually re-run the fetcher.
5. See the Resource disposed BEFORE the Signals/Computeds it consumes when the widget is torn down.
6. Get a clear build-time error for an invalid target (non-`Future`/`Stream` return, sync method, parameterized method, static, abstract, getter, setter, top-level function, field).

## TODO sequence

- **M5-01** — Golden: simple `@SolidQuery` Future-method on `StatelessWidget`. Mirror of M4-01 + M4-06 (pulled-in). Establishes `QueryModel`, `readSolidQueryMethod`, `emitResourceField` (Future branch only), the return-type discriminator in `_collectAnnotatedClasses`, and the `late final ... = Resource<T>(() async => …, name: '<n>')` shape. Removes `'SolidQuery'` from `_reservedAnnotations` and migrates the `m1_15_query` rejection case to a positive golden.
- **M5-02** — Golden: `@SolidQuery` Stream-method form. Adds the `Resource<T>.stream(...)` branch in `emitResourceField`, the `isStream` discriminator in `QueryModel`, and the `async*` body keyword detection in the reader.
- **M5-03** — Golden: `@SolidQuery` co-exists with `@SolidState` field + `@SolidState` getter + `@SolidEffect` method on the same class. Validates that the unified dispose ordering across all four lowered shapes (Signal/Computed/Effect/Resource) is correct under the existing reverse-declaration rule and that the unified materialization list (Effect + Resource) populates `initState` correctly.
- **M5-04** — Golden: `<query>.state.when({ready, loading, error})` reads inside `build()`. Critical regression fence for the §5.1 `.state` rewrite — proves that the rewrite does NOT fire on `.state.when(...)` chains (no double-`.state`) and that the `when`-result widget is wrapped in a `SignalBuilder` for fine-grained rebuilds.
- **M5-05** — Rejection: invalid `@SolidQuery` targets. Parametric test mirroring M4-04: non-Future/Stream return, sync method, parameterized method, static, abstract, getter, setter, top-level function, field, plus the M5-specific async-mismatch cases (Future without `async`, Stream without `async*`).
- **M5-06** — Golden: explicit `<query>.refresh()` call inside `onPressed`. Validates that the §5.1 rewrite targets bare identifiers only (not method-call receivers), and that the §6.2 untracked-context rule applies in `on*` callbacks for any reactive read.
- **M5-07** — Widget test: tap a Reload FAB three times, assert the fetcher fires the expected number of times and the `.when({ready, …})` builder re-emits each time. Parallel to M1-10 / M3-04 / M4-07.
- **M5-08** — Golden: `@SolidQuery` on existing `State<X>` class (lifecycle co-existence with hand-written `initState` / `dispose`). Mirror of M4-08's State-class path. Removes the temporary M5-01 reject guard from `state_class_rewriter.dart`.
- **M5-09** — Golden: `@SolidQuery` on plain class. Mirror of M4-08's plain-class path. Removes the M5-01 reject guard from `plain_class_rewriter.dart`. Extends synthesized-constructor materialization (§8.3) to include Resource fields.

## Cross-cutting concerns

- **Body-rewrite pipeline reuse.** `value_rewriter.dart::collectValueEdits` was generalized in M2-01 to take any `AstNode`. M5-01 calls it with the query method's body, exactly mirroring M4-01's `Effect` body handling. The §5.1 type-driven `.value` / `.state` rewrite fires inside the body for any reactive identifier the query reads.
- **`MethodDeclaration` discriminator.** The M2-01 path keys on `decl.isGetter` (true → Computed). The M4-01 path keys on `!isGetter && !isSetter && carriesSolidEffect` (→ Effect). The M5-01 path keys on `!isGetter && !isSetter && carriesSolidQuery && (returnType is Future<T> || returnType is Stream<T>)` (→ Resource). All three branches share the `_collectAnnotatedClasses` member walk in `builder.dart`.
- **Imports already future-proofed.** SPEC §9 already lists `Resource` on the canonical `flutter_solidart` import-add list — the M1-08 rule fires unchanged.
- **Disposal in source-declaration order, reversed in `dispose()`.** Resources are appended to the unified ordered name list in `signal_emitter.dart::emitDispose`. Reverse-declaration order naturally puts the Resource (declared after the Signals/Computeds it may consume) ahead of those declarations in the dispose body — the same algorithm Effect/Computed already exercise.
- **Materialization extension.** The M4-06 / M4-08 helpers `emitInitState(materializedNames)` and `emitConstructor(className, materializedNames)` accept the unified Effect+Resource list interleaved by source-declaration order; both M5-01 (StatelessWidget) and M5-08 / M5-09 (State / plain) reuse the same helpers without amendment to their merge logic.
- **§5.1 `.state` vs `.value` asymmetry — the only conceptually new SPEC rule.** Implemented as a one-line addition to the rewriter's accessor-selector predicate: receivers whose resolved static type is `Resource<T>` get `.state` appended; every other `SignalBase<T>` subtype receiver gets `.value`. The predicate also enforces idempotency: an already-`.state`-terminated chain is skipped (parallel to §5.4's `.value` no-double-append guarantee). M5-04's golden is the regression fence.
- **No reactive-deps requirement for query bodies.** Unlike Effect (§3.4) and Computed (§4.5), a query body MAY have zero reactive reads. `readSolidQueryMethod` skips the `_readReactiveBody` zero-deps check that `readSolidEffectMethod` and `readSolidStateGetter` enforce.
- **Cross-cutting reactive rules apply uniformly.** Sections 5.1, 5.2, 5.4, 5.5, 6.0, 6.2, 6.4 all hold inside query bodies (with the §5.1 `.state` caveat for Resource receivers). Query bodies are reactive code in the same sense as Computed and Effect bodies; no new rule is required.

## Exit criteria

- All M5-01 through M5-09 items marked DONE.
- `dart test packages/solid_generator/` passes: every M5 golden + every prior golden + every prior rejection test.
- `flutter test example/` passes: M5-07 widget test + every prior widget test.
- `dart analyze --fatal-infos` and `dart analyze packages/solid_generator/test/golden/outputs/` both report zero issues.
- `dart format --set-exit-if-changed .` reports zero diff.
- `m1_15_query` rejection case removed from `packages/solid_generator/test/rejections/m1_15_non_m1_annotations_test.dart` (M5-01).
- `_reservedAnnotations` map in `reserved_annotation_validator.dart` no longer lists `'SolidQuery'` (M5-01).
- Reviewer rubric passes on each M5 PR.
- After M5 is green: `@SolidQuery` is the third fully-shipped annotation; SPEC Section 13 lists only `@SolidEnvironment` and the provider-tree machinery (`SolidProvider` / `InheritedSolidProvider` / `.environment()` / `context.read` / `context.watch`) as deferred.
