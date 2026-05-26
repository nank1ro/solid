import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../backend/chat_backend.dart';
import '../controllers/navigation_controller.dart';
import '../domain/models.dart';
import 'channel_list_pane.dart';
import 'message_pane.dart';

class ChatShell extends StatefulWidget {
  const ChatShell({super.key});

  @override
  State<ChatShell> createState() => _ChatShellState();
}

class _ChatShellState extends State<ChatShell> {
  StreamSubscription<SystemNotice>? _sysSub;

  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  late final navController = context.read<NavigationController>();

  late final backend = context.read<ChatBackend>();

  late final watchSystemNotices = Effect(() {
    // Reactive dep on currentChannelId so the subscription re-arms on channel
    // switch (closes over the latest navigation context).
    navController.currentChannelId.value;
    _sysSub?.cancel();
    _sysSub = backend.systemNotices().listen((notice) {
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            backgroundColor: notice.kind == SystemNoticeKind.warning
                ? Colors.orange
                : Colors.blueGrey,
            content: Text(notice.message),
          ),
        );
    });
  }, name: 'watchSystemNotices');

  @override
  void dispose() {
    watchSystemNotices.dispose();
    _sysSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        final wide = MediaQuery.sizeOf(context).width >= 720;
        final currentChannelId = navController.currentChannelId.value;
        return ScaffoldMessenger(
          key: _messengerKey,
          child: Scaffold(
            body: SafeArea(
              child: wide
                  ? const Row(
                      children: [
                        SizedBox(width: 260, child: ChannelListPane()),
                        Expanded(child: MessagePane()),
                      ],
                    )
                  : (currentChannelId == null
                        ? const ChannelListPane()
                        : Column(
                            children: [
                              Material(
                                elevation: 1,
                                child: SizedBox(
                                  height: 44,
                                  child: Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.arrow_back),
                                        onPressed: navController.closeCurrent,
                                      ),
                                      const Text('Back to channels'),
                                    ],
                                  ),
                                ),
                              ),
                              const Expanded(child: MessagePane()),
                            ],
                          )),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    watchSystemNotices;
  }
}
