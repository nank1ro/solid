/// Canonical URI for the runtime package Solid emits references to.
///
/// See SPEC Section 9 — added to the output whenever any reactive primitive
/// (`Signal`, `Computed`, `Effect`, `Resource`, `SignalBuilder`,
/// `SolidartConfig`, `untracked`) appears in the generated code.
const String flutterSolidartUri =
    'package:flutter_solidart/flutter_solidart.dart';

/// Returns the import URIs that should appear at the top of the generated
/// `lib/` file.
///
/// Source imports are preserved verbatim and in original order per SPEC
/// Section 9. If [addSolidart] is true and `flutter_solidart` is not already
/// present in [sourceImports], it is appended. Unused-import pruning (e.g.
/// `solid_annotations` when no annotation reference remains in the output) is
/// left to `dart fix --apply`; this rewriter never drops a source import.
List<String> computeOutputImports(
  List<String> sourceImports, {
  required bool addSolidart,
}) {
  final result = List<String>.of(sourceImports);
  if (addSolidart && !result.contains(flutterSolidartUri)) {
    result.add(flutterSolidartUri);
  }
  return result;
}
