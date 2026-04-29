# M5 — `@SolidQuery` on methods → `Resource`

**TODOS.md items:** M5-01 → M5-11
**SPEC sections:** 3.5, 4.8, 5.1, 5.2, 5.4, 5.5, 6.0, 6.2, 6.4, 8.3, 9, 10, 14 item 4
**Reviewer rubric:** `plans/features/reviewer-rubric.md`

## Purpose

M5 adds `@SolidQuery` on methods: an async reactive source whose body fetches data from a `Future` or `Stream`, with auto-tracking of any upstream Signals/Computeds the body reads. The contract mirrors the user-facing v1 API (https://solid.mariuti.com/guides/query/) verbatim: the user invokes the query as a method call (`fetchData()`) and chains `.when({ready, loading, error})` / `.maybeWhen` / `.refresh()` / `.isRefreshing` on the result.

The lowering replaces the annotated method with two emitted declarations: a private `late final _<name>` field holding the upstream `Resource<T>` (or `Resource<T>.stream(...)`), and a thin-accessor method `Resource<T> <name>() => _<name>;` that the user calls. The original method's body becomes the Resource's fetcher closure. When the body reads exactly ONE `@SolidState` identifier, that Signal/Computed is passed directly as the Resource's `source:` (no synthesized wrapper — wrapping a single Signal in a Computed that only returns its `.value` would be a no-op). When the body reads TWO OR MORE reactive declarations, a synthesized `late final _<name>Source = Computed<(T1, T2, …)>(() => (s1.value, s2.value, …))` Record-Computed combines them and is wired as the source. Annotation parameters `debounce:` and `useRefreshing:` propagate to the upstream `Resource` constructor.

To preserve source-time typechecking, `solid_annotations` adds two extension surfaces: runtime-throwing stubs on `Future<T>` and `Stream<T>` (so `fetchData().when(...)` typechecks in `source/`), and runtime-real extensions on `Resource<T>` that proxy `.when` / `.maybeWhen` / `.isRefreshing` to `state.when` / `state.maybeWhen` / `state.isRefreshing` (so the lowered call resolves correctly in `lib/`). `Resource<T>.refresh()` already exists upstream as a direct method, so no proxy is needed for it.

The infrastructural delta over M4 is moderate. Reused: `Resource` is already in the canonical solidart-import list (M1-08 future-proofing), the body-rewrite pipeline already accepts any `AstNode` (M2-01), the non-getter `MethodDeclaration` collection branch already exists (M4-01), and the dispose-name-list synthesis already exists (M4-08). New: thin-accessor synthesis (`emitQueryAccessor`), source-Computed synthesis for auto-tracking (`emitQuerySourceField`), `Future<T>` / `Stream<T>` source-time stubs and `Resource<T>` runtime extensions in `solid_annotations`. Resources are NEVER materialized in `initState()` / synthesized constructor — the thin-accessor invocation IS the consumer that triggers the lazy late-final initializer.

A developer after M5 can:

1. Write `@SolidQuery() Future<User> fetchUser() async => api.getUser();` (Future form) or `@SolidQuery() Stream<int> watchTicker() => Stream.periodic(...);` (Stream form, plain or `async*`) on a `StatelessWidget`, an existing `State<X>`, or a plain class.
2. Read the result via `fetchUser().when(ready: …, loading: …, error: …)` inside `build`, with a `SignalBuilder` automatically wrapping the `when`-result subtree because `.when` reads `Resource.state` internally (which subscribes).
3. Call `fetchUser().refresh()` inside an `onPressed` handler (untracked context per SPEC §6.2) to manually re-run the fetcher.
4. Read upstream `@SolidState` declarations inside the fetcher body and have the query auto-refresh whenever any of them change — the generator synthesizes the `source:` Computed automatically.
5. Use `@SolidQuery(debounce: Duration(milliseconds: 300))` to coalesce rapid auto-refreshes (typeahead) and `@SolidQuery(useRefreshing: false)` to make refreshes re-enter the `loading` state instead of marking `isRefreshing == true`.
6. See the Resource (and its synthesized source Computed) disposed BEFORE the Signals/Computeds it consumes when the widget is torn down.
7. Get a clear build-time error for an invalid target (non-`Future`/`Stream` return, sync method, parameterized method, static, abstract, getter, setter, top-level function, field).

## TODO sequence

- **M5-01** — Golden: simple `@SolidQuery` Future-method on `StatelessWidget` (no upstream signals). Mirror of M4-01 + M4-06 (pulled-in). Establishes `QueryModel`, `readSolidQueryMethod`, `emitResourceField` (Future branch, no source), `emitQueryAccessor` (thin-accessor synthesis), the return-type discriminator. Adds the source-side stub extensions on `Future<T>` / `Stream<T>` and the runtime extensions on `Resource<T>` to `solid_annotations`. Removes `'SolidQuery'` from `_reservedAnnotations` and migrates the `m1_15_query` rejection case to a positive golden.
- **M5-02** — Golden: `@SolidQuery` Stream-method form. Adds the `Resource<T>.stream(...)` branch in `emitResourceField`, the `isStream` discriminator in `QueryModel`, and the synchronous-Stream / `async*` body keyword detection in the reader.
- **M5-03** — Golden: `@SolidQuery` co-exists with `@SolidState` field + `@SolidState` getter + `@SolidEffect` method on the same class. Validates dispose ordering across all four lowered shapes AND proves Effects (always materialized) and queries (NEVER materialized) coexist correctly in the same `initState()`.
- **M5-04** — Golden: `fetchData().when({ready, loading, error})` reads inside `build()`. Critical regression fence proving the §5.1 rewrite skips query call expressions (no spurious `.value`) and that §7's SignalBuilder placement detects the `state` access inside `.when` for tracking.
- **M5-05** — Rejection: invalid `@SolidQuery` targets. Parametric test mirroring M4-04: non-Future/Stream return, async-without-Future-return mismatch, parameterized method, static, abstract, getter, setter, top-level function, field.
- **M5-06** — Golden: explicit `fetchData().refresh()` call inside `onPressed`. Validates that the §5.1 rewrite skips query call expressions, the `.refresh()` chain on the result is a direct method call (upstream `Resource<T>.refresh()`), and §6.2's untracked-context rule applies.
- **M5-07** — Widget test: tap a Reload FAB three times, assert the fetcher fires the expected number of times and the `.when({ready, …})` builder re-emits each time. Parallel to M1-10 / M3-04 / M4-07.
- **M5-08** — Golden: `@SolidQuery` on existing `State<X>` class. Mirror of M4-08's State-class path. Removes the temporary M5-01 reject guard from `state_class_rewriter.dart`. Existing `initState` body is byte-identical between input and output (queries are lazy and not spliced); existing `dispose` body has Resource disposals prepended.
- **M5-09** — Golden: `@SolidQuery` on plain class. Mirror of M4-08's plain-class path. Removes the M5-01 reject guard from `plain_class_rewriter.dart`. Synthesized constructor (if present from existing Effects) does NOT splice query materialization. A plain class with ONLY queries has no synthesized constructor and may have a user-defined constructor.
- **M5-10** — Auto-tracking: query body reads upstream reactive declarations → wires the Resource's `source:` argument. **One read**: pass the Signal/Computed directly (no synthesized field — a single-Signal Computed wrapper would be a no-op). **Two or more reads**: synthesize `late final _<name>Source = Computed<(T1, T2, …)>(() => (s1.value, s2.value, …))` Record-Computed and pass it as the source. The synthesized field, when present, joins the dispose-name list immediately before its Resource so reverse-disposal tears the Resource down first.
- **M5-11** — Annotation parameters: `@SolidQuery(debounce: Duration(...))` propagates to `debounceDelay:`; `@SolidQuery(useRefreshing: false)` propagates to `useRefreshing: false` (default `true` is omitted from the emitted output to keep generated lines short).

## Cross-cutting concerns

- **Body-rewrite pipeline reuse.** `value_rewriter.dart::collectValueEdits` was generalized in M2-01 to take any `AstNode`. M5-01 calls it with the query method's body, exactly mirroring M4-01's `Effect` body handling. The §5.1 type-driven `.value` rewrite fires inside the body for any `@SolidState` identifier the query reads.
- **`MethodDeclaration` discriminator.** The M2-01 path keys on `decl.isGetter` (true → Computed). The M4-01 path keys on `!isGetter && !isSetter && carriesSolidEffect` (→ Effect). The M5-01 path keys on `!isGetter && !isSetter && carriesSolidQuery && (returnType is Future<T> || returnType is Stream<T>)` (→ Resource). All three branches share the `_collectAnnotatedClasses` member walk in `builder.dart`.
- **Imports already future-proofed.** SPEC §9 already lists `Resource` on the canonical `flutter_solidart` import-add list — the M1-08 rule fires unchanged.
- **Disposal in source-declaration order, reversed in `dispose()`.** The `_<name>` Resource is always appended to the unified ordered name list in `signal_emitter.dart::emitDispose`. The synthesized `_<name>Source` Record-Computed (only present for multi-dep queries) is emitted immediately before its Resource so reverse-declaration disposal tears the Resource down first, then the Record-Computed, then any underlying Signals. Single-dep queries pass the existing Signal/Computed directly as `source:` and emit no extra dispose entry — the underlying Signal is already in the dispose list from its own `@SolidState` declaration.
- **No materialization for queries.** Queries are lazy — the thin-accessor invocation IS the consumer. Effects always materialize (no consumer). Default `initState()` materializes only Effects; queries never enter the materialization-name list. This is the key design decision differentiating Resource from Effect lowering.
- **`solid_annotations` runtime deps amendment.** M0-02's "no runtime deps" rule is amended in M5-01: the source-time stub extensions on `Future<T>` / `Stream<T>` return `Widget` (so `fetchData().when(...)` typechecks in `source/`), and the runtime extensions on `Resource<T>` reference `Resource<T>` directly. Both require `flutter` and `flutter_solidart` as `solid_annotations` runtime deps.
- **Source-time typechecking via stub extensions.** The `Future<T>.when` / `Future<T>.refresh` / `Stream<T>.when` / etc. extensions in `solid_annotations` have runtime-throwing bodies. Source compiles; the throwing bodies are never invoked because the runtime artifact is in `lib/` where the lowered `fetchData()` returns `Resource<T>` and the runtime extensions on `Resource<T>` (also in `solid_annotations`) handle the call.
- **No reactive-deps requirement for query bodies.** Unlike Effect (§3.4) and Computed (§4.5), a query body MAY have zero reactive reads. `readSolidQueryMethod` skips the `_readReactiveBody` zero-deps check that `readSolidEffectMethod` and `readSolidStateGetter` enforce. When the body has zero reactive reads, no source Computed is synthesized and the Resource constructor omits the `source:` argument.
- **Cross-cutting reactive rules apply uniformly.** Sections 5.1, 5.2, 5.4, 5.5, 6.0, 6.2, 6.4 all hold inside query bodies. Query call expressions in `build` / Effect / Computed bodies are method invocations (not bare identifiers) — the §5.1 rewrite skips them, leaving `fetchData().when(...)` chains byte-identical between input and output. SignalBuilder placement still wraps tracked reads (the `state` access inside `.when` is the subscription point).

## Exit criteria

- All M5-01 through M5-11 items marked DONE.
- `dart test packages/solid_generator/` passes: every M5 golden + every prior golden + every prior rejection test.
- `flutter test example/` passes: M5-07 widget test + every prior widget test.
- `dart analyze --fatal-infos` and `dart analyze packages/solid_generator/test/golden/outputs/` both report zero issues.
- `dart format --set-exit-if-changed .` reports zero diff.
- `dart analyze packages/solid_annotations` reports zero issues with the new `flutter` / `flutter_solidart` runtime deps.
- `m1_15_query` rejection case removed from `packages/solid_generator/test/rejections/m1_15_non_m1_annotations_test.dart` (M5-01).
- `_reservedAnnotations` map in `reserved_annotation_validator.dart` no longer lists `'SolidQuery'` (M5-01).
- Reviewer rubric passes on each M5 PR.
- After M5 is green: `@SolidQuery` is the third fully-shipped annotation; SPEC Section 13 lists only `@SolidEnvironment` and the provider-tree machinery (`SolidProvider` / `InheritedSolidProvider` / `.environment()` / `context.read` / `context.watch`) as deferred.
