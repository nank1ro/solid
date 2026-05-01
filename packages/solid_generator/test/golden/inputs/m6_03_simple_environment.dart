// SPEC §3.6 uses a non-Solid `Logger` as the canonical injected type for
// the simple-environment lowering example. `Logger.log` calls `print` for
// minimal noise; `Text('hello')` is intentionally non-const so the build
// body round-trips byte-identical (the generator never const-ifies — that's
// `dart fix --apply`'s job at the consumer-app level).
// ignore_for_file: avoid_print, prefer_const_constructors

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Logger {
  void log(String message) => print(message);
}

class HomePage extends StatelessWidget {
  HomePage({super.key});

  @SolidEnvironment()
  late Logger logger;

  @override
  Widget build(BuildContext context) {
    return Text('hello');
  }
}
