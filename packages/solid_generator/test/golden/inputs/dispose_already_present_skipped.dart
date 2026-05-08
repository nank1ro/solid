// SPEC §4.9 rule 7. When the user supplies `dispose:` explicitly the visitor
// MUST NOT inject a second argument — even if the user's callback names a
// non-default cleanup method.
// ignore_for_file: prefer_const_constructors_in_immutables, unreachable_from_main

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class Counter {
  @SolidState()
  int value = 0;

  void close() {}

  void dispose() {}
}

class HomePage extends StatelessWidget {
  HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

void main() {
  runApp(
    Provider<Counter>(
      create: (_) => Counter(),
      dispose: (_, c) => c.close(),
      child: HomePage(),
    ),
  );
}
