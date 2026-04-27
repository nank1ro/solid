import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter extends StatefulWidget {
  Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  final counter = Signal<int>(0, name: 'counter');
  late final doubleCounter = Computed<int>(
    () => counter.value * 2,
    name: 'doubleCounter',
  );

  @override
  void dispose() {
    doubleCounter.dispose();
    counter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SignalBuilder(
        builder: (context, child) {
          return Text('${doubleCounter.value}');
        },
      ),
    );
  }
}
