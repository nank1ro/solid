import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Meter implements Disposable {
  final reading = Signal<int>(0, name: 'reading');

  @override
  void dispose() {
    reading.dispose();
  }
}
