// GENERATED FILE — DO NOT EDIT BY HAND.
// Source: source/counter.dart
// The user attempted to change the AppBar title from 'Counter' to 'My Counter'
// directly in this file. build_runner's next run will overwrite their change.
import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final counter = Signal<int>(0, name: 'counter');

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Counter')), // user's mis-edit, will be overwritten
      body: Center(
        child: SignalBuilder(
          builder: (context, _) => Text('Counter is ${counter.value}'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
