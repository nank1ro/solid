// Cross-file @SolidEnvironment consumer. The injected `Counter` is defined
// in `controllers.dart` (same package, different file). The build body must
// rewrite `counter.value` → `counter.value.value` (scalar `@SolidState`
// chain rewrite) AND `counter.history.length` MUST NOT receive a `.value`
// insertion (the cross-file collection field is a `ListSignal<int>` whose
// `ListMixin.length` is reached through the receiver chain directly).
// Both reads are wrapped in `SignalBuilder`.

// The `package:a/...` import is a `build_test`-synthesised package URI —
// the analyzer cannot resolve it outside the multi-file golden harness,
// so the `uri_does_not_exist` / `undefined_class` errors are expected
// here and suppressed.
// ignore_for_file: uri_does_not_exist, undefined_class

import 'package:a/cross_file_environment_read/controllers.dart';
import 'package:flutter/widgets.dart';
import 'package:solid_annotations/solid_annotations.dart';

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
