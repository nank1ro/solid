// GAP 3 of the post-#106 residual gap survey: a BARE `super.` formal
// parameter (`super.authRepository`, no type written) forwards
// `AuthRepository` to `BaseRepository`'s constructor. Unlike
// `cross_file_super_param_type_only` (the already-fixed EXPLICIT-typed
// shape), the type is not present in the source at the parameter position
// at all — the syntactic AST walk in `_populateCrossFileTypes` genuinely
// cannot recover it from text alone.
//
// This class carries its OWN `@SolidState` field (`loadCount`), so the file
// enters the builder's MAIN lowering path with a fully RESOLVED
// `CompilationUnit` (`_resolveUnit`) rather than the no-annotation
// fast-path's unresolved syntactic probe. On that resolved path,
// `SuperFormalParameter.declaredFragment.element.type` IS populated even
// though the AST's own `.type` (explicit annotation) is null — verified
// empirically against `package:analyzer` directly — so the seeding loop
// falls back to the resolved element's type for this one shape.
//
// A PURE consumer whose ONLY link to a cross-file `@SolidState` class is a
// bare `super.x` (no annotation, no provider hint anywhere in the file)
// takes the no-annotation fast path instead, which probes an UNRESOLVED
// unit first — `declaredFragment`/`declaredElement` are not populated
// there, so this resolved-only enhancement cannot help that narrower
// shape; such a file still short-circuits to a verbatim copy before any
// resolved unit is ever requested. That remains a documented, accepted gap
// (see CHANGELOG) — this fixture instead proves the case the fix DOES
// reach: a file already entering the pipeline for another reason.
import 'package:solid_annotations/solid_annotations.dart';

// The bare `super.authRepository` shorthand never spells `AuthRepository`
// out in this file's text, so Dart itself has no use for this import — but
// the generator's cross-file registry walk needs an import directive
// pointing at wherever `AuthRepository` is declared to find it and pull in
// its `@SolidState` members.
// ignore: unused_import
import 'auth_repository.dart';
import 'base_repository.dart';

class CustomersRepository extends BaseRepository {
  CustomersRepository(super.authRepository);

  @SolidState()
  int loadCount = 0;

  bool hasSession() {
    loadCount = loadCount + 1;
    return authRepository.session != null;
  }
}
