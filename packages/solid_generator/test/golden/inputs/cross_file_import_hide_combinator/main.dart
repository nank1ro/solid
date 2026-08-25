// Regression fixture for issue #104 fix review, finding 1b: an import that
// `hide`s the wanted type name must never be credited as that name's
// cross-file source, even if it declares an `@SolidState`-bearing class of
// the same simple name. `wrong_meter.dart` is imported FIRST but with
// `hide Meter`, so `Meter` in this file unambiguously resolves to
// `right_meter.dart`'s class (standard Dart combinator semantics) — the
// cross-file registry seeding in `builder.dart::_populateCrossFileTypes`
// must honor that and skip `wrong_meter.dart` when searching for `Meter`.
//
// `hide Meter` hides the only name `wrong_meter.dart` declares, so nothing
// from that import is actually referenced here — the import itself is the
// fixture (its presence, and the builder's handling of it, is what's under
// test), not any name it brings into scope.
// ignore_for_file: unused_import
import 'package:solid_annotations/solid_annotations.dart';

import 'wrong_meter.dart' hide Meter;
import 'right_meter.dart';

class Display {
  Display(this.meter);

  final Meter meter;

  @SolidState()
  int loadCount = 0;

  int describe() {
    loadCount = loadCount + 1;
    return meter.reading;
  }
}
