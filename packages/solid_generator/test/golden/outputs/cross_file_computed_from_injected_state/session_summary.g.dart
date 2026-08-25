import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'auth_repository.dart';

class SessionSummary implements Disposable {
  SessionSummary(this._authRepository);

  final AuthRepository _authRepository;

  final loadCount = Signal<int>(0, name: 'loadCount');

  late final hasSession = Computed<bool>(
    () => _authRepository.session.value != null,
    name: 'hasSession',
  );

  late final sessionLength = Computed<int>(
    () => _authRepository.session.value!.length,
    name: 'sessionLength',
  );

  @override
  void dispose() {
    sessionLength.dispose();
    hasSession.dispose();
    loadCount.dispose();
  }
}
