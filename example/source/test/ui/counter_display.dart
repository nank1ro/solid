import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int value = 0;
  void dispose() {}
}

class CounterDisplay extends StatelessWidget {
  CounterDisplay({super.key});

  @SolidEnvironment()
  late Counter counter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Counter is ${counter.value}')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          counter.value += 1;
        },
      ),
    );
  }
}
