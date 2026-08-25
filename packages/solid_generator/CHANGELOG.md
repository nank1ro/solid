## 3.0.0-dev.3

- **FIX**: The cross-file class registry (`_populateCrossFileTypes`) now seeds `wantedTypes` from the declared type names of every class's instance fields and constructor parameters, not just `@SolidEnvironment` field types and `Provider(...)`/`.environment<T>()` call sites. A file that only *constructor-receives* a `@SolidState`-bearing class — the plain DI shape, e.g. `CustomersRepository({required AuthRepository authRepository})` storing `final AuthRepository _authRepository;`, with no `@SolidEnvironment` field and no same-file `.environment()`/`Provider()` call site — previously left `classRegistry` empty for that type, so cross-class `.value` reads through it (`_authRepository.session`) were silently un-lowered: no compile error, just an always-non-null `Signal` object that `dart fix`'s `unnecessary_null_comparison` could collapse into dead code (#104).
- **FIX**: The seeding above (and, defensively, every other seeding path into `wantedTypes`) now mirrors Dart's own name-resolution rules instead of blindly matching on simple class name. A simple name that the CURRENT file itself declares as a class/enum/mixin is dropped from the wanted set before the cross-file import walk starts — a local top-level declaration always shadows a same-name import, so attributing an unrelated imported class's reactive members to it was provably wrong (e.g. a file with its own plain `class Address` plus an unrelated, unconnected `@SolidState`-annotated `class Address` imported from elsewhere previously emitted a non-compiling `address.line1.value` against the local class). Each import's `show`/`hide` combinators are also now honored: an import that hides the wanted name, or `show`s a list that excludes it, can no longer be credited as that name's source, closing a second, narrower collision window.
- **FIX**: Constructor parameters using the explicit-typed `super.` shorthand (`Foo(AuthRepository super.repo)`) now seed `wantedTypes` the same as a plain or field-formal parameter. The far more common *bare* `super.repo` (no type written) is a known, accepted gap: the type isn't present in the source at that position at all — recovering it would require resolving `repo` against the superclass's matching field/parameter, which this syntactic AST walk does not do — so a bare-shorthand `super.` parameter still isn't a seeding source.
- **FIX**: A field or constructor parameter declared with a generic collection type (`final List<AuthRepository> repos;`) now seeds `wantedTypes` from every type argument, at every nesting level, not just the outer container name (`List`). This lets the existing resolved-static-type rewrite tiers recognize collection-derived receivers whose element type is Solid-lowered — covered by a golden fixture for a `for (final r in repos) { r.field }` loop variable; a `repos.first.field` receiver was verified manually to rewrite the same way (same resolved-type mechanism) but has no persisted fixture, and deeper nesting (`Map<K, List<T>>` and beyond) is mechanically identical but likewise untested. Container names themselves (`List`, `Map`, `String`, and other `dart:core`/`dart:async` SDK types) are now filtered out of every seed in the new constructor-injection/field loop before being added, which also fixes a performance regression where annotation-blind seeding of primitive types on nearly every field defeated the `wantedTypes.isEmpty` fast-path.

## 3.0.0-dev.2

- **FIX**: Cross-class `.value` rewrite now resolves constructor-injected instance fields (`final AuthRepository _authRepository;`), not just method/function parameters and `@SolidEnvironment` fields. Previously a bare instance field receiver silently kept its unlowered form, producing always-true null checks and compile errors against the unboxed `Signal` payload. Also covers a `this.`-prefixed receiver (`this._authRepository.session`) — `this.<field>` parses as a distinct AST shape from the bare `_authRepository.session` form and previously fell through unrewritten.
- **FIX**: `.environment()` / `Provider(...)` dispose auto-injection is now type-aware — `dispose: (context, provider) => provider.dispose()` is injected per a four-tier decision: (1) the created type provably has `dispose()` (own declaration, or inherited — including transitively through a same-file base-class chain); (2) the created type is `@Solid*`-annotated, same-file OR cross-file (every Solid-lowered class synthesizes `dispose()`); (3) the type's declaration is visible and shows neither → skip, no injection; (4) the declaration isn't visible anywhere this check looked (typically a cross-file, non-`@Solid*` type) → inject anyway, preserving the pre-type-aware default so a wrong guess fails loudly at compile time rather than silently leaking a resource, with `dispose: null` as the explicit opt-out. Previously the injection was unconditional and made source-layer typechecking fail with a compile-time `undefined_method` error on `.dispose()` for any type with no `dispose()` method; omitting `dispose:` for such a type now injects nothing (same as an explicit `dispose: null`) instead of a load-bearing `dispose: null` workaround. This changes generated output for existing call sites that omit `dispose:` on a dispose-less type — the compile error goes away.
- **FIX**: The dispose auto-injection above now also recognizes a cross-file `@Solid*`-annotated type provided via `.environment<T>()` / `Provider<T>(...)` even when nothing in the providing file consumes `T` through an `@SolidEnvironment` field. Previously such a controller — the dominant real-world shape, e.g. a top-level `main()` that provides a controller it never itself consumes — got NO dispose injection at all: its synthesized `dispose()` only exists after lowering, which was invisible to every check this rewriter had. This was a silent resource leak, not a compile error, because the call site was already valid Dart (`dispose:` simply absent).

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
