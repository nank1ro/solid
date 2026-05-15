// Stream-form @SolidQuery with an `async*` body (yield/yield*). The naive
// `body.keyword?.lexeme` read drops the `*` and emits an `async` closure
// where the body uses `yield*`, which is invalid Dart. This golden locks in
// the joined body-keyword extraction so `async*` round-trips.
//
// Source widgets have non-const constructors uniformly per the
// rest of the corpus; the lift adds `const` on the lowered widget half.
// ignore_for_file: prefer_const_constructors_in_immutables

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter extends StatelessWidget {
  Counter({super.key});

  @SolidQuery()
  Stream<int> countUp() async* {
    yield* Stream<int>.periodic(const Duration(seconds: 1), (i) => i);
  }

  @override
  Widget build(BuildContext context) => const Placeholder();
}
