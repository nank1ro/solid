// Build-counting helpers for widget tests. Stateless (not Stateful) is
// deliberate: a `StatelessWidget`'s `build` runs whenever its parent rebuilds,
// which is the metric the SignalBuilder placement tests assert on.

import 'package:flutter/widgets.dart';

class BuildCounter {
  int count = 0;
}

class BuildTracker extends StatelessWidget {
  const BuildTracker({required this.counter, required this.child, super.key});

  final BuildCounter counter;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    counter.count++;
    return child;
  }
}
