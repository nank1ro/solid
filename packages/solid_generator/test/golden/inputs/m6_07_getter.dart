import 'package:solid_annotations/solid_annotations.dart';

class Counter {}

class Foo {
  @SolidEnvironment()
  Counter get c => Counter();
}
