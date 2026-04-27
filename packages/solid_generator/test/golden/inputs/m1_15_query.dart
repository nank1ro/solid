import 'package:solid_annotations/solid_annotations.dart';

class Foo {
  @SolidQuery()
  Future<int> fetch() async => 0;
}
