// PURE CONSUMER shape reported in issue #106: unlike EVERY fixture in the
// #104/#105 suite (`cross_file_constructor_injected_holder` and siblings),
// `SessionReader` carries NO `@SolidState`/`@SolidEffect`/`@SolidQuery`/
// `@SolidEnvironment` annotation of its own, and no `Provider(...)` /
// `.environment<T>()` call site — it just receives `AuthRepository` through
// its constructor and stores it as a plain field. Before the fix, the
// builder's `hasSolidAnnotation`/`hasProviderHint` fast bailout matched
// neither hint text in this file, so it never even PARSED this file — the
// #104/#105 registry seeding never ran, and `_authRepository.session` reads
// stayed silently un-lowered (no `.value`), the exact shape that let
// `dart fix` collapse a null-guard into dead code in a real router guard.
//
// Covers a null-check guard (`hasSession`), a `!`-chain access
// (`sessionLength`), and a bare assignment (`clearSession`).
// ignore_for_file: unnecessary_this

import 'auth_repository.dart';

class SessionReader {
  SessionReader(this._authRepository);

  final AuthRepository _authRepository;

  bool hasSession() {
    return _authRepository.session != null;
  }

  int? sessionLength() => _authRepository.session!.length;

  void clearSession() {
    _authRepository.session = null;
  }
}
