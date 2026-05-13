import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/counter.dart';

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @SolidEnvironment()
  late CounterController counterController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Text(
          'Counter: ${counterController.counter}\n'
          'Double: ${counterController.doubleCounter}',
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'subtract hero',
            onPressed: counterController.decrement,
            child: const Icon(Icons.remove),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: 'add hero',
            onPressed: counterController.increment,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
