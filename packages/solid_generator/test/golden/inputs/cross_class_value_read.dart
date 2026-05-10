// First cross-class `@SolidEnvironment` golden — `Counter` carries a
// `@SolidState` field and is injected into `CounterDisplay` via
// `@SolidEnvironment`. The build body's `counter.value` must rewrite to
// `counter.value.value` (chain-aware rule, env-field receiver shape)
// and the enclosing `Text(...)` must be wrapped in a `SignalBuilder`. `Text(counter.value.toString())` is non-const by construction (the
// argument is a method call), so no `prefer_const_constructors` ignore is
// needed.

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter {
  @SolidState()
  int value = 0;
}

class CounterDisplay extends StatelessWidget {
  CounterDisplay({super.key});

  @SolidEnvironment()
  late Counter counter;

  @override
  Widget build(BuildContext context) {
    return Text(counter.value.toString());
  }
}
