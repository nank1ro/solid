// M6-09 — end-to-end source for the `.environment<T>()` + `@SolidEnvironment`
// + dispose widget test. Mirrors the M6-04 cross-class read shape (golden
// input `m6_04_cross_class_value_read.dart`) extended with a FAB so the test
// can drive a tap, plus an empty `dispose()` stub on `Counter` (M6-02
// `user_dispose_no_override` shape with empty body) so the source-layer
// analyzer can resolve `c.dispose()` in the `.environment` callback.

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int value = 0;

  // Empty stub. The source-layer analyzer needs to resolve `c.dispose()` in
  // the `.environment<Counter>(... dispose: (_, c) => c.dispose())` callback;
  // it cannot see the `Disposable` interface that the generator emits in
  // `lib/`. The generator merges the synthesized `value.dispose()` into this
  // body per SPEC §10 (M6-02 dispose-body merge for plain classes).
  void dispose() {}
}

class CounterDisplay extends StatelessWidget {
  CounterDisplay({super.key});

  @SolidEnvironment()
  late Counter counter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('Counter is ${counter.value}')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => counter.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
