import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'auth_repository.dart';

class Manager implements Disposable {
  Manager(this.repos);

  final List<AuthRepository> repos;

  final loadCount = Signal<int>(0, name: 'loadCount');

  bool anyHasSession() {
    loadCount.value = loadCount.value + 1;
    for (final repo in repos) {
      if (repo.session.value != null) return true;
    }
    return false;
  }

  @override
  void dispose() {
    loadCount.dispose();
  }
}
