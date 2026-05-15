import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/channels_controller.dart';
import '../controllers/messages_controller.dart';
import '../controllers/navigation_controller.dart';
import 'presence_indicator.dart';

class ChannelListPane extends StatelessWidget {
  const ChannelListPane({super.key});

  @SolidEnvironment()
  late ChannelsController channelsController;

  @SolidEnvironment()
  late MessagesController messagesController;

  @SolidEnvironment()
  late NavigationController navController;

  @override
  Widget build(BuildContext context) {
    final channels = channelsController.channels;
    final currentId = navController.currentChannelId;
    final totalUnread = messagesController.totalUnread;
    return Material(
      elevation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            color: Colors.blueGrey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Chat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (totalUnread > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$totalUnread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const PresenceIndicator(),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final c = channels[index];
                final unread = messagesController.unreadFor(c.id);
                final selected = c.id == currentId;
                return ListTile(
                  selected: selected,
                  selectedTileColor: Colors.blue.shade50,
                  title: Text(
                    c.name,
                    style: TextStyle(
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: unread > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                          ),
                        )
                      : null,
                  onTap: () {
                    navController.open(c.id);
                    messagesController.markAllRead(c.id);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
