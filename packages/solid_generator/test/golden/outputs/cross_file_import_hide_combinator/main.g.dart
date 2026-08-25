import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';
import 'right_meter.dart';
import 'wrong_meter.dart' hide Meter;

class Display implements Disposable {
  Display(this.meter);

  final Meter meter;

  final loadCount = Signal<int>(0, name: 'loadCount');

  int describe() {
    loadCount.value = loadCount.value + 1;
    return meter.reading.value;
  }

  @override
  void dispose() {
    loadCount.dispose();
  }
}
