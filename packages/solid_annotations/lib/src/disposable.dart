/// {@template SolidAnnotations.Disposable}
/// Marks a generator-lowered class as carrying a synthesized `dispose()`.
///
/// Added to every Solid-lowered class with a synthesized `dispose()` by the
/// generator — ONLY in the generated `lib/` output. The user's
/// `source/` class never declares this interface; the source-layer analyzer
/// cannot see it. The generator auto-injects
/// `dispose: (context, provider) => provider.dispose()` into `Provider<T>`
/// and `.environment<T>()` call sites that omit `dispose:` (SPEC §4.9
/// rule 7). For source-layer typecheck of the auto-injected closure, users
/// declare an empty `void dispose() {}` stub on their source class (SPEC
/// §3.6 Provider-side note).
/// {@endtemplate}
// `one_member_abstracts` is silenced: this is a marker interface consumed by
// the generator (`implements Disposable` in lowered output), not a
// candidate for collapsing into a top-level function.
// ignore: one_member_abstracts
abstract interface class Disposable {
  /// {@macro SolidAnnotations.Disposable}
  void dispose();
}
