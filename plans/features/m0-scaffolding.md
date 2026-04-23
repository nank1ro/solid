# M0 — Scaffolding

**TODOS.md items:** M0-01, M0-02, M0-03, M0-05, M0-06
**SPEC sections:** 2, 3.2, 9, 11, 12
**Reviewer rubric:** `plans/features/reviewer-rubric.md`

## Purpose

Stand up an empty-but-passing workspace so that `build_runner` can run the `source/ → lib/` pipeline with a no-op builder. This milestone delivers zero user-facing behavior — its only job is to prove the packaging, analyzer configuration, and file layout are correct before any real transformation logic exists.

A developer after M0 can:

1. `dart pub get` at workspace root.
2. `dart run build_runner build` inside `example/` and see `example/source/counter.dart` copied verbatim to `example/lib/counter.dart`.
3. `flutter run` in `example/` and see a hello-world screen.
4. `dart test packages/solid_generator` and see an empty suite pass.

Nothing about `@SolidState` works yet — only the plumbing.

## TODO sequence

1. **M0-01** — Workspace `pubspec.yaml`, `analysis_options.yaml`, `.gitignore`. Establish the workspace shape: two packages (`packages/solid_annotations`, `packages/solid_generator`) plus the `example/` Flutter app.
2. **M0-02** — `packages/solid_annotations`. Ship `@SolidState` with its `name:` parameter. Reserve the three other names per SPEC Section 3.2.
3. **M0-03** — `packages/solid_generator`. No-op builder + `build.yaml` with the `^source/{{}}.dart → lib/{{}}.dart` mapping, anchored so `lib/some_source/...` does NOT match.
4. **M0-05** — `example/` with hand-written `source/counter.dart` and `lib/main.dart`. Must round-trip through the no-op builder without breaking.
5. **M0-06** — `golden_test.dart` scaffolding so M1 TODOs just append names to a list.

## Cross-cutting concerns

- **`build.yaml` shape.** Use `build_extensions` with capture groups. `auto_apply: dependents`, `build_to: source` (so writes land in real `lib/` files, not the build cache). Explicit `sources:` under `targets.$default` including both `source/**` and `lib/**` plus `pubspec.*` and `$package$`.
- **Analyzer suppressions.** `example/analysis_options.yaml` needs `must_be_immutable: ignore`, `always_put_required_named_parameters_first: ignore`, `invalid_annotation_target: ignore` so that a `StatelessWidget` with mutable `@SolidState` fields does not trip lint.
- **Versions.** Pin minimums for `build: ^2.4.0`, `build_runner: ^2.10.1`, `build_config: ^1.1.0`, `analyzer: ^6`, `dart_style: ^2.3`, `flutter_solidart: ^2.7.0`. Document in `packages/solid_generator/pubspec.yaml`.
- **`.gitignore`.** Ignore `.dart_tool/`, `.packages`, `build/`, `.flutter-plugins`, `.flutter-plugins-dependencies`. Do NOT ignore `example/source/**` or `example/lib/**` — both are committed review artifacts.
- **Package names.** Per SPEC Section 14 item 5: two packages. `package:solid_annotations` (runtime dep) hosts the annotations; `package:solid_generator` (dev_dep) hosts the builder. There is no `package:solid` umbrella. Users import `package:solid_annotations/solid_annotations.dart` for annotations and `package:flutter_solidart/flutter_solidart.dart` for reactive primitives.

## Exit criteria

- `dart pub get` at workspace root exits 0.
- `dart run build_runner build --delete-conflicting-outputs` in `example/` exits 0; `example/lib/counter.dart` byte-equals `example/source/counter.dart`.
- `flutter run` in `example/` boots and displays hello-world.
- `dart test packages/solid_generator` exits 0 (empty suite passes).
- `dart analyze --fatal-infos` across all packages reports zero issues.
- `dart format --set-exit-if-changed .` reports zero diff.
- Reviewer rubric (all 8 items) passes on the M0 PR.
