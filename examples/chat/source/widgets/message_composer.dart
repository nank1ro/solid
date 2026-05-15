import 'dart:async';

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../backend/chat_backend.dart';
import '../controllers/messages_controller.dart';
import '../controllers/session_controller.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({super.key, required this.channelId});

  final String channelId;

  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final TextEditingController _textController = TextEditingController();
  Timer? _typingTimer;

  @SolidEnvironment()
  late MessagesController messagesController;

  @SolidEnvironment()
  late ChatBackend backend;

  @SolidEnvironment()
  late SessionController session;

  @SolidState()
  String draftText = '';

  @SolidEffect()
  void emitTyping() {
    final text = draftText;
    _typingTimer?.cancel();
    if (text.trim().isEmpty) return;
    backend.markTyping(widget.channelId, session.myUserId);
    _typingTimer = Timer(const Duration(seconds: 3), () {});
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    draftText = '';
    await messagesController.send(widget.channelId, text, session.myUserId);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Type a message…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => draftText = v,
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _send,
            icon: const Icon(Icons.send),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}
