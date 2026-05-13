---
name: solid
description: >
  PRIORITY — read this skill FIRST before writing Dart code when `pubspec.yaml`
  declares `solid_annotations` or `solid_generator`. In these projects Flutter
  conventions are inverted: `lib/` is build_runner output from `source/`;
  editing `lib/` is destroyed on next build. Without this skill you WRITE TO
  THE WRONG DIRECTORY and silently lose work. Use whenever ANY of these appear:
  `solid_annotations`/`solid_generator` in pubspec;
  `@SolidState`/`@SolidEffect`/`@SolidQuery`/`@SolidEnvironment`/`.untracked`
  in the user's message or code; "my lib/ edits keep disappearing";
  "add/scaffold a widget/page/route/model/controller" in such a project;
  reactive patterns (debounce, "when X changes fetch Y", "make reactive"); or
  installing pub packages (go_router, freezed, riverpod, drift,
  json_serializable) whose docs say `lib/` — substitute `source/`. Annotation
  contract (`@SolidQuery` no params, `@SolidEnvironment` needs `late`) is
  non-obvious. NOT for SolidJS/Solid.js or Flutter projects without those
  packages.
---

# Solid (Flutter)

Solid is a tiny framework on top of Flutter. You write reactive state directly on a `StatelessWidget` in `source/`; the `solid_generator` build_runner builder transpiles each `source/<x>.dart` into `lib/<x>.dart`, turning your class into a `StatefulWidget` with `Signal`/`Computed`/`Effect`/`Resource` plumbing from [`flutter_solidart`](https://pub.dev/packages/flutter_solidart). Inspired by SwiftUI (`@Environment`) and SolidJS (fine-grained reactivity).

User-facing docs: <https://solid.mariuti.com>.

## Step 0 — Is this project Solid?

Before doing anything, decide if the project actually uses Solid. The user may not say "Solid" anywhere — and an existing `lib/` directory plus `solid_annotations`/`solid_generator` not being in pubspec means this is *not* a Solid project.

Run this check first:

```bash
grep -E '^\s*(solid_annotations|solid_generator):' pubspec.yaml
```

- **Match found** → this is a Solid project. Follow this skill.
- **No match** → not a Solid project. Don't apply Solid conventions. Skip this skill.

The same check via Read tool works too: read `pubspec.yaml` and look for either package name under `dependencies:` or `dev_dependencies:`. A Solid setup typically has `solid_annotations` (runtime) under `dependencies` and `solid_generator` plus `build_runner` under `dev_dependencies`.

## Cardinal rule

**Edit `source/<x>.dart`. Never edit `lib/<x>.dart`.**

In Flutter, `lib/` is where you write code. In Solid, `lib/` is generated output — every time build_runner runs, it overwrites `lib/<x>.dart` from `source/<x>.dart`. Hand-edits to `lib/` are lost on the next build. The user-facing entry point is `source/main.dart`; `lib/main.dart` is generated.

This inverts Flutter muscle memory. The rest of the Flutter ecosystem (`flutter run`, pub packages, IDE templates, every tutorial on the internet) assumes `lib/` is the source of truth. In this project it isn't. Apply the substitution everywhere.

## Decision shortcuts

| Situation | What to do |
| --- | --- |
| About to write to a file under `lib/` | **Stop.** Find or create the matching `source/<x>.dart` and write there. |
| User asks to "add a widget / page / button / form" | Create `source/<snake_name>.dart`. Use `@SolidState` for fields you'll mutate. |
| User asks to "fetch X when Y changes" | `@SolidState` for the input Y, `@SolidQuery` (no parameters) for the fetch. Body reads Y to register the dependency. |
| User asks to install a pub package whose README says "create `lib/<x>.dart`" | Substitute `source/` for `lib/` in every file-creation step. See `references/third-party-packages.md`. |
| User says "I edited `lib/foo.dart` and the change disappeared" | The `lib/` write is the bug, not build_runner. Migrate the change to `source/foo.dart`, then regenerate. |
| build_runner output looks unpolished (no `const`, unused imports) | Run `scripts/verify.sh`, which chains `dart fix --apply` after build_runner. |
| build_runner fails | Run `scripts/verify.sh` from the package root — it surfaces the first `[SEVERE]` line. |

## Third-party packages: substitute `source/` for `lib/`

When the user (or another AI) installs a new pub package, the package's README, examples, and any AI-generated setup instructions will all assume `lib/` is the source of truth. In a Solid project that assumption is wrong.

**Rule of thumb**: the package itself stays in `pubspec.yaml` as the docs describe. Only the *files you write that import it* move from `lib/` to `source/`. Examples:

- `go_router` README says "create `lib/router.dart`" → create `source/router.dart` instead, and import it from `source/main.dart` via a relative path.
- `freezed` says "create `lib/models/user.dart`" → create `source/models/user.dart`. Freezed's own `*.freezed.dart` generated output still lands wherever `build.yaml` puts it (typically next to the source file under `lib/`, since freezed reads from `lib/`); **but** in a Solid project you want freezed to read from `source/` too. Add `source/**` to freezed's `build.yaml` `sources` list (Solid's setup already does this — keep it).
- `riverpod` generator says "create `lib/providers/...`" → create `source/providers/...`.
- `drift` says "create `lib/database.dart`" → create `source/database.dart`.

For the full list and per-package gotchas, read `references/third-party-packages.md`.

**The key thing to tell yourself**: "the docs say `lib/`. In this project, that means `source/`."

## Same-package imports must be relative

Inside a `source/` file, reference other source files via relative paths (`../controllers/foo.dart`), never via `package:<self>/foo.dart`. The `package:` form resolves to `lib/` (the *generated* realm), pointing your source file at lowered Signal types — the generator now rejects it at build time. Cross-package imports (`flutter`, `solid_annotations`, `provider`, third-party) keep the `package:` form as usual.

## Annotation cheat sheet

Each annotation goes on a class member of a `StatelessWidget` (or any class — `@SolidEnvironment` also works in `State<X>`). The generator turns the widget into a `StatefulWidget` under the hood.

- **`@SolidState()`** — reactive state. Docs: <https://solid.mariuti.com/guides/state>.
  - Valid on: instance field with initializer, `late` non-nullable instance field, nullable instance field, instance getter (derived state).
  - Invalid: `final`, `const`, `static`, setter, method, top-level.
  - Example: `@SolidState() int counter = 0;` or `@SolidState() int get doubleCounter => counter * 2;`.

- **`@SolidEffect()`** — side effect that re-runs whenever its tracked dependencies change. Docs: <https://solid.mariuti.com/guides/effect>.
  - Valid on: instance method returning `void`.
  - Example: `@SolidEffect() void logCounter() { print('Counter: $counter'); }`.

- **`@SolidQuery()`** — reactive async/stream resource. Docs: <https://solid.mariuti.com/guides/query>.
  - Valid on: instance method returning `Future<T>` or `Stream<T>`. **No parameters.**
  - Call site `fetchData()` returns a `Resource<T>` exposing `.when(ready:, loading:, error:)`, `.maybeWhen(...)`, `.isRefreshing`, `.refresh()`.
  - Options: `debounce: Duration(...)`, `useRefreshing: false`.
  - Read `@SolidState` fields from the body to make the query react to them.

- **`@SolidEnvironment()`** — inject a value from the widget tree (SwiftUI-style). Docs: <https://solid.mariuti.com/guides/environment>.
  - Valid on: `late` field on a `StatelessWidget` or `State<X>`.
  - Bound on first access to the nearest ancestor `Provider<T>`.
  - Provide via `.environment<T>()` extension shipped by `solid_annotations`, or `Provider<T>` from `package:provider`.

For full target rules per annotation, read `references/annotation-contract.md`. For canonical idioms, read `references/patterns.md`.

## Untracked reads

By default every read of a `@SolidState` field inside `build`, `@SolidEffect`, or `@SolidQuery` registers a dependency. Two opt-outs:

- **Automatic**: reads inside callback parameters whose name starts with `on` (`onPressed`, `onTap`, `onChanged`, …) are untracked — Solid recognizes user-interaction handlers and doesn't subscribe.
- **Manual**: append `.untracked` to the field. Common use: `key: ValueKey(counter.untracked)`, or reading the same signal you're writing to inside an effect to avoid a self-dependency loop.

In string interpolations, only the long form works: `'${counter.untracked}'`. The short form `'$counter.untracked'` parses as `${counter}` followed by a literal suffix (still tracked).

Docs: <https://solid.mariuti.com/guides/untracked>.

## Setup checklist (fresh project)

If `pubspec.yaml` doesn't yet declare Solid, install it:

1. `flutter pub add solid_annotations flutter_solidart provider`
2. `dart pub add --dev solid_generator build_runner`
3. Create `build.yaml` at the project root (or extend the existing one):
   ```yaml
   targets:
     $default:
       sources:
         - source/**
         - lib/**
         - $package$
   ```
4. In `source/main.dart`, set `SolidartConfig.autoDispose = false;` before `runApp(...)`. (Temporary — will become the default in a future `flutter_solidart` major release.)
5. In `analysis_options.yaml`, add `analyzer.errors.must_be_immutable: ignore` (your source widgets are mutable; the generated ones are immutable).
6. Run `dart run build_runner watch --delete-conflicting-outputs` during development.

## Verify your changes

After writing or editing `source/`, regenerate `lib/` and apply lint fixes:

- **`scripts/verify.sh`** — run from any package root. Runs `dart run build_runner build --delete-conflicting-outputs`, then `dart fix --apply` on the package (adds `const`, removes unused imports, applies relative-import lints). Prints PASS/FAIL plus the first `[SEVERE]` error on failure. Exit code reflects build_runner success; `dart fix` failure is non-fatal.

Why `dart fix --apply` matters: the generator prioritises correct, runnable code over polish. The emitted `lib/` may miss `const` opportunities, leave unused imports, or pick a non-preferred import form. `dart fix --apply` cleans this up using the project's lint rules (`prefer_const_constructors`, `unnecessary_import`, `prefer_relative_imports`, …). Always run it after generation — in CI too.

## Hot reload

`flutter run` does not auto-reload when build_runner rewrites `lib/` (no IDE save event fires for filesystem changes). Two workflows:

- Press `r` in the `flutter run` terminal after build_runner emits.
- Use [`dashmonx`](https://pub.dev/packages/dashmonx) — wraps `flutter run` and triggers hot reload on `lib/` changes. Any `flutter run` flag passes through, e.g. `dashmonx -d chrome`.

## Common mistakes

- Writing to a file under `lib/`. Always under `source/`. (The single hardest rule to internalise.)
- Following a pub-package README literally when it says `lib/`. Substitute `source/`. See `references/third-party-packages.md`.
- Adding `final` or `static` to a `@SolidState` field. The generator rejects it.
- Giving `@SolidQuery` parameters. Use `@SolidState` fields as inputs — the query re-runs when they change.
- Forgetting `SolidartConfig.autoDispose = false` in `source/main.dart` — atoms leak in tests and long sessions.
- Importing same-package files via `package:<self>/...` from inside `source/`. Use relative paths.
- Expecting `flutter run` to pick up build_runner output without `r` or `dashmonx`.
- Treating `must_be_immutable` lint as a real error — your widgets are mutable; the generated ones are immutable. Set `must_be_immutable: ignore`.

## Helper scripts

- **`scripts/verify.sh`** — described above.
- **`scripts/scaffold-widget.sh <PascalName> [--state|--query|--env]`** — writes a starter `source/<snake_case>.dart` with the right boilerplate. Refuses to overwrite.

## Where to read more

- Canonical docs: <https://solid.mariuti.com>
- Annotation valid/invalid targets: `references/annotation-contract.md`
- Canonical idioms (counter, computed, effect, query, environment, untracked): `references/patterns.md`
- Error symptom → cause → fix: `references/troubleshooting.md`
- Third-party package redirect catalogue: `references/third-party-packages.md`
- Working example: <https://github.com/nank1ro/solid/tree/main/example/source>
