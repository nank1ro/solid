// Router-guard shape from issue #106's real-world reproduction: an
// annotation-free `AuthGuard` reads a cross-file `@SolidState` session
// field through an `if (... == null) { … } else { … }` branch. Before the
// fix, `_authRepository.session` stayed un-lowered (a bare `String?`
// field read, not a `Signal<String?>` read), so `dart fix`'s
// `dead_code`/`unnecessary_null_comparison` passes would see the
// un-lowered comparison as trivially always-true or always-false and
// collapse one branch away — reproduced in a real app as a generated
// authentication bypass. `SessionReader` carries no `@SolidState` field of
// its own — the ONLY thing that could seed the cross-file registry for
// this file is the #106 pure-consumer probe.

import 'auth_repository.dart';

class AuthGuard {
  AuthGuard(this._authRepository);

  final AuthRepository _authRepository;

  String onNavigation() {
    if (_authRepository.session == null) {
      return '/login';
    } else {
      return '/home';
    }
  }
}
