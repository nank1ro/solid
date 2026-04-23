import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int count = 0;

  void increment() => count++;
}

void main() {
  runApp(
    MaterialApp(
      home: SolidProvider(
        create: (context) => Counter.new,
        child: CounterPage(),
      ),
    ),
  );
}

class CounterPage extends StatelessWidget {
  CounterPage({super.key});

  @SolidEnvironment()
  late final Counter counter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(counter.count.toString()),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: counter.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
