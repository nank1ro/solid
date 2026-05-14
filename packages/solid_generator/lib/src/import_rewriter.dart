/// Canonical URI for the runtime package Solid emits references to.
///
/// Added to the output whenever any reactive primitive (`Signal`, `Computed`,
/// `Effect`, `Resource`, `SignalBuilder`, `SolidartConfig`) appears in the
/// generated code.
const String flutterSolidartUri =
    'package:flutter_solidart/flutter_solidart.dart';

/// Canonical URI for `package:provider`. Added to the output whenever any
/// annotated class carries an `@SolidEnvironment` field: the lowered
/// `late final <name> = context.read<T>();` line resolves through `provider`'s
/// `ReadContext` extension on `BuildContext`. The full library is imported (no
/// `show` clause) so consumers can also call other `provider` APIs
/// (`Provider.of<T>(context)`, `MultiProvider`, …) in the same file without a
/// duplicate-import.
const String providerUri = 'package:provider/provider.dart';

/// URI prefix matched when pruning `solid_annotations` imports from generator
/// output. Any source URI starting with this prefix is dropped unless the
/// lowered code references `Disposable` or `.environment<T>()`.
const String solidAnnotationsUriPrefix = 'package:solid_annotations/';

const String _dartScheme = 'dart:';
const String _packageScheme = 'package:';

/// Canonical set of identifiers exported by `flutter_solidart` whose presence
/// in generated output triggers the import-add rule.
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
  // Collection-typed `@SolidState` fields lower to one of these
  // (`List<T>` → ListSignal, `Set<T>` → SetSignal, `Map<K, V>` → MapSignal)
  // via `parseCollectionTypeText` in `signal_emitter.dart`.
  'ListSignal',
  'SetSignal',
  'MapSignal',
};

/// One annotated class's contribution to the generated output.
///
/// `text` is the rewritten (or verbatim) source for the class; `solidartNames`
/// enumerates which [solidartNames] identifiers `text` references, used by the
/// builder to decide whether to add the `flutter_solidart` import.
/// `emitsDisposable` is true when the rewriter spliced `implements Disposable`
/// into the lowered class header (marker rule). The builder unions this flag
/// across results to decide whether to keep the `solid_annotations` import.
///
/// `constCtorNames` is the set of constructor invocation names (matching
/// `InstanceCreationExpression.constructorName.toString()`) that this
/// rewriter emitted with a `const` keyword on their declaration — `"Counter"`
/// for the unnamed ctor, `"Counter.named"` for a named ctor. The builder
/// unions these across all results and runs a post-emit pass that prepends
/// `const ` to matching call sites elsewhere in the assembled output — keeps
/// `prefer_const_constructors` silent end-to-end without requiring the user
/// to run `dart fix`.
typedef RewriteResult = ({
  String text,
  Set<String> solidartNames,
  bool emitsDisposable,
  Set<String> constCtorNames,
});

/// Returns the import URIs that should appear at the top of the generated
/// `lib/` file.
///
/// Imports are emitted in three groups — `dart:`, then `package:`, then
/// relative — alphabetically by full URI within each group, matching the
/// analyzer's `directives_ordering` rule. Appended `flutter_solidart` and
/// `provider` URIs are sorted into position alongside source imports rather
/// than appended at the tail. If [addSolidart] is true and `flutter_solidart`
/// is not already present in [sourceImports], it is added. If [addProvider]
/// is true and `package:provider/provider.dart` is not already present, it is
/// added (env fields lower to `context.read<T>()`).
///
/// `package:solid_annotations/...` imports are dropped from the result unless
/// [referencesSolidAnnotations] is true. Annotation classes (`@SolidState`,
/// `@SolidEffect`, `@SolidQuery`, `@SolidEnvironment`) are stripped during
/// lowering, so a file that uses only annotations leaves no live reference and
/// the import is pruned. The caller computes the flag from the OR of any
/// rewriter's `emitsDisposable` (the `Disposable` marker interface is the only
/// way `solid_annotations` survives a class rewrite) and a textual scan of the
/// lowered body for `.environment<T>()` (the providing extension survives
/// verbatim from user widget code).
List<String> computeOutputImports(
  List<String> sourceImports, {
  required bool addSolidart,
  required bool referencesSolidAnnotations,
  bool addProvider = false,
  Iterable<String> extraImports = const [],
}) {
  final result = [
    for (final uri in sourceImports)
      if (referencesSolidAnnotations ||
          !uri.startsWith(solidAnnotationsUriPrefix))
        uri,
  ];
  if (addSolidart && !result.contains(flutterSolidartUri)) {
    result.add(flutterSolidartUri);
  }
  if (addProvider && !result.contains(providerUri)) {
    result.add(providerUri);
  }
  for (final uri in extraImports) {
    if (!result.contains(uri)) result.add(uri);
  }
  result.sort(_compareImportUris);
  return result;
}

/// Comparator implementing the import emit order: `dart:` group first, then
/// `package:`, then relative; alphabetical (full-URI string compare) within
/// each group. Matches the analyzer's `directives_ordering` lint exactly —
/// `package:flutter/material.dart` sorts before
/// `package:flutter_solidart/flutter_solidart.dart` because `/` (0x2F) < `_`
/// (0x5F) in ASCII.
int _compareImportUris(String a, String b) {
  int rank(String uri) {
    if (uri.startsWith(_dartScheme)) return 0;
    if (uri.startsWith(_packageScheme)) return 1;
    return 2;
  }

  final groupOrder = rank(a).compareTo(rank(b));
  return groupOrder != 0 ? groupOrder : a.compareTo(b);
}
