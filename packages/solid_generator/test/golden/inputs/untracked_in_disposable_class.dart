import 'package:solid_annotations/solid_annotations.dart';

// A plain class with reactive fields lowers to `implements Disposable`, which
// keeps the `solid_annotations` import in the output. It also calls the
// `untracked(...)` function (which resolves to `flutter_solidart`'s). Both
// packages export `untracked`, so the generator must hide it from the retained
// `solid_annotations` import.
class HistoryController {
  @SolidState()
  int counter = 0;

  @SolidState()
  List<int> history = [];

  @SolidEffect()
  void record() {
    final c = counter;
    untracked(() => history = [...history, c]);
  }
}
