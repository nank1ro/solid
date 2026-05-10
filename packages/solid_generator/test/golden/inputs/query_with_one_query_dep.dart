// SPEC §3.5 "Auto-tracking of upstream queries" / §4.8 rule 5: a query body
// that invokes ONE same-class `@SolidQuery` (and zero `@SolidState` reads)
// passes the upstream Resource directly as `source:` — no synthesized
// Record-Computed wrapper is needed. The downstream Resource is wired
// reactively via the upstream's emissions because `Resource<T>` extends
// `Signal<ResourceState<T>>` and qualifies as a `SignalBase<dynamic>` source.
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class TickReader extends StatelessWidget {
  TickReader({super.key});

  @SolidQuery()
  Stream<int> watchTicks() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @SolidQuery()
  Future<double> halveLatestTick() async {
    return (watchTicks().asReady?.value ?? 0).toDouble() / 2.0;
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
