// Same constructor-injection DI shape as
// `cross_file_constructor_injected_holder/customers_repository.dart`, but
// the cross-file field is read from inside a `@SolidState` GETTER, which
// lowers to a `Computed` (`emitComputedField` in `signal_emitter.dart`,
// invoked from `plain_class_rewriter.dart`'s getter branch) instead of a
// plain user method. This is the previously-untested combination: the
// cross-file registry seeding fixed for issue #104 threads through
// `readSolidStateGetter` the same way it threads through
// `readSolidEffectMethod` / user-method rewriting, but that path had no
// dedicated coverage.
//
// Danger case if the combination were broken: the Computed closure's
// cross-class read keeps `_authRepository.session != null` un-lowered (no
// `.value`). A `Signal<String?>` object is always non-null, so `hasSession`
// would permanently and silently evaluate to `true` regardless of the
// actual session state — a stale/wrong derived value with no error at
// build or run time.
//
// `sessionLength` mirrors the sibling fixture's `!.`-chain method
// (`cross_file_constructor_injected_holder/customers_repository.dart`'s
// `sessionLength()`) but as a second Computed getter, confirming the
// null-assert chain shape is also legal through the Computed lowering path
// (`cross_class_instance_field_read.dart` already proves the `!.` shape
// legal for plain cross-class methods; this proves it for getters too).

import 'package:solid_annotations/solid_annotations.dart';

import 'auth_repository.dart';

class SessionSummary {
  SessionSummary(this._authRepository);

  final AuthRepository _authRepository;

  @SolidState()
  int loadCount = 0;

  @SolidState()
  bool get hasSession => _authRepository.session != null;

  @SolidState()
  int get sessionLength => _authRepository.session!.length;
}
