import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import '../backend/chat_backend.dart';
import '../domain/models.dart';

class UsersController implements Disposable {
  final users = MapSignal<String, User>({
    for (final u in ChatBackend.seedUsers) u.id: u,
  }, name: 'users');

  void upsert(User u) {
    users[u.id] = u;
  }

  void remove(String id) {
    users.remove(id);
  }

  User? lookup(String id) => users[id];

  @override
  void dispose() {
    users.dispose();
  }
}
