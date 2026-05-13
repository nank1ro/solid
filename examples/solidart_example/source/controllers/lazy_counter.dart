import 'package:solid_annotations/solid_annotations.dart';

class LazyCounterController {
  @SolidState()
  late int lazyCounter;

  void increment() {
    lazyCounter = lazyCounter.hasValue ? lazyCounter + 1 : 0;
  }

  void decrement() {
    lazyCounter = lazyCounter.hasValue ? lazyCounter - 1 : 0;
  }
}
