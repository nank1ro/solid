// A query body that mixes ONE @SolidState read AND ONE @SolidQuery call
// synthesizes a Record-Computed source whose tuple contains both a `T`
// element (state read via `<name>.value`) and a `ResourceState<T>` element
// (query read via `<name>.state`). The synthesized Computed disposes AFTER
// the downstream Resource (reverse-declaration order in dispose()) so the
// Resource tears down its subscription before its source is released.

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class ScaledTickReader extends StatelessWidget {
  ScaledTickReader({super.key});

  @SolidState()
  int divisor = 2;

  @SolidQuery()
  Stream<int> watchTicks() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @SolidQuery()
  Future<double> scaledTick() async {
    return (watchTicks().asReady?.value ?? 0) / divisor.toDouble();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
