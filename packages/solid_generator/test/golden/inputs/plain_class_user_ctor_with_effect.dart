// Plain class with a user-declared constructor AND an `@SolidEffect` —
// the merge must (a) preserve the user's body verbatim with `.value`
// rewrites applied, AND (b) splice an `<effectName>;` materialization
// read at the end of the body so the Effect's `late final` initialiser
// runs during construction (the plain-class analogue of the State class's
// `initState()` splice).

// `print` is used as the Effect's canonical side-effect demonstration.
// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  Counter({int init = 0}) {
    value = init;
  }

  @SolidState()
  late int value;

  @SolidEffect()
  void log() {
    print('value: $value');
  }
}
