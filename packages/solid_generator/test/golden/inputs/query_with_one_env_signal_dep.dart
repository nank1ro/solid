// A `@SolidQuery` body that reads exactly ONE cross-class `@SolidState` signal
// through an `@SolidEnvironment`-injected receiver passes that Signal directly
// as the Resource's `source:` argument (no synthesized wrapper Computed, since
// `Computed(() => signal.value)` would be a no-op). Mirrors the same-class
// `query_with_one_signal_dep` golden but the single dep is reached through
// an env receiver instead of a same-class field.

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Filter {
  @SolidState()
  int factor = 1;
}

class ValueCard extends StatelessWidget {
  ValueCard({super.key});

  @SolidEnvironment()
  late Filter filter;

  @SolidQuery()
  Future<int> fetchValue() async => 10 * filter.factor;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
