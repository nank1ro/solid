import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../backend/chat_backend.dart';
import '../controllers/users_controller.dart';

class TypingIndicator extends StatelessWidget {
  TypingIndicator({super.key, required this.channelId});

  final String channelId;

  @SolidEnvironment()
  late UsersController usersController;

  @SolidEnvironment()
  late ChatBackend backend;

  @SolidQuery(useRefreshing: false)
  Stream<Set<String>> watchTypingUsers() {
    return backend.typingUsers(channelId);
  }

  @override
  Widget build(BuildContext context) {
    final ids = watchTypingUsers().maybeWhen(
      ready: (ids) => ids,
      orElse: () => const <String>{},
    );
    final label = _labelFor(ids);
    // Collapse to zero height when nobody is typing, so the row reserves no
    // space below the input while idle.
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
