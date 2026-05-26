import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  late final countUp = Resource<int>.stream(() async* {
    yield* Stream<int>.periodic(const Duration(seconds: 1), (i) => i);
  }, name: 'countUp');

  @override
  void dispose() {
    countUp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
