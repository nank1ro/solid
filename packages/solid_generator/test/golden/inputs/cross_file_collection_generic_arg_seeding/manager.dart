// Generic-type-argument seeding regression fixture (issue #104 fix review,
// finding 4): `Manager` receives `AuthRepository` only wrapped in
// `List<AuthRepository>` — the declared type's simple name is `List`, so
// the constructor-injection seeding loop must recurse into the type
// argument to find `AuthRepository`. Before the fix, only `List` was seeded
// (and even that was later filtered as an SDK name — see finding 5), so
// `AuthRepository` never entered `wantedTypes` and the for-in loop variable
// read below stayed un-lowered.
//
// `firstHasSession` covers the sibling `.first` receiver (same finding):
// previously verified manually but had no persisted fixture — see
// CHANGELOG. Same resolved-type mechanism as the for-in loop variable:
// `repos.first` resolves to `AuthRepository` via `Expression.staticType`.
import 'package:solid_annotations/solid_annotations.dart';

import 'auth_repository.dart';

class Manager {
  Manager(this.repos);

  final List<AuthRepository> repos;

  @SolidState()
  int loadCount = 0;

  bool anyHasSession() {
    loadCount = loadCount + 1;
    for (final repo in repos) {
      if (repo.session != null) return true;
    }
    return false;
  }

  bool firstHasSession() => repos.first.session != null;
}
