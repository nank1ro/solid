import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:integration_tests/cross_file_env/counter_controller.dart';
import 'package:provider/provider.dart';

class CounterDisplay extends StatefulWidget {
  const CounterDisplay({super.key});

  @override
  State<CounterDisplay> createState() => _CounterDisplayState();
}

class _CounterDisplayState extends State<CounterDisplay> {
  late final counter = context.read<Counter>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SignalBuilder(
            builder: (context, child) {
              return Text('value: ${counter.value.value}');
            },
          ),
          SignalBuilder(
            builder: (context, child) {
              return Text('history-len: ${counter.history.length}');
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          counter.value.value++;
          counter.history.add(counter.value.value);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
