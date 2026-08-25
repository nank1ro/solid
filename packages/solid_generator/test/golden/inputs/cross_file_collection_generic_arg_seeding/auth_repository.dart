// Cross-file `@SolidState` host for the generic-type-argument seeding
// regression (issue #104 fix review, finding 4). `manager.dart` reaches
// this class ONLY as the payload type of a `List<AuthRepository>` field —
// no `@SolidEnvironment` field, no plain `AuthRepository`-typed field/param,
// no `.environment()`/`Provider()` call site — so the cross-file registry
// seeding in `builder.dart::_populateCrossFileTypes` must recurse into the
// declared `List<T>` field's type argument to recognize `AuthRepository` as
// Solid-lowered.
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
