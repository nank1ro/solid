// A `@SolidQuery` body that mixes ONE same-class `@SolidState` field with ONE
// cross-class `@SolidState` signal (through an `@SolidEnvironment` receiver)
// synthesizes a Record-Computed source field that merges both deps. Same-class
// elements come first in the tuple (matching the visitor's
// `trackedSignalNames`), then cross-class elements
// (`trackedCrossClassSignalNames`); query elements would sit between them in
// the more general case.

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

  @SolidState()
  int seed = 0;

  @SolidQuery()
  Future<int> fetchValue() async => seed + filter.factor;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
