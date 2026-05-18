import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../backend/chat_backend.dart';
import '../controllers/users_controller.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key, required this.channelId});

  final String channelId;

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> {
  late final usersController = context.read<UsersController>();
  late final backend = context.read<ChatBackend>();
  late final watchTypingUsers = Resource<Set<String>>.stream(
    () {
      return backend.typingUsers(widget.channelId);
    },
    useRefreshing: false,
    name: 'watchTypingUsers',
  );

  @override
  void dispose() {
    watchTypingUsers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        // Resolve the typing set + label inside build's statement scope so the
        // generator's outer SignalBuilder catches the query subscription.
        final ids = watchTypingUsers().maybeWhen(
          ready: (ids) => ids,
          orElse: () => const <String>{},
        );
        final label = _labelFor(ids);
        // Collapse to zero height when nobody is typing — avoids the always-on
        // 20px gap that was visible above the input before.
        return AnimatedSize(
          duration: const Duration(milliseconds: 150),
          alignment: Alignment.topCenter,
          child: label.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  String _labelFor(Set<String> ids) {
    if (ids.isEmpty) return '';
    final names = ids
        .map((id) => usersController.users[id]?.displayName ?? id)
        .toList();
    if (names.length == 1) return '${names.first} is typing…';
    if (names.length == 2) return '${names[0]} and ${names[1]} are typing…';
    return '${names.length} people are typing…';
  }
}
