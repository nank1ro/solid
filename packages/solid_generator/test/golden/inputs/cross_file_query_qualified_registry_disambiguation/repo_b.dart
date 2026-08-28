// The OTHER `Repo` — same simple name as `repo_a.dart`'s. `items()` here is
// an ORDINARY (non-`@SolidQuery`) method sharing `repo_a.dart`'s method
// name and shape — the false-positive bait `main.dart` calls through `b`.
//
// `otherQuery()` is a real, differently-named `@SolidQuery` method. It is
// NOT exercised from `main.dart` — its only purpose is to give this `Repo`
// an entry of its own in `_registerWantedClassesFrom`'s query-origin
// tracking. Without it, `builder.dart` would never notice this `Repo`
// exists at all (a matched class with ZERO `@SolidQuery` methods
// contributes nothing to `classQueryNamesOrigins`), so the genuine
// two-origin collision on the simple name `Repo` would go undetected and
// `items` would wrongly stay resolvable through the flat,
// origin-blind `classQueryNames` map — exactly the false positive this
// fixture exists to catch.
import 'package:solid_annotations/solid_annotations.dart';

class Repo {
  Future<List<String>> items() async => const ['b'];

  @SolidQuery()
  Future<int> otherQuery() async => 0;
}
