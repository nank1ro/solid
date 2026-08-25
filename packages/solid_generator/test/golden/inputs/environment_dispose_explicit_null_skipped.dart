// Regression lock: explicit `dispose: null` is a valid opt-out — the visitor
// must not touch the call site (no double injection, no removal). `Counter`
// carries `@SolidState` so this file goes through the main lowering
// pipeline, same shape as the other `environment_dispose_*` goldens.
// `dispose: null` matches the parameter's default, hence the second ignore —
// this is exactly the load-bearing-`dispose: null` shape the type-aware
// auto-injection (FIX 2) exists to make optional, not mandatory.
// ignore_for_file: prefer_const_constructors_in_immutables, avoid_redundant_argument_values

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

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

class App extends StatelessWidget {
  App({super.key});

  @override
  Widget build(BuildContext context) {
    return HomePage().environment<Counter>((_) => Counter(), dispose: null);
  }
}
