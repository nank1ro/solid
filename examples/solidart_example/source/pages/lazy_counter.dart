import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import '../controllers/lazy_counter.dart';

class LazyCounterPage extends StatelessWidget {
  const LazyCounterPage({super.key});

  @SolidEnvironment()
  late LazyCounterController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lazy Counter')),
      body: Center(
        child: Text(
          controller.lazyCounter.hasValue
              ? 'Counter: ${controller.lazyCounter}'
              : 'Counter: not initialized',
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'subtract hero',
            onPressed: controller.decrement,
            child: const Icon(Icons.remove),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: 'add hero',
            onPressed: controller.increment,
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
