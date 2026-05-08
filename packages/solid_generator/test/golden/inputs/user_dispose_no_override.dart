// SPEC §10 example uses `print` as the user-dispose-body sample statement.
// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int value = 0;

  void dispose() {
    print('counter cleanup');
  }
}
