import 'package:flutter/foundation.dart';
import 'package:solid_annotations/solid_annotations.dart';

class EffectsController {
  @SolidState()
  int count = 0;

  @SolidEffect()
  void logCount() {
    debugPrint('The count is now $count');
  }

  void increment() => count++;
}
