// SPEC §4.9 rule 7. `MultiProvider(...)` itself receives no dispose injection
// — the visitor descends into its `providers:` list and applies the
// per-Provider rule to each entry. Both inner Providers should gain
// `dispose: (context, provider) => provider.dispose()`.
// ignore_for_file: prefer_const_constructors_in_immutables, unreachable_from_main

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class Counter {
  @SolidState()
  int value = 0;

  void dispose() {}
}

class Logger {
  @SolidState()
  int messages = 0;

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
    MultiProvider(
      providers: [
        Provider<Counter>(create: (_) => Counter()),
        Provider<Logger>(create: (_) => Logger()),
      ],
      child: HomePage(),
    ),
  );
}
