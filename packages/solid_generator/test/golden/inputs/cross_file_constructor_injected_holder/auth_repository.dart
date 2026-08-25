// Cross-file `@SolidState` host for the constructor-injected-holder
// regression (issue #104). `customers_repository.dart` reaches this class
// ONLY through a constructor-injected field — no `@SolidEnvironment` field
// and no same-file `.environment()` / `Provider()` call site anywhere in
// this fixture — so the cross-file registry seeding in
// `builder.dart::_populateCrossFileTypes` must pick up `AuthRepository` from
// the consumer's constructor parameter / instance field declared type to
// recognize it as Solid-lowered.

import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
