import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  final value = Signal<int>(0, name: 'value');

  void increment() => value++;

  void dispose() {
    value.dispose();
  }
}

void main() {
  SolidartConfig.autoDispose = false;
  runApp(
    MaterialApp(
      home: SolidProvider(
        create: (context) => Counter.new,
        child: CounterPage(),
      ),
    ),
  );
}

class CounterPage extends StatefulWidget {
  CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  late final Counter counter = context.read<Counter>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return Text(counter.value.value.toString());
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: counter.increment,
        child: const Icon(Icons.add),
      ),
    );
  }
}
