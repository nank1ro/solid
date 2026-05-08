import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int value = 0;

  @SolidState()
  String label = '';
}
