/// Canonical URI for the runtime package Solid emits references to.
///
/// See SPEC Section 9 — added to the output whenever any reactive primitive
/// (`Signal`, `Computed`, `Effect`, `Resource`, `SignalBuilder`,
/// `SolidartConfig`) appears in the generated code.
const String flutterSolidartUri =
    'package:flutter_solidart/flutter_solidart.dart';

/// Canonical URI for `package:provider`. Added to the output whenever any
/// annotated class carries an `@SolidEnvironment` field (SPEC §3.6 / §9): the
/// lowered `late final <name> = context.read<T>();` line resolves through
/// `provider`'s `ReadContext` extension on `BuildContext`. The full library
/// is imported (no `show` clause) so consumers can also call other `provider`
/// APIs (`Provider.of<T>(context)`, `MultiProvider`, …) in the same file
/// without a duplicate-import.
const String providerUri = 'package:provider/provider.dart';

/// Canonical set of identifiers exported by `flutter_solidart` whose presence
/// in generated output triggers the import-add rule (SPEC Section 9).
///
/// Each rewriter declares which subset of these names it statically emits;
/// the builder unions those subsets and adds `flutter_solidart` if the union
/// is non-empty.
const Set<String> solidartNames = {
  'Signal',
  'Computed',
  'Effect',
  'Resource',
  'SignalBuilder',
  'SolidartConfig',
};

/// One annotated class's contribution to the generated output.
///
/// `text` is the rewritten (or verbatim) source for the class; `solidartNames`
/// enumerates which [solidartNames] identifiers `text` references, used by the
/// builder to decide whether to add the `flutter_solidart` import.
/// `emitsDisposable` is true when the rewriter spliced `implements Disposable`
/// into the lowered class header (SPEC §10 marker rule — only emitted by the
/// plain-class rewriter today). The builder unions this flag across results
/// to decide whether to keep the `solid_annotations` import.
typedef RewriteResult = ({
  String text,
  Set<String> solidartNames,
  bool emitsDisposable,
});

/// Returns the import URIs that should appear at the top of the generated
/// `lib/` file.
///
/// Source imports are preserved verbatim and in original order per SPEC
/// Section 9. If [addSolidart] is true and `flutter_solidart` is not already
/// present in [sourceImports], it is appended. If [addProvider] is true and
/// `package:provider/provider.dart` is not already present, it is appended
/// after `flutter_solidart` (SPEC §3.6 / §9 — env fields lower to
/// `context.read<T>()`).
///
/// `package:solid_annotations/...` imports are dropped from the result unless
/// [referencesSolidAnnotations] is true (SPEC §9 bullet 4). Annotation
/// classes (`@SolidState`, `@SolidEffect`, `@SolidQuery`, `@SolidEnvironment`)
/// are stripped during lowering, so a file that uses only annotations leaves
/// no live reference and the import is pruned. The caller computes the flag
/// from the OR of any rewriter's `emitsDisposable` (the `Disposable` marker
/// interface is the only way `solid_annotations` survives a class rewrite)
/// and a textual scan of the lowered body for `.environment<T>()` (the
/// providing extension survives verbatim from user widget code).
List<String> computeOutputImports(
  List<String> sourceImports, {
  required bool addSolidart,
  required bool referencesSolidAnnotations,
  bool addProvider = false,
}) {
  final result = [
    for (final uri in sourceImports)
      if (referencesSolidAnnotations ||
          !uri.startsWith('package:solid_annotations/'))
        uri,
  ];
  if (addSolidart && !result.contains(flutterSolidartUri)) {
    result.add(flutterSolidartUri);
  }
  if (addProvider && !result.contains(providerUri)) {
    result.add(providerUri);
  }
  return result;
}
