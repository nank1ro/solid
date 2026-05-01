// `Base` and `Marker` are abstract by design — the fixture's purpose is to
// exercise the M6-02 implements-clause merge with `extends` + `with` +
// `implements` all present. The lints below would distract from that.
// ignore_for_file: one_member_abstracts

import 'package:solid_annotations/solid_annotations.dart';

abstract class Base {
  String describe();
}

mixin class Tagged {
  String get tag => 'default';
}

abstract class Marker {}

class Sub extends Base with Tagged implements Marker {
  @SolidState()
  int value = 0;

  @override
  String describe() => 'sub';
}
