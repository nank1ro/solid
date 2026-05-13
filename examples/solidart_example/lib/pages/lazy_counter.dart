import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../controllers/lazy_counter.dart';

class LazyCounterPage extends StatefulWidget {
  const LazyCounterPage({super.key});

  @override
  State<LazyCounterPage> createState() => _LazyCounterPageState();
}

class _LazyCounterPageState extends State<LazyCounterPage> {
  late final controller = context.read<LazyCounterController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lazy Counter')),
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return Text(
              controller.lazyCounter.hasValue
                  ? 'Counter: ${controller.lazyCounter.value}'
                  : 'Counter: not initialized',
            );
          },
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
