// Explicit-typed `super.` formal parameter DI shape (issue #104 fix review,
// finding 3): `CustomersRepository`'s constructor receives `AuthRepository`
// only through `AuthRepository super.authRepository`, forwarding it to
// `BaseRepository`'s constructor. `authRepository` is never redeclared as a
// field here — it's read as an inherited member. Before the fix,
// `_populateCrossFileTypes` had no branch for `SuperFormalParameter`, so
// `AuthRepository` was never seeded into `wantedTypes` and
// `authRepository.session` reads were silently un-lowered.
import 'package:solid_annotations/solid_annotations.dart';

import 'auth_repository.dart';
import 'base_repository.dart';

class CustomersRepository extends BaseRepository {
  // The explicit `AuthRepository` type annotation is the shape under test —
  // it's what makes this parameter recoverable by a syntactic AST walk (see
  // the file comment above). Suppress the lint that would otherwise flag it
  // as redundant.
  // ignore: type_init_formals
  CustomersRepository(AuthRepository super.authRepository);

  @SolidState()
  int loadCount = 0;

  bool hasSession() {
    loadCount = loadCount + 1;
    return authRepository.session != null;
  }
}
