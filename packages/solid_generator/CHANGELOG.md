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
