// The REAL, `@SolidState`-annotated `UnitsController` — same simple name as
// the decoy in `decoy.dart`, imported by `main.dart` AFTER the decoy. If
// `_populateCrossFileTypes` stops searching on the first same-simple-name
// class it sees (the decoy), this class is never scanned and the
// `classRegistry` never learns that `UnitsController` is Solid-lowered.
import 'package:solid_annotations/solid_annotations.dart';

class UnitsController {
  @SolidState()
  int count = 0;
}
