// SPEC §3.4 / §4.7 use `print` as the canonical Effect side-effect example.
// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class EffectShadowing extends StatelessWidget {
  EffectShadowing({super.key});

  @SolidState()
  int counter = 0;

  @SolidEffect()
  void logCounter() {
    print('outer: $counter');
    {
      const counter = 'shadowed';
      print('inner: $counter');
    }
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
