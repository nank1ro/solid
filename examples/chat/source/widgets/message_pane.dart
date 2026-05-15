import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/navigation_controller.dart';
import 'message_composer.dart';
import 'message_list.dart';

class MessagePane extends StatelessWidget {
  const MessagePane({super.key});

  @SolidEnvironment()
  late NavigationController navController;

  @override
  Widget build(BuildContext context) {
    final channel = navController.currentChannel;
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
