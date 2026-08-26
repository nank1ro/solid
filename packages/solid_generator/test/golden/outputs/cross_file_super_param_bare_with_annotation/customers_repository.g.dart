import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'auth_repository.dart';
import 'base_repository.dart';

class CustomersRepository extends BaseRepository implements Disposable {
  CustomersRepository(super.authRepository);

  final loadCount = Signal<int>(0, name: 'loadCount');

  bool hasSession() {
    loadCount.value = loadCount.value + 1;
    return authRepository.session.value != null;
  }

  @override
  void dispose() {
    loadCount.dispose();
  }
}
