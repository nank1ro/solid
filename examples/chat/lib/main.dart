import 'package:flutter/material.dart';
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
  // `.environment(X)` wraps the receiver in `Provider<X>(child: receiver)`,
  // so X ends up ABOVE the receiver in the widget tree. For a Provider's
  // `create` callback to find a dependency via `ctx.read<T>()`, the
  // dependency must be ABOVE — i.e. its `.environment(...)` call must
  // appear LATER in the chain (the last call is the outermost provider).
  //
  // Order below:
  //   * NavigationController (consumer of ChannelsController) goes first
  //   * ChannelsController goes after so it ends up above
  //   * MessagesController (consumer of ChatBackend) goes before ChatBackend
  //   * ChatBackend goes last so it ends up at the top
  runApp(
    const ChatApp()
        .environment(
          (ctx) =>
              NavigationController(channels: ctx.read<ChannelsController>()),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (ctx) => MessagesController(backend: ctx.read<ChatBackend>()),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (_) => UsersController(),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (_) => SessionController(),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (_) => ChannelsController(),
          dispose: (context, provider) => provider.dispose(),
        )
        .environment(
          (_) => ChatBackend(),
          dispose: (context, provider) => provider.dispose(),
        ),
  );
}
