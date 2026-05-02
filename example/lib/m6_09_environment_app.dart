import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';

class Counter implements Disposable {
  final value = Signal<int>(0, name: 'value');

  @override
  void dispose() {
    value.dispose();
  }
}

class CounterDisplay extends StatefulWidget {
  const CounterDisplay({super.key});

  @override
  State<CounterDisplay> createState() => _CounterDisplayState();
}

class _CounterDisplayState extends State<CounterDisplay> {
  late final Counter counter = context.read<Counter>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return Text('Counter is ${counter.value.value}');
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.value.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
