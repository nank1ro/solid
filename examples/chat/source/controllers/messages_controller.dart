import 'dart:async';

import 'package:solid_annotations/solid_annotations.dart';

import '../backend/chat_backend.dart';
import '../domain/models.dart';

class MessagesController {
  MessagesController({required this.backend}) {
    for (final c in ChatBackend.seedChannels) {
      channelMessages[c.id] = <Message>[];
      readIds[c.id] = <String>{};
      final sub = backend.incomingMessages(c.id).listen((m) {
        final current = channelMessages[c.id] ?? const <Message>[];
        channelMessages[c.id] = [...current, m];
      });
      _subs.add(sub);
    }
  }

  final ChatBackend backend;
  final List<StreamSubscription<Message>> _subs = [];

  @SolidState()
  Map<String, List<Message>> channelMessages = {};

  @SolidState()
  Map<String, Set<String>> readIds = {};

  @SolidState()
  int get totalUnread {
    var sum = 0;
    for (final entry in channelMessages.entries) {
      final read = readIds[entry.key] ?? const <String>{};
      for (final m in entry.value) {
        if (m.status != MessageStatus.confirmed) continue;
        if (!read.contains(m.id)) sum++;
      }
    }
    return sum;
  }

  int unreadFor(String channelId) {
    final msgs = channelMessages[channelId] ?? const <Message>[];
    final read = readIds[channelId] ?? const <String>{};
    var n = 0;
    for (final m in msgs) {
      if (m.status != MessageStatus.confirmed) continue;
      if (!read.contains(m.id)) n++;
    }
    return n;
  }

  void markAllRead(String channelId) {
    final msgs = channelMessages[channelId] ?? const <Message>[];
    final next = <String>{...?readIds[channelId]};
    for (final m in msgs) {
      if (m.status == MessageStatus.confirmed) next.add(m.id);
    }
    readIds[channelId] = next;
  }

  Future<void> send(String channelId, String text, String senderId) async {
    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pending = Message(
      id: pendingId,
      channelId: channelId,
      senderId: senderId,
      text: text,
      timestamp: DateTime.now(),
      status: MessageStatus.pending,
    );
    final before = channelMessages[channelId] ?? const <Message>[];
    channelMessages[channelId] = [...before, pending];
    try {
      final confirmed = await backend.send(channelId, text, senderId);
      final list = channelMessages[channelId] ?? const <Message>[];
      channelMessages[channelId] = [
        for (final m in list)
          if (m.id == pendingId) confirmed else m,
      ];
    } on Object {
      final list = channelMessages[channelId] ?? const <Message>[];
      channelMessages[channelId] = [
        for (final m in list)
          if (m.id == pendingId)
            m.copyWith(status: MessageStatus.failed)
          else
            m,
      ];
      Future<void>.delayed(const Duration(milliseconds: 800), () {
        final l = channelMessages[channelId] ?? const <Message>[];
        channelMessages[channelId] = [
          for (final m in l)
            if (m.id != pendingId) m,
        ];
      });
    }
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
  }
}
