import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  static int get x => 0;
}
