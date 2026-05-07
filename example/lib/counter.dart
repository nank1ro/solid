import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});

  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final counter = Signal<int>(0, name: 'counter');
  late final doubleCounter = Computed<int>(
    () => counter.value * 2,
    name: 'doubleCounter',
  );
  late final logCounter = Effect(() {
    print('Counter updated: ${counter.value}');
  }, name: 'logCounter');

  @override
  void initState() {
    super.initState();
    logCounter;
  }

  @override
  void dispose() {
    logCounter.dispose();
    doubleCounter.dispose();
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SignalBuilder(
          builder: (context, child) {
            return Text(
              'Counter is ${counter.value}, double is ${doubleCounter.value}',
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
