import 'package:solid_annotations/solid_annotations.dart';

class CounterController {
  @SolidState()
  int counter = 0;

  @SolidState()
  int get doubleCounter => counter * 2;

  void increment() => counter++;

  void decrement() => counter--;
}
