import 'package:solid_annotations/solid_annotations.dart';

import '../backend/chat_backend.dart';
import '../domain/models.dart';

class UsersController {
  // Seed the map directly via a collection-literal initializer to avoid
  // a constructor-body write to a Signal — that would trigger solidart's
  // reactive flush during lazy `Provider.create` and re-enter the host
  // Effect mid-construction.
  @SolidState()
  Map<String, User> users = {for (final u in ChatBackend.seedUsers) u.id: u};

  void upsert(User u) {
    users[u.id] = u;
  }

  void remove(String id) {
    users.remove(id);
  }

  User? lookup(String id) => users[id];
}
