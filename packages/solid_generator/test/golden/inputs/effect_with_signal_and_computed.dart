// SPEC §3.4 / §4.7 use `print` as the canonical Effect side-effect example.
// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class EffectWithDeps extends StatelessWidget {
  EffectWithDeps({super.key});

  @SolidState()
  int counter = 0;

  @SolidState()
  int get doubleCounter => counter * 2;

  @SolidEffect()
  void logBoth() {
    print('$counter / $doubleCounter');
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
