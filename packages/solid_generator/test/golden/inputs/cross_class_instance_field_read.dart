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
//
// `hasSessionViaThis` / `sessionLengthViaThis` cover the fourth AST fallback
// tier — a `this.<field>.<reactiveField>` receiver (`this.x` parses as a
// `PropertyAccess` with a `ThisExpression` target, never as a
// `PrefixedIdentifier`, so it needs its own resolution branch rather than
// falling out of tier 3's `SimpleIdentifier`-only match).
// ignore_for_file: unnecessary_this

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

  bool hasSessionViaThis() {
    return this._authRepository.session != null;
  }

  int? sessionLengthViaThis() => this._authRepository.session!.length;
}
