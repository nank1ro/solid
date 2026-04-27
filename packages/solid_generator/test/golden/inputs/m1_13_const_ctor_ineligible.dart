import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter extends StatelessWidget {
  Counter({super.key});

  final Stopwatch watch = Stopwatch();

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
