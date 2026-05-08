// SPEC §3.4 / §4.7 use `print` as the canonical Effect side-effect example.
// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidState()
  int counter = 0;

  @SolidEffect()
  void logCounter() {
    print('Counter changed: $counter');
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
