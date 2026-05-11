// `@SolidState` getter on a plain (non-Widget) class — Computed lowering
// via the same `emitComputedField` path the stateless rewriter uses. The
// getter declared after the Signal field reads it via the same-class
// `.value` rewrite. Reverse disposal: doubled first, then value.

import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int value = 0;

  @SolidState()
  int get doubled => value * 2;
}
