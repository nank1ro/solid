// Cross-file env-injection runtime fence — the `Counter` plain class side.
// Defines `@SolidState` scalar AND collection fields so the runtime suite
// exercises both the scalar `.value.value` chain rewrite AND the
// collection no-`.value` chain rewrite when the receiver is an env field
// resolved across file boundaries.

import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int value = 0;

  @SolidState()
  List<int> history = const [];

  // Empty stub — the source-layer analyzer needs to resolve `c.dispose()` in
  // the `.environment<Counter>(... dispose: (_, c) => c.dispose())` callback.
  // The generator merges synthesized disposals into this body.
  void dispose() {}
}
