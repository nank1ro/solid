import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(
    MaterialApp(home: CounterDisplay().environment((_) => Counter())),
  );
}

class Counter {
  @SolidState()
  int value = 0;
}

class CounterDisplay extends StatelessWidget {
  CounterDisplay({super.key});

  @SolidEnvironment()
  late Counter counter;

  @override
  Widget build(BuildContext context) {
    return Text(counter.value.toString());
  }
}
