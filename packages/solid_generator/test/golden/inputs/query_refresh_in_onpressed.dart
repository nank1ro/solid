// Tear-off `fetchCount.refresh()` inside an `onPressed` callback. Source
// typechecks via the `RefreshFuture<T> on Future<T> Function()` stub
// extension in `solid_annotations`. The tear-off is byte-identical between
// input and output because the call-expression rewrite fires only on
// zero-arg `MethodInvocation` shapes (`fetchCount()`), NOT on
// tear-off-then-method-call shapes (`fetchCount.refresh()`). The FAB is
// NOT wrapped in `SignalBuilder` — `onPressed` matches the
// untracked-context callback pattern. The `() => fetchCount.refresh()`
// lambda matches the canonical Refresh example verbatim, so
// `unnecessary_lambdas` is silenced.
// ignore_for_file: prefer_const_constructors_in_immutables, unnecessary_lambdas

import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/material.dart';

class CounterScreen extends StatelessWidget {
  CounterScreen({super.key});

  @SolidQuery()
  Future<int> fetchCount() async => 0;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => fetchCount.refresh(),
      child: const Icon(Icons.refresh),
    );
  }
}
