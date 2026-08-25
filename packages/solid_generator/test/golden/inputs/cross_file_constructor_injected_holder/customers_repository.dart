// Plain constructor-injection DI shape reported in issue #104:
// `CustomersRepository` never uses `@SolidEnvironment` or
// `.environment()`/`Provider()` — it just receives `AuthRepository` through
// its constructor and stores it as a plain field. Before the fix,
// `_authRepository.session` reads were silently un-lowered (no `.value`)
// because `_populateCrossFileTypes` never seeded `AuthRepository` into
// `wantedTypes`, so `classRegistry["AuthRepository"]` was empty when this
// file was processed.
//
// Covers a null-check guard (`hasSession`), a `!`-chain access
// (`sessionLength`), a bare assignment (`clearSession`), a `??=`
// compound-assign (`ensureSession`), and the `this.<field>.<reactiveField>`
// receiver shape (`hasSessionViaThis`).
// ignore_for_file: unnecessary_this

import 'package:solid_annotations/solid_annotations.dart';

import 'auth_repository.dart';

class CustomersRepository {
  CustomersRepository(this._authRepository);

  final AuthRepository _authRepository;

  @SolidState()
  int loadCount = 0;

  bool hasSession() {
    loadCount = loadCount + 1;
    return _authRepository.session != null;
  }

  int? sessionLength() => _authRepository.session!.length;

  void clearSession() {
    _authRepository.session = null;
  }

  void ensureSession() {
    _authRepository.session ??= 'anon';
  }

  bool hasSessionViaThis() {
    return this._authRepository.session != null;
  }
}
