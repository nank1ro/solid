# Weather example — Solid generator evaluation

Findings from authoring `examples/weather` as a stress-test of Flutter Solid's
under-exercised paths: `@SolidQuery` with `debounce:`, `.refresh()` + `.isRefreshing`,
parallel resources, per-instance resources keyed off widget constructor params, and a
three-deep `@SolidEnvironment` chain.

The example was first authored against `packages/solid_annotations` and `packages/solid_generator`
at commit `fa59efa`. Two real issues surfaced (per-instance widget-ctor field rewrite gap, and
over-strict `@SolidQuery` arrow-body validation); both were fixed in the follow-up commit
and the workarounds removed from this example. `dart format --set-exit-if-changed .`,
`dart analyze --fatal-infos`, and `dart run build_runner build` all pass cleanly with the
final code.

---

## Primitives exercised — first-try results

| Primitive | Where | First try? | Notes |
| --- | --- | --- | --- |
| `@SolidState` scalar field | `units_controller.dart` (`TempUnit tempUnit`, `WindUnit windUnit`) | yes | Trivial. |
| `@SolidState` collection field | `cities_controller.dart` (`List<City> cities`) | **no** | Initial `= const []` rejected. Generator emits a clear message — see Generator-enforced restrictions below. |
| `@SolidState` getter → `Computed` (plain class) | `cities_controller.dart` (`int get count`) | yes | Works on plain class. |
| `@SolidQuery` (Future) | `widgets/city_card.dart`, `pages/search_page.dart`, `pages/city_detail_page.dart` | **no, now fixed** | Originally arrow bodies on `Future`-returning queries were rejected; the over-strict validation was removed (see Fix 2 below). Final example uses natural `=> …` arrow form on every Future-returning query. |
| `@SolidQuery(debounce:)` | `pages/search_page.dart` (`results()`) | yes | Generator emits `debounceDelay: const Duration(milliseconds: 350)` and synthesizes a `source:` Computed from the `@SolidState String query` read inside the body. |
| `.refresh()` + `.isRefreshing` | `pages/city_detail_page.dart` (refresh button + `LinearProgressIndicator`) | yes | Both resources keep their stale value while `isRefreshing == true`. |
| Two parallel resources in one widget | `pages/city_detail_page.dart` (`current()`, `hourly()`) | yes | Both materialize as independent `late final Resource<T>` fields, both disposed in reverse declaration order. |
| Per-instance resource keyed off widget ctor param | `widgets/city_card.dart` (`weather()` reading `city.lat/lon`) | **no, now fixed** | The generator missed the widget→state scope shift inside `@SolidQuery` bodies (and `@SolidState` getter / `@SolidEffect` bodies). Fix 1 below threads the rewrite through. Final example reads `city.lat`/`city.lon` natively. |
| `@SolidEnvironment` × 3 in one widget | `widgets/city_card.dart`, `pages/city_detail_page.dart` | yes | Two/three injections per widget all wire up. |
| Three-deep `.environment()` chain at root | `source/main.dart` | yes | `WeatherApi → CitiesController → UnitsController`. Generator auto-injected `dispose: (context, provider) => provider.dispose()` on all three call sites. |
| Plain class with constructor parameter | `cities_controller.dart` (`CitiesController({initial})`) | yes | Constructor runs and the synthesized Effect/Signal materialization is interleaved correctly. |
| Plain class as DI'd service (no annotations) | `api/weather_api.dart` | yes | Coexists cleanly. Required: a `void dispose()` method on the class (since auto-injected `dispose:` calls `provider.dispose()` and `WeatherApi` is not Solid-lowered). |
| Cross-class signal read driving query refetch | `widgets/city_card.dart` reads `units.tempUnit`/`units.windUnit` inside `weather()` | yes | Generator inserts `.value` and registers a multi-dep source Computed, so toggling units in Settings re-fetches every visible card. |

---

## Fix 1 (landed) — widget ctor params not rewritten inside `@SolidQuery` / `@SolidEffect` / `@SolidState` getter bodies

**Severity (original):** broke the headline "per-instance resource keyed off widget constructor
param" pattern. Builds appeared to succeed (no `CodeGenerationError`) but the emitted
`lib/` code referenced an undefined identifier and only `dart analyze` caught it.

**Status:** fixed. `examples/weather` now uses the natural pattern without workaround.

**Source (the natural pattern a developer would write):**

```dart
class CityCard extends StatelessWidget {
  CityCard({super.key, required this.city});
  final City city;

  @SolidEnvironment() late WeatherApi api;
  @SolidEnvironment() late UnitsController units;

  @SolidQuery()
  Future<CurrentWeather> weather() async {
    return api.currentWeather(
      lat: city.lat,         // <-- works in build() but NOT here
      lon: city.lon,
      tempUnit: units.tempUnit,
      windUnit: units.windUnit,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Text(city.name);  // <-- this WILL be rewritten to widget.city.name
  }
}
```

**Generated `lib/widgets/city_card.dart` (broken):**

```dart
class _CityCardState extends State<CityCard> {
  late final api = context.read<WeatherApi>();
  late final units = context.read<UnitsController>();
  late final weather = Resource<CurrentWeather>(() async {
    return api.currentWeather(
      lat: city.lat,        // ← UNDEFINED — `city` lives on the Widget, not on State
      lon: city.lon,
      tempUnit: units.tempUnit.value,
      windUnit: units.windUnit.value,
    );
  }, name: 'weather');
  …
  @override
  Widget build(BuildContext context) {
    …Text(widget.city.name)…   // ← correctly rewritten
  }
}
```

`dart analyze` reports:

```
error • Undefined name 'city' • lib/widgets/city_card.dart:27:12 • undefined_identifier
error • Undefined name 'city' • lib/widgets/city_card.dart:28:12 • undefined_identifier
```

`build_runner` itself does **not** flag this — it reports
`Built with build_runner/aot in Xs; wrote N outputs.` The breakage only surfaces at
analyze time.

**Root cause (verified by reading the generator):**

`packages/solid_generator/lib/src/stateless_rewriter.dart:84–102` applies the
"widget→state scope shift" (renaming bare references to widget-bound non-`@SolidState`
fields to `widget.X`) **only inside the build method**, via `rewriteBuildMethod`.
`emitQueryFields` (called from `stateless_rewriter.dart:273`, implemented in
`packages/solid_generator/lib/src/signal_emitter.dart:339`) emits the query body
**without applying the same rewrite**. Cross-class `@SolidState` reads (e.g.
`units.tempUnit` → `units.tempUnit.value`) are rewritten because that path is a
different transform; only the **own-class widget-bound field** path is missed.

**`this.city` workaround does NOT work** — the rewriter passes `this.city` through
verbatim, so the lib version reads `this.city.lat`, and `this` in the State class
refers to `_CityCardState`, which has no `city` field.

**Fix shipped:** the readers `readSolidStateGetter`, `readSolidEffectMethod`, and
`readSolidQueryMethod` (`packages/solid_generator/lib/src/annotation_reader.dart`)
now accept a `widgetBoundFields` parameter and forward it to `_readReactiveBody` →
`collectValueEdits`. The builder (`packages/solid_generator/lib/builder.dart`)
pre-computes the per-class ctor-bound set via `collectWidgetBoundNames` (promoted to
public in `stateless_rewriter.dart`) and passes it to each reader. Same code path
the `build()` body has used since v2.0; the three other reactive-member bodies now
share it.

Three regression goldens lock the fix in place:

- `packages/solid_generator/test/golden/inputs/computed_reads_widget_ctor_field.dart`
  — `@SolidState` getter on a `StatelessWidget` reading a ctor field.
- `packages/solid_generator/test/golden/inputs/effect_reads_widget_ctor_field.dart`
  — `@SolidEffect` on a `StatelessWidget` reading a ctor field.
- `packages/solid_generator/test/golden/inputs/query_reads_widget_ctor_field.dart`
  — `@SolidQuery` on a `StatelessWidget` reading a ctor field (the form we hit).

The original example pattern now generates correctly:

```dart
@SolidQuery()
Future<CurrentWeather> weather() => api.currentWeather(
  lat: city.lat,         // ← rewritten to widget.city.lat in lib/
  lon: city.lon,
  tempUnit: units.tempUnit,
  windUnit: units.windUnit,
);
```

---

## Generator-enforced restrictions encountered

These are intentional rejections by the generator — surfacing them so future LLMs
know what patterns to avoid.

### 1. `const` initializer on a `@SolidState` collection field is rejected

Source:

```dart
@SolidState()
List<City> cities = const [];
```

Generator error (during `dart run build_runner build`):

```
CodeGenerationError: Failed to generate cities - @SolidState() collection field `cities` has a `const` initializer:
    List<City> cities = const [];
A `const` literal is unmodifiable — the lowered ListSignal would throw `UnsupportedError` on the first write. Drop the `const` so the collection signal wraps a mutable copy:
    List<City> cities = [];
```

Excellent error: it names the field, quotes the offending line, and prints the fix.

### 2. `@SolidQuery` arrow-body bound to a Future return type — was rejected, now accepted (Fix 2 landed)

**Original behaviour:** `Future<T>` queries with an arrow body (no `async`) were
rejected even when the body simply returned a `Future<T>` expression. Source:

```dart
@SolidQuery()
Future<CurrentWeather> weather() => api.currentWeather(...);
```

```
ValidationError at CityCard.weather: [INVALID_QUERY_TARGET_METHOD_WHOSE_BODY_KEYWORD_DOES_NOT_MATCH_THE_RETURN_TYPE]
  @SolidQuery cannot be applied to a method whose body keyword does not match the return type
```

**Fix shipped:** the body-keyword check at `target_validator.dart:284–290` was
deleted. All four shapes (`=> expr`, `async => expr`, `{ return expr; }`,
`async { return expr; }`) are valid Dart and accepted unchanged by the emitter.
Dart's own analyzer reports `await_in_non_async_function` if a body uses `await`
without `async`, so the generator no longer duplicates that check.

The corresponding rejection test (`future_without_async` case in
`solid_query_invalid_targets_test.dart`) and its input fixture are removed; a
positive golden `query_future_arrow_body` was added in their place.

### 3. `@SolidState` getter on existing `State<X>` subclass is hard-rejected

Probe:

```dart
class _ProbeStatefulPageState extends State<ProbeStatefulPage> {
  @SolidState() int count = 0;
  @SolidState() int get doubled => count * 2;
  @override Widget build(BuildContext context) => Text('$doubled');
}
```

Generator error:

```
CodeGenerationError: Failed to generate _ProbeStatefulPageState - @SolidState getter on existing State<X> subclass is not yet supported; offending getter: doubled
```

Matches the documented restriction at
`packages/solid_generator/lib/src/state_class_rewriter.dart:51`. Plain classes and
`StatelessWidget` subclasses support the getter→`Computed` lowering; `State<X>`
subclasses do not. The phrase "not yet supported" suggests this is intentional but
incomplete.

### 4. Factory-only plain class with `@SolidEffect` — works as expected

A hypothesis raised during planning: factory constructors might silently fail to
materialize Effects. Probed four variants:

| Variant | Generative ctor | Result |
| --- | --- | --- |
| `factory X.create() => X._(0); X._(this.seed);` | named private | Effect materialized in `X._` |
| `factory X.create() => X(); X();` | default | Effect materialized in `X()` |
| `factory X.create() { … return X._(); } X._();` (factory has a body) | named private | Effect materialized in `X._` |
| `factory X() = _Impl;` + separate `_Impl()` | redirecting factory on abstract class | Effect materialized in `_Impl()` |
| Singleton via `factory X() => _instance ??= X._internal();` | `X._internal();` | Effect materialized in `X._internal` |

**Conclusion:** the hypothesis does not reproduce. The generator always inserts
the materializing `effectName;` statement into the **generative** constructor of
whichever class hosts the `@SolidEffect`. Since Dart requires a generative ctor for
any factory to return an instance, there is always a place for the materialization
to land.

The Explore agent's flag was based on reading a guard (`rejectIfEffectsNotYetSupported`
in `packages/solid_generator/lib/src/effect_model.dart:62–74`) that has no call
site — but that guard is for `@SolidEffect` on a `State<X>` subclass, not on a
plain class with a factory. The two paths are independent. I did not probe the
former because all my widgets are `StatelessWidget`.

---

## Other observations

### `MaterialApp` `home:` is not enough for Provider scope across routes

Initially put `.environment()` on `const HomePage().environment(…)`. Pushing a new
route from `HomePage` then could not see the providers (Navigator-pushed routes
are siblings to the initial route's subtree, not children). Fix: chain
`.environment()` on `const WeatherApp()` (which returns `MaterialApp`) so the
Provider sits above the Navigator. This is a Flutter/Provider pattern, not a
Solid-specific issue, but worth noting because the existing single-page examples
(`examples/todos`, `example/`) put providers on `home:` and don't surface this.

### `dispose` is implicitly required on every DI'd type

`WeatherApi` is a plain `http` wrapper with no Solid annotations. When passed to
`.environment((_) => WeatherApi())`, the generator auto-injects
`dispose: (context, provider) => provider.dispose()` — which requires `WeatherApi`
to have a `dispose()` method. Added `void dispose() => _client.close();`. This is
intentional: per project policy, types passed to `.environment()` are expected to
declare `dispose()` when they have something to clean up; Solid-lowered classes get
one synthesized automatically, and non-Solid types that genuinely have nothing to
release can simply not be passed through `.environment()`. Closing the http client
on Provider teardown is legitimate cleanup, so the explicit method stays.

### Obsolete `--delete-conflicting-outputs` flag (Fix 3 landed)

`build_runner` no longer accepts `--delete-conflicting-outputs` or its `-d`
shorthand — both are removed and print a warning if passed. Six docs/script files
were updated to drop the flag; the user's auto-memory was updated to match. Output
deletion happens implicitly.

### Cross-class type imports (Fix 4 landed)

When a `@SolidQuery` body reads a cross-class signal via an `@SolidEnvironment`
receiver (e.g. `units.tempUnit`), the synthesized Record-Computed names the
field's declared type (`TempUnit`) textually in `lib/`:

```dart
late final _weatherSource = Computed<(TempUnit, WindUnit)>(...);
```

In v1 of the cross-class fix the user had to import `domain/units.dart` in
the source file with `// ignore: unused_import`, because the source body
never spelled the type. The generator now auto-injects the missing import
into the consumer's lib output during the cross-file resolution pass —
relative form, deduped against existing source-side imports by resolved
`AssetId`. The source files have no extra imports and no ignores. Verified
via two regression goldens:
`packages/solid_generator/test/golden/inputs/query_with_cross_class_signal_unimported_type/`
and `…_already_imported_type/`.

### `flutter analyze` flagged numerous post-build infos that needed file-level ignores

To get a clean `dart analyze --fatal-infos` (CI's strictness), the following had to
be added to `analysis_options.yaml` beyond what `examples/todos` already specifies:

- `discarded_futures: ignore` — for `current.refresh(); hourly.refresh();` inside
  sync `onPressed` callbacks.
- `use_setters_to_change_properties: ignore` — for `void setTempUnit(TempUnit unit) => tempUnit = unit;` in `UnitsController`.
- `deprecated_member_use: ignore` — `RadioListTile.groupValue` is deprecated post
  Flutter 3.32 in favour of `RadioGroup`. Suppressed rather than migrated to keep
  the example focused on Solid primitives, not the Material 3 API churn.
- `avoid_equals_and_hash_code_on_mutable_classes: ignore` — `City` defines `==`/
  `hashCode` and is logically immutable (all `final` fields) but isn't annotated
  with `@immutable`. Suppressed locally.

These are downstream Flutter/lint concerns rather than Solid issues, but a future
fresh example author will hit them and should know to copy this expanded list.

---

## Reproduction notes

```bash
# from the repo root
flutter pub get
cd examples/weather
dart run build_runner build
dart analyze --fatal-infos
dart format --set-exit-if-changed .
```

The pre-fix bug behaviour (Fix 1) can be reproduced by checking out the commit
prior to the generator fix, building the example, and observing the
`Undefined name 'city' • undefined_identifier` errors in `lib/widgets/city_card.dart`
and `lib/pages/city_detail_page.dart`. With the fix landed, the natural `city.lat`
form is rewritten to `widget.city.lat` in the generated `lib/` automatically.
