// The HIDDEN decoy: `main.dart` imports this with `hide Meter`, so this
// class must never be credited as `Meter`'s cross-file `@SolidState`
// source — despite sharing the simple name and carrying its own
// (differently named) reactive field. See issue #104 fix review,
// finding 1b.
import 'package:solid_annotations/solid_annotations.dart';

class Meter {
  @SolidState()
  int wrongField = 0;
}
