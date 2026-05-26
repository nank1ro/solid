// User-authored method on a pre-existing State<X> subclass that mutates a
// same-class @SolidState field. The rewriter must run the same value-rewrite
// over this method's body that it runs over `build`/Effect/Query bodies, so
// `counter++` (which lowers to a setter on a final Signal) becomes
// `counter.value++` (the supported in-place increment). Mirror of
// `plain_class_user_ctor_basic` for State<X>.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter extends StatefulWidget {
  const Counter({super.key});

  @override
  State<Counter> createState() => _CounterState();
}

class _CounterState extends State<Counter> {
  @SolidState()
  int counter = 0;

  void increment() {
    counter++;
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
