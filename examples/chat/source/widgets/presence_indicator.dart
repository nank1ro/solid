import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../backend/chat_backend.dart';
import '../controllers/users_controller.dart';
import '../domain/models.dart';

class PresenceIndicator extends StatelessWidget {
  const PresenceIndicator({super.key});

  @SolidEnvironment()
  late ChatBackend backend;

  @SolidEnvironment()
  late UsersController users;

  @SolidQuery()
  Stream<Map<String, Presence>> watchPresence() {
    return backend.presence();
  }

  @override
  Widget build(BuildContext context) {
    return watchPresence().when(
      ready: (presence) {
        final onlineCount = presence.values
            .where((p) => p == Presence.online || p == Presence.typing)
            .length;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.circle, color: Colors.green, size: 10),
            const SizedBox(width: 4),
            Text('$onlineCount online'),
          ],
        );
      },
      loading: () => const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (e, _) => Text('presence: $e'),
    );
  }
}
