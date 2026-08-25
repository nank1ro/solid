// Cross-class `.value` rewrite through a plain constructor-injected instance
// field (NOT `@SolidEnvironment`) — the most common Flutter DI shape:
// `final AuthRepository _authRepository;` set via the constructor. The
// receiver type isn't resolvable via `staticType` in the test sandbox (no
// Flutter SDK) or the AST parameter fallback (it's a field, not a
// parameter), so this exercises the third AST fallback tier —
// `_resolveInstanceFieldTypeNameFromAst`. Covers a guard-style null check
// (`_authRepository.session != null`), a chained access through `!`
// (`_authRepository.session!.length`), and the existing Signal-API
// pass-through (`.hasValue`) that must not double-rewrite.
//
// `hasSessionViaThis` / `sessionLengthViaThis` cover the fourth AST fallback
// tier — a `this.<field>.<reactiveField>` receiver (`this.x` parses as a
// `PropertyAccess` with a `ThisExpression` target, never as a
// `PrefixedIdentifier`, so it needs its own resolution branch rather than
// falling out of tier 3's `SimpleIdentifier`-only match).
//
// `clearSession` / `ensureSession` / `clearSessionViaThis` /
// `ensureSessionViaThis` cover the same tier-3/tier-4 resolution but for
// assignment-target position (bare write, `??=` compound-assign, and both
// again through `this.`) — the cross-class rewrite appends `.value`
// unconditionally at the identifier's end regardless of get/set context, so
// these prove that holds for the new field/this.-resolved receivers too.
//
// `rawLastId` covers the explicit-`.value`-chain no-double-rewrite guard
// (`_signalApiGetters`) through a tier-3-resolved receiver. Writing a
// literal `.value` chain against `session` itself isn't typecheckable here:
// `session`'s pre-lowering type is `String?`, and appending `.value` to ANY
// nullable receiver — regardless of the underlying type — trips a Dart
// analyzer diagnostic (`unchecked_use_of_nullable_value`) instead of the
// expected "no such getter" error, because the analyzer checks nullability
// before member existence. A non-nullable field sidesteps that diagnostic
// but then genuinely has no `.value` getter (`solid_annotations` stubs
// `.hasValue` / `.previousValue` for exactly this reason but not `.value` —
// see `LazyStateExtension`), so `lastId`'s type is `SessionId`, a value type
// whose own `.value` getter returns `this`: pre-lowering, `.value` resolves
// to that getter (`SessionId`); post-lowering, `lastId` becomes
// `Signal<SessionId>` and `.value` resolves to the Signal getter (also
// `SessionId`) — the declared return type checks out on both sides without
// fighting either quirk.
//
// `otherField` covers the negative twin: `AuthRepository` IS registered
// (via `session`/`lastId`), but `other` is a plain field, not `@SolidState`
// — the field-name discrimination inside `_maybeRewriteCrossClass` must gate
// the rewrite per-member, not per-class.
// ignore_for_file: unnecessary_this

import 'package:solid_annotations/solid_annotations.dart';

/// A value type whose own `.value` getter returns another `SessionId`. See
/// the file header for why `rawLastId` needs this rather than a plain
/// nullable field.
class SessionId {
  const SessionId();

  SessionId get value => const SessionId();
}

class AuthRepository {
  @SolidState()
  String? session;

  @SolidState()
  SessionId lastId = const SessionId();

  String other = 'unused';
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

  void clearSession() {
    _authRepository.session = null;
  }

  void ensureSession() {
    _authRepository.session ??= 'anon';
  }

  void clearSessionViaThis() {
    this._authRepository.session = null;
  }

  void ensureSessionViaThis() {
    this._authRepository.session ??= 'anon';
  }

  SessionId rawLastId() => _authRepository.lastId.value;

  String otherField() => _authRepository.other;
}
