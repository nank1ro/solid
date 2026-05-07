import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

const String appName = 'demo';

class Ticker implements Disposable {
  final tick = Signal<int>(0, name: 'tick');

  @override
  void dispose() {
    tick.dispose();
  }
}
