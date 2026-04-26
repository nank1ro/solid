import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Ticker {
  final tick = Signal<int>(0, name: 'tick');

  void dispose() {
    tick.dispose();
  }
}
