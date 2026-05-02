# M7 — Operational: GitHub Actions CI

**TODOS.md items:** M7-01 (more candidate items flagged below; not yet committed to)
**SPEC sections:** 13 (deferred operational concerns)
**Reviewer rubric:** `plans/features/reviewer-rubric.md`

## Purpose

M7 ships the deferred operational concern from SPEC §13: a CI workflow that runs the verification commands on every PR and every push to `main`, instead of relying on developer discipline to run them locally. The v2 annotation surface (M1, M4, M5, M6) is closed; what remains is the operational scaffolding around the codebase — CI checks, docs deployment, contributor docs.

The repo is public on GitHub, so Actions minutes are unmetered. SPEC §13's parenthetical "until GitHub Actions budget permits" is moot, and CI can run unconstrained on every event without a minute budget.

The workflow is modeled on a developer-supplied reference: a single `build` job on `ubuntu-latest`, both `dart-lang/setup-dart@v1` and `subosito/flutter-action@v2` installed, `cache: true` on the Flutter action so the SDK and pub cache are restored on subsequent runs, `paths-ignore: ["**.md"]` so doc-only commits skip CI, and a `concurrency` block that cancels superseded runs on the same head ref. The reference's `--coverage` and Codecov upload steps are intentionally dropped — coverage tracking is not part of M7.

A developer after M7-01 can:

1. Open a PR and see a green CI check confirming the six M6-environment.md exit-criteria commands pass: `dart format --set-exit-if-changed`, three `dart analyze` invocations (root, golden outputs, annotations package), `dart test packages/solid_generator/`, and `flutter test example/`.
2. Push a `.md`-only commit and see CI correctly skip the run.
3. Push two commits in rapid succession and see the older run cancelled by the `concurrency` block.
4. Trust that on a second run, the Flutter SDK is restored from cache (setup step <10s) instead of redownloaded.

## TODO sequence

- **M7-01** — `.github/workflows/ci.yml` with a single `build` job on `ubuntu-latest`. Triggers: `pull_request` (any branch) + `push` to `main`, both filtered by `paths-ignore: ["**.md"]`. Steps: checkout, setup-dart, flutter-action with `cache: true`, `flutter pub get`, then the six M6-exit-criteria commands. `-r github` reporter on test runs; `--fail-fast` on `dart test`. No coverage / Codecov.

## Candidate follow-ups (not yet committed to)

- **M7-02** — `.github/workflows/docs.yml` building the Astro site under `docs/` on every PR + push to `main`. Different toolchain (Node + `npm ci && npm run build`); cleaner as its own item with `actions/setup-node@v4` and `cache: npm`.
- **M7-03** — `CONTRIBUTING.md`, `dependabot.yml` for Dart + GitHub Actions deps, CI status badge in README.

These are listed for visibility, not scoped or estimated. They land only when the user requests them.

## Cross-cutting concerns

- **Pub workspace resolution.** Root `pubspec.yaml` declares `workspace: [packages/solid_annotations, packages/solid_generator, example]`. A single `flutter pub get` at the repo root resolves all three members; per-package `pub get` is unnecessary and duplicates work.
- **Flutter SDK cache key.** `subosito/flutter-action@v2`'s `cache: true` keys on a hash of the channel + version + the action's bundled cache logic; pub-cache content is keyed on `pubspec.yaml` / `pubspec.lock` content. First run downloads the SDK (~80MB) and primes pub-cache; subsequent runs restore in seconds. No manual `actions/cache` block needed.
- **`paths-ignore` semantics.** Both `pull_request` and `push` triggers carry the same `paths-ignore: ["**.md"]` filter. A commit that touches only `.md` files (anywhere in the tree) does not trigger CI. A commit that touches a `.md` AND a `.dart` file DOES trigger CI (paths-ignore is "all paths ignored" semantics; any non-ignored path enables the trigger).
- **Concurrency cancellation.** `group: ${{ github.head_ref || github.run_id }}` keys on the PR head ref when triggered from a PR (so all runs on the same PR share a group), and on the unique run id otherwise (so push-to-main runs never cancel each other). `cancel-in-progress: true` aborts older runs in the same group when a new run starts.
- **Reporter choice.** `-r github` on `dart test` and `flutter test` emits GitHub Actions workflow commands (`::error::`, `::group::`) so failures are surfaced inline in the PR diff view. Without it, failures land in the raw run log only.
- **`--fail-fast` asymmetry.** `dart test` accepts `--fail-fast` and stops at the first failing test (useful for golden-test suites where the first divergence is usually informative). `flutter test` does not accept `--fail-fast`; the flag is omitted on that step.
- **Branch protection (out of scope here, configured separately on GitHub).** For the CI check to actually gate merges, the repo's branch protection rules on `main` need the `build` check marked as required. That's a one-time GitHub-UI action by the repo owner; not part of the workflow file itself.

## Exit criteria

- `.github/workflows/ci.yml` exists and parses cleanly (YAML well-formed).
- A representative PR shows the `CI / build` check green, with all seven step lines passing.
- On a second push to the same PR, the `Setup Flutter` step shows `Cache hit: true` and completes in <10s.
- A pure-`.md` commit on a separate branch does NOT trigger the workflow.
- Two commits pushed in quick succession on the same PR branch result in the first run being cancelled and only the second completing.
- M7-01 marked DONE in TODOS.md with a one-line summary mirroring M6-10's format.
- Reviewer rubric passes on the M7-01 PR.
- After M7-01 is green: the deferred operational concern from SPEC §13 is satisfied for Dart/Flutter checks. M7-02 (docs build) and M7-03 (CONTRIBUTING + dependabot + status badge) remain optional follow-ups.
