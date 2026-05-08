import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class CounterPage extends StatelessWidget {
  CounterPage({super.key});

  @SolidState()
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Counter is $counter')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
