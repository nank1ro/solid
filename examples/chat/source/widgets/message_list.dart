import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../backend/chat_backend.dart';
import '../controllers/messages_controller.dart';
import '../controllers/users_controller.dart';
import '../domain/models.dart';

class MessageList extends StatelessWidget {
  MessageList({super.key, required this.channelId});

  final String channelId;

  @SolidEnvironment()
  late MessagesController messagesController;

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
    // Hoist signal reads OUT of ListView.builder's deferred `itemBuilder`
    // closure — that closure runs after the wrapping SignalBuilder has
    // stopped tracking, so a read inside it never subscribes. Reading at
    // the build method's statement scope keeps the read inside the outer
    // SignalBuilder that the generator synthesizes around the whole build
    // body (SPEC §7.1 unanchored case).
    final messages =
        messagesController.channelMessages[channelId] ?? const <Message>[];
    final users = usersController.users;
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty
              ? const Center(
                  child: Text(
                    'No messages yet — say hello',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final user = users[m.senderId];
                    return _MessageRow(message: m, user: user);
                  },
                ),
        ),
        SizedBox(
          height: 20,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _labelFor(
                  watchTypingUsers().maybeWhen(
                    ready: (ids) => ids,
                    orElse: () => const <String>{},
                  ),
                ),
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.black54,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ),
      ],
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

class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message, required this.user});

  final Message message;
  final User? user;

  @override
  Widget build(BuildContext context) {
    final isPending = message.status == MessageStatus.pending;
    final isFailed = message.status == MessageStatus.failed;
    Color? bg;
    if (isPending) bg = Colors.grey.shade100;
    if (isFailed) bg = Colors.red.shade50;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.blueGrey.shade100,
            child: Text(
              user?.initials ?? '??',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user?.displayName ?? message.senderId,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(message.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.schedule,
                          size: 12,
                          color: Colors.black45,
                        ),
                      ],
                      if (isFailed) ...[
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.error_outline,
                          size: 12,
                          color: Colors.red,
                        ),
                      ],
                    ],
                  ),
                  Text(message.text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}
