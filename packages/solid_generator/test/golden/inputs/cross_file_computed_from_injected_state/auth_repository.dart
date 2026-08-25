// Cross-file `@SolidState` host for the constructor-injected-holder +
// Computed-getter combination (issue #104 follow-up). `session_summary.dart`
// reaches this class ONLY through a constructor-injected field — no
// `@SolidEnvironment` field and no same-file `.environment()` / `Provider()`
// call site anywhere in this fixture — so the cross-file registry seeding in
// `builder.dart::_populateCrossFileTypes` must pick up `AuthRepository` from
// the consumer's constructor parameter / instance field declared type to
// recognize it as Solid-lowered, exactly as in
// `cross_file_constructor_injected_holder`. This sibling fixture drives the
// same seeding path but through a `@SolidState` GETTER (Computed lowering)
// instead of a plain user method — see `session_summary.dart` for why that
// matters.

import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}
