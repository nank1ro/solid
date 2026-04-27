import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

class Counter extends StatelessWidget {
  Counter({super.key, this.title = 'Counter'});

  Counter.named({super.key}) : title = 'Named';

  factory Counter.fromInt(int value) {
    return Counter(title: 'count=$value');
  }

  final String title;

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) => const Placeholder();
}
