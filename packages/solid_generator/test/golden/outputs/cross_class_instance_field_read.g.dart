import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository implements Disposable {
  final session = Signal<String?>(null, name: 'session');

  @override
  void dispose() {
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

  @override
  void dispose() {
    probeCount.dispose();
  }
}
