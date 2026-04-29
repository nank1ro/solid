// The abstract class is the whole point of this fixture (M4-04 must reject
// `@SolidEffect` on an abstract method, which can only legally exist inside an
// `abstract class`). Suppress the one-member-abstract-class lint.
// ignore_for_file: one_member_abstracts

import 'package:solid_annotations/solid_annotations.dart';

abstract class Counter {
  @SolidEffect()
  void doThing();
}
