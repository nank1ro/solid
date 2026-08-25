// The REAL `Meter` that `main.dart`'s `hide Meter` on the wrong_meter.dart
// import leaves visible. See issue #104 fix review, finding 1b.
import 'package:solid_annotations/solid_annotations.dart';

class Meter {
  @SolidState()
  int reading = 0;
}
