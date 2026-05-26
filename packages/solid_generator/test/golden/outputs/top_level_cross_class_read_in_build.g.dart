import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Session implements Disposable {
  final userName = Signal<String?>(null, name: 'userName');

  @override
  void dispose() {
    userName.dispose();
  }
}

class SessionView extends StatefulWidget {
  const SessionView({super.key});

  @override
  State<SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends State<SessionView> {
  late final session = context.read<Session>();

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        final name = session.userName.value;
        if (name == null) return const Text('signed out');
        return Text('signed in as $name');
      },
    );
  }
}
