import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

/// A value type whose own `.value` getter returns another `SessionId`. See
/// the file header for why `rawLastId` needs this rather than a plain
/// nullable field.
class SessionId {
  const SessionId();

  SessionId get value => const SessionId();
}

class AuthRepository implements Disposable {
  final session = Signal<String?>(null, name: 'session');

  final lastId = Signal<SessionId>(const SessionId(), name: 'lastId');

  String other = 'unused';

  @override
  void dispose() {
    lastId.dispose();
    session.dispose();
  }
}

class SessionGuard implements Disposable {
  SessionGuard(this._authRepository);

  final AuthRepository _authRepository;

  final probeCount = Signal<int>(0, name: 'probeCount');

  bool hasSession() {
    probeCount.value = probeCount.value + 1;
    return _authRepository.session.value != null;
  }

  int? sessionLength() => _authRepository.session.value!.length;

  bool sessionResolved() => _authRepository.session.hasValue;

  bool hasSessionViaThis() {
    return this._authRepository.session.value != null;
  }

  int? sessionLengthViaThis() => this._authRepository.session.value!.length;

  void clearSession() {
    _authRepository.session.value = null;
  }

  void ensureSession() {
    _authRepository.session.value ??= 'anon';
  }

  void clearSessionViaThis() {
    this._authRepository.session.value = null;
  }

  void ensureSessionViaThis() {
    this._authRepository.session.value ??= 'anon';
  }

  SessionId rawLastId() => _authRepository.lastId.value;

  String otherField() => _authRepository.other;

  @override
  void dispose() {
    probeCount.dispose();
  }
}
