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

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        // Hoist signal reads OUT of ListView.builder's deferred `itemBuilder`
        // closure — that closure runs after the wrapping SignalBuilder has
        // stopped tracking, so a read inside it never subscribes. Reading at
        // the build method's statement scope keeps the read inside the outer
        // SignalBuilder that the generator synthesizes around the whole build
        // body (SPEC §7.1 unanchored case).
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
        return _MessageScrollList(messages: messages, users: users);
      },
    );
  }
}

/// Manages the scroll position of the message list. Auto-scrolls to the
/// bottom when new messages arrive AND the user was already at the bottom;
/// shows a floating "scroll to bottom" button when the user has scrolled
/// up (so new incoming messages don't yank them out of context).
class _MessageScrollList extends StatefulWidget {
  const _MessageScrollList({required this.messages, required this.users});

  final List<Message> messages;
  final Map<String, User> users;

  @override
  State<_MessageScrollList> createState() => _MessageScrollListState();
}

class _MessageScrollListState extends State<_MessageScrollList> {
  final _controller = ScrollController();
  bool _atBottom = true;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(_MessageScrollList oldWidget) {
    super.didUpdateWidget(oldWidget);
    // With `reverse: true`, the ListView's newest items live at scroll
    // position 0 (the visual bottom). When new messages arrive AND the
    // user is pinned to the bottom, animate from the small jitter back
    // to 0 so the new row stays visible. If they scrolled up to read
    // older history, the FAB takes over.
    final grew = widget.messages.length > oldWidget.messages.length;
    if (grew && _atBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    // With `reverse: true`, `pixels == 0` is the bottom (newest message).
    // 24px tolerance for fractional offsets.
    final atBottom = pos.pixels <= 24;
    if (atBottom != _atBottom) {
      setState(() => _atBottom = atBottom);
    }
  }

  void _animateToBottom() {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.messages.length;
    return Stack(
      children: [
        ListView.builder(
          controller: _controller,
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: count,
          itemBuilder: (context, index) {
            // `reverse: true` flips the visual order. Index 0 is the
            // bottom-most visual row, which we want to be the NEWEST
            // message — so iterate the underlying list from the end.
            final m = widget.messages[count - 1 - index];
            final user = widget.users[m.senderId];
            return _MessageRow(message: m, user: user);
          },
        ),
        // Positioned must be a direct Stack child — wrapping it in
        // AnimatedSwitcher would strip the absolute positioning. So the
        // Positioned stays outside the switcher, and the switcher animates
        // the chip's appearance / disappearance INSIDE it.
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
                      onTap: _animateToBottom,
                    ),
            ),
          ),
        ),
      ],
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
