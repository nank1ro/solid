// Top-level cross-class read through an `@SolidEnvironment` receiver.
// Mirrors the chat example's `ChatShell`/`MessagePane` shape where the
// host widget injects a controller and reads one of its reactive fields
// at the build method's statement scope. The outer body wrap must
// subscribe to the receiver's signal, not just emit `.value`.

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Session {
  @SolidState()
  String? userName;
}

class SessionView extends StatelessWidget {
  SessionView({super.key});

  @SolidEnvironment()
  late Session session;

  @override
  Widget build(BuildContext context) {
    final name = session.userName;
    if (name == null) return const Text('signed out');
    return Text('signed in as $name');
  }
}
