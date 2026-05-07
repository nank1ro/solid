import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class CounterPage extends StatelessWidget {
  CounterPage({super.key});

  @SolidState()
  int counter = 0;

  @SolidState()
  int get doubleCounter => counter * 2;

  @SolidEffect()
  void logCounter() {
    print('Counter updated: $counter');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Counter is $counter, double is $doubleCounter'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
