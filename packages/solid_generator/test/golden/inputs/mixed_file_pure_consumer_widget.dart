// A pure-consumer `StatelessWidget` co-located in the SAME file as the
// annotated class it reads/writes. Whole-file `lowerPureConsumers` only fires
// when NO class in the file is annotated, so this mixed-file shape exercises
// the per-class `lowerPureConsumerClass` path (the no-annotation branch of
// `builder.dart::_resultForClass`). Without it, `counter.count = …` stays
// un-lowered and hits `assignment_to_final` on the generated `final Signal`,
// and the `counter.count` read stays non-reactive (no `SignalBuilder` wrap).
//
// `CounterView` owns no reactive member, so it must NOT be lifted to a
// `StatefulWidget` and must NOT gain `implements Disposable` — a pure consumer
// disposes nothing. Only `.value` lowering + the `build` wrap apply.
import 'package:flutter/widgets.dart';

import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int count = 0;
}

class CounterView extends StatelessWidget {
  const CounterView({required this.counter, super.key});

  final Counter counter;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => counter.count = counter.count + 1,
      child: Text('${counter.count}'),
    );
  }
}
