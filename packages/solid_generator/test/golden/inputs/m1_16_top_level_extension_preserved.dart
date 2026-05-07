import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

extension StringX on String {
  String get bold => '*$this*';
}

class Ticker {
  @SolidState()
  int tick = 0;
}
