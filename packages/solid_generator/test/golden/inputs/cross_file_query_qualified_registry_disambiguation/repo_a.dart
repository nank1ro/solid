// One of two DIFFERENT `Repo` classes sharing a simple name across files —
// the `@SolidQuery` counterpart of
// `cross_file_qualified_registry_disambiguation`'s `foo_a.dart`/`foo_b.dart`
// pair, proving `classQueryNames` gets the SAME per-origin disambiguation
// as `classRegistry` (issue #110 parity). This one is the REAL query
// source: `items()` is annotated `@SolidQuery`.
import 'package:solid_annotations/solid_annotations.dart';

class Repo {
  @SolidQuery()
  Future<List<String>> items() async => const ['a'];
}
