// The source already hides one (unused) `solid_annotations` export. The class
// keeps the import (it lowers to `implements Disposable`) and also calls
// `untracked(...)` (resolving to `flutter_solidart`'s). The generator must hide
// `untracked` too, MERGING it into the existing `hide` clause rather than
// emitting a second `hide` (which would warn `multiple_combinators`).
import 'package:solid_annotations/solid_annotations.dart'
    hide LazyStateExtension;

class FilteredController {
  @SolidState()
  int counter = 0;

  @SolidState()
  List<int> log = [];

  @SolidEffect()
  void record() {
    final c = counter;
    untracked(() => log = [...log, c]);
  }
}
