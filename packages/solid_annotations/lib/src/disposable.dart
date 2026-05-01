/// {@template SolidAnnotations.Disposable}
/// Marks a generator-lowered class as carrying a synthesized `dispose()`.
///
/// Added to every Solid-lowered class with a synthesized `dispose()` by the
/// generator at M6-02 — ONLY in the generated `lib/` output. The user's
/// `source/` class never declares this interface; the source-layer analyzer
/// cannot see it. Users who want `Provider<T>(dispose: (_, c) => c.dispose())`
/// to typecheck in source add an empty `void dispose() {}` stub on their
/// source class instead (SPEC §3.6 Provider-side note).
/// {@endtemplate}
// `one_member_abstracts` is silenced: this is a marker interface consumed by
// the generator at M6-02 (`implements Disposable` in lowered output), not a
// candidate for collapsing into a top-level function.
// ignore: one_member_abstracts
abstract interface class Disposable {
  /// {@macro SolidAnnotations.Disposable}
  void dispose();
}
