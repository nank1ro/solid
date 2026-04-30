// SPEC §4.8 Stream-form query: a synchronous block body returning a Stream.
// `Stream.periodic` produces an integer stream ticking every second.
// `Ticker` has only a query (no mutable `@SolidState` field) so its
// constructor could be const before lowering, but the SPEC §2 source model
// writes user-facing widgets with non-const constructors uniformly.
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Ticker extends StatelessWidget {
  Ticker({super.key});

  @SolidQuery()
  Stream<int> watchTicks() {
    return Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
