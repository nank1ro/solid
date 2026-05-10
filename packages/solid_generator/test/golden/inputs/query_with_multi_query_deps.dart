// A query body that invokes TWO OR MORE same-class `@SolidQuery` methods
// (and zero `@SolidState` reads) synthesizes a Record-Computed source
// whose tuple contains a `ResourceState<T>` per upstream query (read via
// `<name>.state`). All-query Record case — no state-typed elements
// interleave.
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class TickCombiner extends StatelessWidget {
  TickCombiner({super.key});

  @SolidQuery()
  Stream<int> ticksA() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @SolidQuery()
  Stream<int> ticksB() {
    return Stream.periodic(const Duration(seconds: 2), (i) => i * 10);
  }

  @SolidQuery()
  Future<int> combined() async {
    final a = ticksA().asReady?.value ?? 0;
    final b = ticksB().asReady?.value ?? 0;
    return a + b;
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
