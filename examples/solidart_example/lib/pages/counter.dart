import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import '../controllers/counter.dart';

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  late final counterController = context.read<CounterController>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return Text(
              'Counter: ${counterController.counter.value}\n'
              'Double: ${counterController.doubleCounter.value}',
            );
          },
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
