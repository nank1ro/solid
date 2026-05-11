// Plain class with a user-declared constructor that seeds a `@SolidState`
// `late` field. The body's `value = init` assignment must rewrite to
// `value.value = init` (same-class write rule). The `const` modifier (if
// present on the source ctor) is stripped because the lowered class holds
// a mutable `Signal<int>` field. No Effects, so no synthesized
// materialization read is spliced.

import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  Counter({int init = 0}) {
    value = init;
  }

  @SolidState()
  late int value;
}
