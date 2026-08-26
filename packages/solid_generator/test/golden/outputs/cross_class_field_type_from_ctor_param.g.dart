import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class AuthRepository implements Disposable {
  final session = Signal<String?>(null, name: 'session');

  @override
  void dispose() {
    session.dispose();
  }
}

class SessionReader implements Disposable {
  SessionReader(AuthRepository this._service);

  final _service;

  final probeCount = Signal<int>(0, name: 'probeCount');

  bool hasSession() {
    probeCount.value = probeCount.value + 1;
    return _service.session.value != null;
  }

  @override
  void dispose() {
    probeCount.dispose();
  }
}

class SessionReaderViaInitializer implements Disposable {
  SessionReaderViaInitializer(AuthRepository service) : _service = service;

  final _service;

  final probeCount = Signal<int>(0, name: 'probeCount');

  bool hasSession() {
    probeCount.value = probeCount.value + 1;
    return _service.session.value != null;
  }

  @override
  void dispose() {
    probeCount.dispose();
  }
}
