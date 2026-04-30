// SPEC §3.4 / §4.7 use `print` as the canonical Effect side-effect example.
// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';

class Counter {
  @SolidState()
  int value = 0;

  @SolidEffect()
  void log() {
    print('value: $value');
  }

  @SolidQuery()
  Future<int> fetchSnapshot() async => 0;
}
