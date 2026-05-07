import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter/widgets.dart';

const String appName = 'demo';

class Ticker {
  @SolidState()
  int tick = 0;
}
