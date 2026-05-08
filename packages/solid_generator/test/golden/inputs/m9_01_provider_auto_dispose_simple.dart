// SPEC §4.9 rule 7. Bare `Provider(create: ..., child: ...)` at top level.
// The generator must inject `dispose: (context, provider) => provider.dispose()`
// before the closing `)`. `Counter` is a Solid-lowered class that gets
// `implements Disposable` + a synthesized `dispose()` in lib/ (Section 10);
// the source-side `void dispose() {}` stub is required so the source layer
// typechecks `provider.dispose()`.
// ignore_for_file: prefer_const_constructors_in_immutables, unreachable_from_main

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

class Counter {
  @SolidState()
  int value = 0;

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
    Provider(
      create: (_) => Counter(),
      child: HomePage(),
    ),
  );
}
