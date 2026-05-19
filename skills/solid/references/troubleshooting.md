# Solid troubleshooting

Common errors and fixes. Source: <https://solid.mariuti.com/faq> plus the "common mistakes" callouts in each guide.

## Build & generation

| Symptom | Cause | Fix |
| --- | --- | --- |
| Edits to a file under `lib/` keep disappearing on save | `lib/` is generated; `build_runner watch` rewrites it from `source/`. | Move the change to the matching `source/<x>.dart`. |
| `lib/<x>.dart` not produced | `source/**` not in `build.yaml` `targets.$default.sources`. | Add `- source/**` to the sources list. |
| Generator errors complain about stale outputs | Old `.g.dart` / `lib/` files conflict with regeneration. | `dart run build_runner build` (or `watch`) deletes conflicting outputs automatically. Or run `scripts/verify.sh`. |
| `flutter run` doesn't pick up a `build_runner` rewrite | No IDE save event fires for filesystem changes. | Press `r` in the `flutter run` terminal, or use [`dashmonx`](https://pub.dev/packages/dashmonx) (`dashmonx -d chrome` etc.). |
| Working with another generator (`freezed`, `json_serializable`, …) and only Solid runs | `build.yaml` `sources` list missing `lib/**` or `$package$`. | Use the full block: `- lib/**`, `- $package$`, `- source/**`. Run `dart run build_runner watch` once. |
| Generated `lib/` files are missing `const`, have unused imports, or use absolute `package:` imports | The generator prioritises correctness over polish; lint-driven fixes aren't applied. | Run `dart fix --apply` after `build_runner` — or use `scripts/verify.sh` which chains them. Apply in CI too. |

## Annotation rejections

| Symptom | Cause | Fix |
| --- | --- | --- |
| Generator rejects `@SolidState() final int counter = 0;` | `@SolidState` requires an assignable target — the generator rewrites reads through a setter. | Drop `final`. Use `@SolidState() int counter = 0;`. |
| Generator rejects `@SolidState() static int counter = 0;` | State is per-widget-instance, not per-class. | Drop `static`. |
| `late` field with `@SolidState` never gets a value | A `late` `@SolidState` field needs an initializer site (or to be assigned before first read). | Either initialize at declaration or assign before read; or make the type nullable. |
| `@SolidQuery() Future<String> fetchData(int id) async {...}` rejected | Queries cannot have parameters. | Move the input into a `@SolidState` field; the query auto-re-runs when it changes. See `references/patterns.md` §5. |
| `@SolidEnvironment() Counter counter;` errors at first read | Lookup is lazy and needs `late`. | Mark the field `late`: `@SolidEnvironment() late Counter counter;`. |
| Generator rejects `import 'package:<self>/foo.dart';` from a `source/` file | Same-package imports inside `source/` must be relative — `package:` resolves to the generated `lib/` realm. | Use a relative import: `import '../path/to/foo.dart';`. |

## Runtime

| Symptom | Cause | Fix |
| --- | --- | --- |
| Atoms are not disposed in tests / long sessions | `flutter_solidart` defaults to auto-dispose, which Solid manages manually. | In `source/main.dart` set `SolidartConfig.autoDispose = false;` before `runApp(...)`. (Will become the default in a future `flutter_solidart` major release.) |
| `Provider not found` when reading a `@SolidEnvironment` field | No ancestor `Provider<T>` in the widget tree. | Add `.environment((_) => T(...))` on a parent widget, or wrap with `Provider<T>(create: ..., child: ...)`. |
| `ProviderNotFoundException` from a `.environment(...)` `create` callback that calls `ctx.read<T>()` | `.environment(X)` wraps the RECEIVER, so X ends up ABOVE it. A consumer chained BEFORE its dependency has the dep BELOW (not above) its own `create` context. | Reorder so the dependency's `.environment(...)` appears AFTER the consumer's (the dep ends up outermost = above). See [patterns.md §6](./patterns.md#6-solidenvironment-reading-an-ancestor-providert) for the worked example. |
| `TypeError: Null is not a subtype of <T>` on a `@SolidEnvironment` field's first read, with a stack that includes `_notifyChanged` → `flush` → `Effect.run` → `Provider.create` | A controller's CONSTRUCTOR writes to one of its own `@SolidState` collection fields (e.g. `channels.addAll(...)` in the ctor body). When the controller is built lazily via `Provider.create` triggered by an `@SolidEffect` reading a `@SolidEnvironment` field, solidart's reactive flush re-enters the Effect's closure mid-init, and the late-final receiver is still null. | Seed `@SolidState` collection fields directly via a non-const collection literal (`List<T> items = [...someConst]`, `Map<K, V> m = {for (final x in xs) x.k: x.v}`) instead of writing in the constructor body. The lowered `ListSignal<T>([...], …)` ctor argument is not a tracked write, so no flush fires. |
| Reactive read inside `@SolidQuery` body doesn't trigger re-run | The read happens before the resource is observed, or on a non-`@SolidState` source. | Ensure the value comes from a `@SolidState` field (or a `@SolidState` getter) on the same widget. |
| `Computed`-like value stale | A regular getter doesn't track dependencies — only `@SolidState`-annotated getters do. | Annotate the getter with `@SolidState()`. |

## Lints & analyzer

| Symptom | Cause | Fix |
| --- | --- | --- |
| `must_be_immutable` lint fires on every Solid widget | The `StatelessWidget` you write holds mutable fields. The generated widget is immutable. | In `analysis_options.yaml`: `analyzer.errors.must_be_immutable: ignore`. |
| `public_member_api_docs` lint fires everywhere in `source/` | Solid's recommended setup disables it. | In `analysis_options.yaml`: `linter.rules.public_member_api_docs: false`. |
| Lints complain about `package:<self>/...` imports inside `source/` | Same-package imports must be relative. | Set `linter.rules.always_use_package_imports: false` and `linter.rules.prefer_relative_imports: true`. |
