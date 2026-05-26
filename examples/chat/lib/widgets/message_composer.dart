import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
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

  late final messagesController = context.read<MessagesController>();

  late final backend = context.read<ChatBackend>();

  late final session = context.read<SessionController>();

  final draftText = Signal<String>('', name: 'draftText');

  late final emitTyping = Effect(() {
    final text = draftText.value;
    _typingTimer?.cancel();
    if (text.trim().isEmpty) return;
    backend.markTyping(widget.channelId, session.myUserId.value);
    _typingTimer = Timer(const Duration(seconds: 3), () {});
  }, name: 'emitTyping');

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    draftText.value = '';
    await messagesController.send(
      widget.channelId,
      text,
      session.myUserId.value,
    );
  }

  @override
  void dispose() {
    emitTyping.dispose();
    draftText.dispose();
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
              onChanged: (v) => draftText.value = v,
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

  @override
  void initState() {
    super.initState();
    emitTyping;
  }
}
