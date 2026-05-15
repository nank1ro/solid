import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'backend/chat_backend.dart';
import 'chat_app.dart';
import 'controllers/channels_controller.dart';
import 'controllers/messages_controller.dart';
import 'controllers/navigation_controller.dart';
import 'controllers/session_controller.dart';
import 'controllers/users_controller.dart';

void main() {
  SolidartConfig.autoDispose = false;
  runApp(
    const ChatApp()
        .environment(
          (_) => ChatBackend(),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (_) => SessionController(),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (_) => UsersController(),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (_) => ChannelsController(),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (ctx) =>
              NavigationController(channels: ctx.read<ChannelsController>()),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (ctx) => MessagesController(backend: ctx.read<ChatBackend>()),
          dispose: (context, provider) => provider.dispose(),
        ),
  );
}
