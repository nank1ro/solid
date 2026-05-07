import 'package:solid_annotations/solid_annotations.dart';

const String appName = 'demo';

class Ticker {
  @SolidState()
  int tick = 0;
}
