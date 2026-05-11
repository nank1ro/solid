import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solidart_example/controllers/counter.dart';

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  late final counterController = CounterController();

  @override
  void dispose() {
    counterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: SignalBuilder(
          builder: (_, _) {
            return Text(
              'Counter: ${counterController.counter.value}\nDouble: ${counterController.doubleCounter.value}',
            );
          },
        ),
      ),
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'subtract hero',
            child: const Icon(Icons.remove),
            onPressed: counterController.decrement,
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: 'add hero',
            child: const Icon(Icons.add),
            onPressed: counterController.increment,
          ),
        ],
      ),
    );
  }
}
