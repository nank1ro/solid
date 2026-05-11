import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solidart_example/controllers/lazy_counter.dart';

class LazyCounterPage extends StatefulWidget {
  const LazyCounterPage({super.key});

  @override
  State<LazyCounterPage> createState() => _LazyCounterPageState();
}

class _LazyCounterPageState extends State<LazyCounterPage> {
  late final controller = LazyCounterController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lazy Counter')),
      body: Center(
        child: SignalBuilder(
          builder: (_, _) {
            return switch (controller.lazyCounter.hasValue) {
              true => Text('Counter: ${controller.lazyCounter.value}'),
              false => const Text('Counter: not initialized'),
            };
          },
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'subtract hero',
            child: const Icon(Icons.remove),
            onPressed: controller.decrement,
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: 'add hero',
            child: const Icon(Icons.add),
            onPressed: controller.increment,
          ),
        ],
      ),
    );
  }
}
