// SPEC §14 item 7 clause (c) reject-path: any `AssertInitializer` in the
// init list disqualifies the ctor — the generator preserves the ctor
// declaration verbatim. The `assert(label.isNotEmpty)` here deliberately
// invokes a non-const getter on `String` so analyzer's `canBeConst`
// returns false and the lowered output is also lint-clean
// (`prefer_const_constructors_in_immutables` does not fire).

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Greeter extends StatelessWidget {
  Greeter({super.key, required this.label})
    : assert(label.isNotEmpty, 'label must not be empty');

  final String label;

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Text('$label $counter');
  }
}
