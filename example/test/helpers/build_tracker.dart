// Helpers for counting widget rebuilds in M1-10 / M1-11 / M3-04 widget tests.
// See plans/features/m1-solid-state-field.md "Test helpers" note.
//
// `BuildCounter` is a tiny mutable holder with a single `count` field; tests
// instantiate one per tracked widget and read `count` directly. `BuildTracker`
// is a `StatelessWidget` that increments the holder on every `build` and
// returns its `child` unchanged. Stateless (not Stateful) is deliberate: a
// `StatelessWidget`'s `build` method is invoked whenever its parent rebuilds,
// which is exactly the metric we want.

import 'package:flutter/widgets.dart';

/// Mutable holder for a rebuild count. One instance per tracked widget.
class BuildCounter {
  /// Number of times the associated [BuildTracker] has been built.
  int count = 0;

  /// Resets [count] to zero. Tests typically prefer fresh instances over
  /// reuse, but this is provided for symmetry.
  void reset() => count = 0;
}

/// Wraps [child] and increments [counter] each time `build` is invoked.
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
