import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  final counter = Signal<int>(0, name: 'counter');

  void increment() {
    counter.value++;
  }

  @override
  Widget build(BuildContext context) => const Placeholder();

  @override
  void dispose() {
    counter.dispose();
    super.dispose();
  }
}
