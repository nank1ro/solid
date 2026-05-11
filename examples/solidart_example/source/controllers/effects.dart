// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';

class EffectsController {
  @SolidState()
  int count = 0;

  @SolidEffect()
  void logCount() {
    print('The count is now $count');
  }

  void increment() => count++;
}
