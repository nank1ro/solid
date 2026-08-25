import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'auth_repository.dart';

class CustomersRepository implements Disposable {
  CustomersRepository(this._authRepository);

  final AuthRepository _authRepository;

  final loadCount = Signal<int>(0, name: 'loadCount');

  bool hasSession() {
    loadCount.value = loadCount.value + 1;
    return _authRepository.session.value != null;
  }

  int? sessionLength() => _authRepository.session.value!.length;

  void clearSession() {
    _authRepository.session.value = null;
  }

  void ensureSession() {
    _authRepository.session.value ??= 'anon';
  }

  bool hasSessionViaThis() {
    return this._authRepository.session.value != null;
  }

  @override
  void dispose() {
    loadCount.dispose();
  }
}
