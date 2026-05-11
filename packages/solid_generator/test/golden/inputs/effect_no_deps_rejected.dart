// Uses `print` as the canonical Effect side-effect example.
// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';

class Foo {
  @SolidEffect()
  void doThing() {
    print('no signals here');
  }
}
