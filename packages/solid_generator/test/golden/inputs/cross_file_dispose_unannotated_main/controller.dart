// Cross-file `@SolidState` controller — the annotated type lives here, not
// in `main.dart`. Its `lib/` output always synthesizes `dispose()` /
// `implements Disposable` (Section 10), but that synthesis has NOT happened
// yet when `main.dart` is scanned for auto-dispose injection — this file's
// pre-lowering source class carries the `@SolidState` annotation but no
// `dispose()` method of its own.

import 'package:solid_annotations/solid_annotations.dart';

class CitiesController {
  @SolidState()
  int count = 0;
}
