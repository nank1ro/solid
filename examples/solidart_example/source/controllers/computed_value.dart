import 'package:solid_annotations/solid_annotations.dart';

class ComputedValueController {
  @SolidState()
  int count = 0;

  @SolidState()
  int get doubleCount => count * 2;

  void increment() => count++;
}
