// Multi-`@SolidEnvironment` golden — `Counter` (Solid-lowered, carries
// `@SolidState int value`) and `Logger` (plain class) are both injected
// into `CounterDisplay`. Locks SPEC §3.6 + §4.9 rule 2: two independent
// `late final ... = context.read<T>();` field declarations in source-
// declaration order, no `initState` splice. Locks §5.1 per-field cross-
// class rewrite (counter gets `.value` appended; logger left alone — `log`
// is not in `Logger`'s reactive-field set). Locks §7 SignalBuilder
// placement (wraps only the tracked `Text` expression; `logger.log(...)`
// stays outside the builder closure).
// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter {
  @SolidState()
  int value = 0;
}

class Logger {
  void log(String message) => print(message);
}

class CounterDisplay extends StatelessWidget {
  CounterDisplay({super.key});

  @SolidEnvironment()
  late Counter counter;

  @SolidEnvironment()
  late Logger logger;

  @override
  Widget build(BuildContext context) {
    logger.log('build');
    return Text(counter.value.toString());
  }
}
