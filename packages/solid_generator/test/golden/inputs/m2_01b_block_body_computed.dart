import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidState()
  int counter = 0;

  @SolidState()
  String get summary {
    final c = counter;
    return 'count is $c';
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
