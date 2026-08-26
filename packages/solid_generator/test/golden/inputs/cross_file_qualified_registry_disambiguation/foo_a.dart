// One of two DIFFERENT `Foo` classes sharing a simple name across files
// (issue #110's "ultimate disambiguation proof" — see `main.dart`).
import 'package:solid_annotations/solid_annotations.dart';

class Foo {
  @SolidState()
  String? label;
}
