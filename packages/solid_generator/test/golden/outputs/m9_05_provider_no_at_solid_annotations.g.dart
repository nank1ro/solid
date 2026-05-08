// SPEC §4.9 rule 7. The auto-dispose pass must run on files WITHOUT any
// `@Solid*` annotation — a top-level `main()` that wires `Provider(...)` is
// the canonical app-entry shape and must receive the injection.
// ignore_for_file: unreachable_from_main

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class Counter {
  void dispose() {}
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

void main() {
  runApp(
    Provider(
      create: (_) => Counter(),
      child: const HomePage(),
      dispose: (context, provider) => provider.dispose(),
    ),
  );
}
