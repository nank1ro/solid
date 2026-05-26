import 'package:solid_annotations/solid_annotations.dart';

import '../backend/chat_backend.dart';
import '../domain/models.dart';

class UsersController {
  UsersController() {
    for (final u in ChatBackend.seedUsers) {
      users[u.id] = u;
    }
  }

  @SolidState()
  Map<String, User> users = {};

  void upsert(User u) {
    users[u.id] = u;
  }

  void remove(String id) {
    users.remove(id);
  }

  User? lookup(String id) => users[id];
}
