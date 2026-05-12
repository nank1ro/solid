// Cross-file @SolidState host. Imported by `widget.dart` via
// `package:a/cross_file_environment_read/controllers.dart` — the builder's
// resolver pass redirects same-package `lib/` URIs to `source/` so the
// pre-transformation annotations are visible to the cross-class chain
// rewrite running on `widget.dart`.

import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int value = 0;

  @SolidState()
  List<int> history = [];
}
