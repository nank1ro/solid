import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/navigation_controller.dart';
import 'message_composer.dart';
import 'message_list.dart';

class MessagePane extends StatefulWidget {
  const MessagePane({super.key});

  @override
  State<MessagePane> createState() => _MessagePaneState();
}

class _MessagePaneState extends State<MessagePane> {
  late final navController = context.read<NavigationController>();

  @override
  Widget build(BuildContext context) {
    final channel = navController.currentChannel.value;
    if (channel == null) {
      return const Center(
        child: Text(
          'Pick a channel on the left',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return Column(
      key: ValueKey(channel.id),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Row(
            children: [
              Text(
                channel.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: MessageList(
            key: ValueKey('list-${channel.id}'),
            channelId: channel.id,
          ),
        ),
        MessageComposer(
          key: ValueKey('composer-${channel.id}'),
          channelId: channel.id,
        ),
      ],
    );
  }
}
