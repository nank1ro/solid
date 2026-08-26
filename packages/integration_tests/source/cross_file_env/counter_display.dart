// Cross-file env-injection consumer — imports `Counter` from a sibling
// source file via a relative URI. The generator's resolver pass redirects
// relative source imports to their `lib/` counterparts so the
// `@SolidState` annotations are visible to the rewriter even though the
// import resolves to `lib/cross_file_env/...` post-build.

import 'package:flutter/material.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'counter_controller.dart';

class CounterDisplay extends StatelessWidget {
  CounterDisplay({super.key});

  @SolidEnvironment()
  late Counter counter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('value: ${counter.value}'),
          Text('history-len: ${counter.history.length}'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          counter.value++;
          counter.history.add(counter.value);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
