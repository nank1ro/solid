## 3.0.0-dev.1

- **BREAKING**: Raise the Dart SDK lower bound to `^3.10.0` to target the solidart v3 ecosystem.
- **CHORE**: Upgrade `analyzer` to `^12.0.0` and adapt to its reshaped class/enum declaration AST (name and members moved onto `namePart`/`body` for primary constructors).
- **CHORE**: Bump `solid_annotations` to `^3.0.0-dev.1`, `dart_style` to `^3.1.8`, and `build`/`build_runner`/`build_test`.
- **FIX**: Cross-class `.value` rewrite now resolves constructor-injected instance fields (`final AuthRepository _authRepository;`), not just method/function parameters and `@SolidEnvironment` fields. Previously a bare instance field receiver silently kept its unlowered form, producing always-true null checks and compile errors against the unboxed `Signal` payload. Also covers a `this.`-prefixed receiver (`this._authRepository.session`) — `this.<field>` parses as a distinct AST shape from the bare `_authRepository.session` form and previously fell through unrewritten.
- **FIX**: `.environment()` / `Provider(...)` dispose auto-injection is now type-aware — `dispose: (context, provider) => provider.dispose()` is injected per a four-tier decision: (1) the created type provably has `dispose()` (own declaration, or inherited — including transitively through a same-file base-class chain); (2) the created type is `@Solid*`-annotated, same-file OR cross-file (every Solid-lowered class synthesizes `dispose()`); (3) the type's declaration is visible and shows neither → skip, no injection; (4) the declaration isn't visible anywhere this check looked (typically a cross-file, non-`@Solid*` type) → inject anyway, preserving the pre-type-aware default so a wrong guess fails loudly at compile time rather than silently leaking a resource, with `dispose: null` as the explicit opt-out. Previously the injection was unconditional and made source-layer typechecking fail with a compile-time `undefined_method` error on `.dispose()` for any type with no `dispose()` method; omitting `dispose:` for such a type now injects nothing (same as an explicit `dispose: null`) instead of a load-bearing `dispose: null` workaround. This changes generated output for existing call sites that omit `dispose:` on a dispose-less type — the compile error goes away.
- **FIX**: The dispose auto-injection above now also recognizes a cross-file `@Solid*`-annotated type provided via `.environment<T>()` / `Provider<T>(...)` even when nothing in the providing file consumes `T` through an `@SolidEnvironment` field. Previously such a controller — the dominant real-world shape, e.g. a top-level `main()` that provides a controller it never itself consumes — got NO dispose injection at all: its synthesized `dispose()` only exists after lowering, which was invisible to every check this rewriter had. This was a silent resource leak, not a compile error, because the call site was already valid Dart (`dispose:` simply absent).

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
