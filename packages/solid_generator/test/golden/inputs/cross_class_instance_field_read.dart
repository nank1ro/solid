// Cross-class `.value` rewrite through a plain constructor-injected instance
// field (NOT `@SolidEnvironment`) — the most common Flutter DI shape:
// `final AuthRepository _authRepository;` set via the constructor. The
// receiver type isn't resolvable via `staticType` in the test sandbox (no
// Flutter SDK) or the AST parameter fallback (it's a field, not a
// parameter), so this exercises the third AST fallback tier —
// `_resolveInstanceFieldTypeNameFromAst`. Covers a guard-style null check
// (`_authRepository.session != null`), a chained access through `!`
// (`_authRepository.session!.length`), and the existing Signal-API
// pass-through (`.hasValue`) that must not double-rewrite. The explicit
// `.value` no-double-rewrite case is covered by `value_rewriter_test.dart`
// instead — writing a literal `.value` chain against a non-Future/Stream
// `@SolidState` field has no source-time stub extension in
// `solid_annotations` (unlike `.hasValue`), so it isn't a typecheckable
// authoring pattern for a golden fixture.

import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository {
  @SolidState()
  String? session;
}

class SessionGuard {
  SessionGuard(this._authRepository);

  final AuthRepository _authRepository;

  @SolidState()
  int probeCount = 0;

  bool hasSession() {
    probeCount = probeCount + 1;
    return _authRepository.session != null;
  }

  int? sessionLength() => _authRepository.session!.length;

  bool sessionResolved() => _authRepository.session.hasValue;
}
