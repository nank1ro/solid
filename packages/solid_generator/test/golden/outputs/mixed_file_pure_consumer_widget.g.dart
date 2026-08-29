import 'package:flutter/widgets.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  final count = Signal<int>(0, name: 'count');

  @override
  void dispose() {
    count.dispose();
  }
}

class CounterView extends StatelessWidget {
  const CounterView({required this.counter, super.key});

  final Counter counter;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => counter.count.value = counter.count.value + 1,
      child: SignalBuilder(
        builder: (context, child) {
          return Text('${counter.count.value}');
        },
      ),
    );
  }
}
