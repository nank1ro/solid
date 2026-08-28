## 3.0.0-dev.7

- **FEAT**: A `build()` reading `<query>.previousState` (the `solid_annotations` `previousState` tear-off) now gets a `SignalBuilder` wrap and `flutter_solidart` import even with no `<query>()` call anywhere in the same build — same-class and cross-instance — since `Resource.previousState` is reactive at the signal level. No source edit; the tear-off resolves to `Resource.previousState` unchanged. `<query>.refresh` stays untracked.

## 3.0.0-dev.6

- **FEAT**: A widget `build()` can read another class's `@SolidQuery` method cross-instance (e.g. `viewModel.customers().isLoading`) and now gets the `SignalBuilder` wrap and `flutter_solidart` import it needs, while the `query()` call sites and the `query.refresh` tear-off stay byte-identical (no `.value` rewrite). Previously only the class declaring a query could consume it, even though cross-instance `@SolidState` reads already worked. The cross-file query-name registry is origin-qualified exactly like the `@SolidState` registry (#110 parity): an ambiguous simple name resolves only on a receiver's resolved-library match, so a same-named non-query method is never spuriously tracked.

## 3.0.0-dev.5

- **FIX**: Bare `super.x` constructor parameters now seed the cross-file registry: the superclass is located syntactically (alias-aware, same-package imports only), the matched constructor parameter's type is resolved (recursing through super-formal chains, mapping generic type parameters to the extends-clause type arguments), and the registry walk also searches the located superclass file's own imports one hop further (#108).
- **FIX**: Registry entries under a shadowed or multi-origin simple name are qualified by origin library and resolve only on a receiver's resolved-library match, so a local plain class and a foreign `@SolidState` class sharing a name each behave correctly; ambiguous names never rewrite through AST-only resolution (#110). Side-effect: dispose auto-injection no longer recognizes a name with multiple cross-file origins — pass `dispose:` explicitly for such classes.

## 3.0.0-dev.4

- **FIX**: Files with no `@Solid*` annotation and no provider call site now enter the pipeline when they read cross-file `@SolidState` state — previously they passed through verbatim, leaving reads un-lowered (and `dart fix` could collapse the resulting always-non-null guards into dead code) (#106). Pure-consumer plain classes get `.value` lowering with no `Disposable` synthesis; pure-consumer widgets get the same `SignalBuilder`-wrapped `build()` as `@SolidEnvironment` widgets, with imports repaired combinator-aware. Also covered: static-field holders, untyped fields typed via constructor parameters, and collection receivers (`.first`, for-in). `part` files remain outside the pipeline.

## 3.0.0-dev.3

- **FIX**: The cross-file registry is seeded from instance-field and constructor-parameter declared types (generic type arguments included), so `@SolidState` reads through plain constructor-injected references lower across files (#104). Locally declared names shadow imports, `show`/`hide` combinators are honored, and `dart:core`/`dart:async` names are skipped.

## 3.0.0-dev.2

- **FIX**: Cross-class `.value` rewriting resolves constructor-injected instance fields (including `this.`-prefixed receivers), not just method parameters and `@SolidEnvironment` fields.
- **FIX**: `.environment()`/`Provider(...)` dispose auto-injection is type-aware: injected when the created type provably has `dispose()` or is `@Solid*`-annotated (same- or cross-file), skipped for provably plain types, and kept as the loud compile-time default for unresolvable types (`dispose: null` opts out).

## 3.0.0-dev.1

- **BREAKING**: Raise the Dart SDK lower bound to `^3.10.0` to target the solidart v3 ecosystem.
- **CHORE**: Upgrade `analyzer` to `^12.0.0` and adapt to its reshaped class/enum declaration AST (name and members moved onto `namePart`/`body` for primary constructors).
- **CHORE**: Bump `solid_annotations` to `^3.0.0-dev.1`, `dart_style` to `^3.1.8`, and `build`/`build_runner`/`build_test`.

## 2.0.0+1

- **DOCS**: Update README installation.

## 2.0.0

- **FEAT**: SignalBuilder placement, `.value` rewrite, dispose synthesis, StatelessWidget→StatefulWidget split.
- **FEAT**: Computed synthesis from getter form of `@SolidState`.
- **FEAT**: Fine-grained reactivity with untracked-read semantics (`.untracked`).
- **FEAT**: Support the `untracked(() => …)` function form for untracked **writes** inside reactive bodies (e.g. writing a collection signal in a `@SolidEffect` without a cyclic reaction). The call passes through to `flutter_solidart`'s `untracked`; inner reads still receive `.value` but are not tracked. Previously this form was rejected.
- **FEAT**: Effect lowering with `initState` materialization for State and plain-class targets.
- **FEAT**: Resource lowering for Future/Stream with `.when()` / `.refresh()` call-site preservation.
- **FEAT**: Environment field synthesis with Provider-backed DI and cross-class chain rewrites.

## 1.0.3

- **FIX**: Missing `flutter_solidart` import in generated `main.dart` file, if no reactive annotations are used.

## 1.0.2

- **FIX**: Generator not transpiling code correctly in some cases.

## 1.0.1

- **FIX**: Remove Flutter SDK.

## 1.0.0+2

- **CHORE**: Add `flutter` sdk to resolve score on pub.dev.

## 1.0.0

- Initial version.
