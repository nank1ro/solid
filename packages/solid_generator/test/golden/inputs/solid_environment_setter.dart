import 'package:solid_annotations/solid_annotations.dart';

class Counter {}

class Foo {
  @SolidEnvironment()
  set c(Counter v) {}
}
