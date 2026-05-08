// SPEC §10: a source class that names `implements Disposable` without
// declaring `dispose()` is intentionally unresolved at the source layer —
// the generator synthesizes `dispose()` in the lowered output. The
// analyzer cannot see the synthesized member, so suppress the warning on
// the input fixture.
// ignore_for_file: non_abstract_class_inherits_abstract_member

import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  @SolidState()
  int value = 0;
}
