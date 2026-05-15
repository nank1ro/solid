import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../backend/chat_backend.dart';
import '../controllers/users_controller.dart';
import '../domain/models.dart';

class PresenceIndicator extends StatefulWidget {
  const PresenceIndicator({super.key});

  @override
  State<PresenceIndicator> createState() => _PresenceIndicatorState();
}

class _PresenceIndicatorState extends State<PresenceIndicator> {
  late final backend = context.read<ChatBackend>();
  late final users = context.read<UsersController>();
  late final watchPresence = Resource<Map<String, Presence>>.stream(() {
    return backend.presence();
  }, name: 'watchPresence');

  @override
  void dispose() {
    watchPresence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
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
      },
    );
  }
}
