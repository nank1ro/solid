// Plain class with multiple named constructors — each generative one gets
// the merge (initializer-list assignment to a `@SolidState` field is
// rewritten in the body; here the only body is a default `;` body so the
// merge is a no-op aside from `const` stripping).

import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  Counter();

  Counter.seeded(int init) {
    value = init;
  }

  @SolidState()
  late int value;
}
