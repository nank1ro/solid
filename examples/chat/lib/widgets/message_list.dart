import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../controllers/messages_controller.dart';
import '../controllers/users_controller.dart';
import '../domain/models.dart';

class MessageList extends StatefulWidget {
  const MessageList({super.key, required this.channelId});

  final String channelId;

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  late final messagesController = context.read<MessagesController>();

  late final usersController = context.read<UsersController>();

  final _scrollController = ScrollController();

  bool _atBottom = true;

  @override
  void initState() {
    super.initState();
    keepChannelRead;
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    keepChannelRead.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  late final keepChannelRead = Effect(() {
    // While this channel is on screen, mark its messages read as they arrive —
    // the sidebar must never show an unread badge for the channel you're
    // viewing. The bare read below is the effect's dependency; the write goes
    // through `untracked` to avoid a cyclic reaction (marking read writes the
    // `readIds` collection signal, which would otherwise re-trigger this effect).
    messagesController.channelMessages[widget.channelId];
    untracked(() => messagesController.markAllRead(widget.channelId));
  }, name: 'keepChannelRead');

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    // With `reverse: true`, offset 0 is the visual bottom (newest message).
    // The list stays pinned there as new messages arrive, so no manual
    // auto-scroll is needed — the offset only drives the chip's visibility.
    final atBottom = _scrollController.position.pixels <= 24;
    if (atBottom != _atBottom) {
      setState(() => _atBottom = atBottom);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        // Read the reactive atoms in build's own scope so the generated
        // SignalBuilder tracks them. The itemBuilder below is a separate
        // function — reads performed inside it would not be tracked.
        final messages =
            messagesController.channelMessages[widget.channelId] ??
            const <Message>[];
        final users = usersController.users.value;
        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'No messages yet — say hello',
              style: TextStyle(color: Colors.black54),
            ),
          );
        }
        final count = messages.length;
        return Stack(
          children: [
            ListView.builder(
              controller: _scrollController,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: count,
              itemBuilder: (context, index) {
                // `reverse: true` flips the order: index 0 is the bottom-most
                // (newest) row, so read the underlying list from the end.
                final m = messages[count - 1 - index];
                return _MessageRow(message: m, user: users[m.senderId]);
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 12,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _atBottom
                      ? const SizedBox.shrink(
                          key: ValueKey('scroll-to-bottom-hidden'),
                        )
                      : _ScrollToBottomChip(
                          key: const ValueKey('scroll-to-bottom'),
                          onTap: _scrollToBottom,
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScrollToBottomChip extends StatelessWidget {
  const _ScrollToBottomChip({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.78),
      elevation: 4,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.white70),
              SizedBox(width: 6),
              Text(
                'Scroll to bottom',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
