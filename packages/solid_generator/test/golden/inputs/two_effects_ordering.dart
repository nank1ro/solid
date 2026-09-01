// The effect bodies below use `print` to make ordering observable in the
// lowered output; that's the point of this fixture, not a mistake.
// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';

// Two `@SolidEffect` methods on one class: locks in that both the field
// declarations and the materialization assignments are emitted in
// source-declaration order (`first` before `second`), so a future change to
// the effect walk order is caught. Plain class → the synthesized constructor
// carries both assignments.
class Counter {
  @SolidState()
  int count = 0;

  @SolidEffect()
  void first() {
    print('first: $count');
  }

  @SolidEffect()
  void second() {
    print('second: $count');
  }
}
