// Cross-file @SolidEnvironment consumer. The injected `Counter` is defined
// in `controllers.dart` (same package, different file). The build body must
// rewrite `counter.value` → `counter.value.value` (scalar `@SolidState`
// chain rewrite) AND `counter.history.length` MUST NOT receive a `.value`
// insertion (the cross-file collection field is a `ListSignal<int>` whose
// `ListMixin.length` is reached through the receiver chain directly).
// Both reads are wrapped in `SignalBuilder`.

// Same-package imports must be relative (SPEC §2) — `controllers.dart` is a
// sibling source file in the multi-file golden harness.

import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

import 'controllers.dart';

class Display extends StatelessWidget {
  Display({super.key});

  @SolidEnvironment()
  late Counter counter;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('value: ${counter.value}'),
        Text('history-len: ${counter.history.length}'),
      ],
    );
  }
}
