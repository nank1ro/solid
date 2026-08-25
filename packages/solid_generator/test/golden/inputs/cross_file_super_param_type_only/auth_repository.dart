// Cross-file `@SolidState` host for the super-formal-parameter regression
// (issue #104 fix review, finding 3). `customers_repository.dart` reaches
// this class ONLY through an explicitly-typed super-initializer parameter
// (`AuthRepository super.authRepository`) — no `@SolidEnvironment` field, no
// plain constructor-injected field, no `.environment()`/`Provider()` call
// site — so the cross-file registry seeding in
// `builder.dart::_populateCrossFileTypes` must pick up `AuthRepository` from
// the super-formal-parameter's declared type to recognize it as
// Solid-lowered.
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
