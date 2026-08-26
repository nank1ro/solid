// Cross-file `@SolidState` host for the STATIC-FIELD-MEDIATED DI regression
// (GAP 2 of the post-#106 residual gap survey). `holder_reader.dart` reaches
// this class ONLY through a `static final AuthRepository instance = …;`
// singleton-holder field — no `@SolidEnvironment` field, no plain instance
// field/constructor parameter, no `.environment()`/`Provider()` call site —
// so the cross-file registry seeding in
// `builder.dart::_populateCrossFileTypes` must stop skipping `static`
// fields to recognize `AuthRepository` as Solid-lowered.
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
