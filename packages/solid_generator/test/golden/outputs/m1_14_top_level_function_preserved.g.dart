import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:provider/provider.dart';
import 'package:solid_annotations/solid_annotations.dart';

void main() {
  runApp(
    MaterialApp(
      home: const CounterDisplay().environment(
        (_) => Counter(),
        dispose: (context, provider) => provider.dispose(),
      ),
    ),
  );
}

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
  late final counter = context.read<Counter>();

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, child) {
        return Text(counter.value.value.toString());
      },
    );
  }
}
