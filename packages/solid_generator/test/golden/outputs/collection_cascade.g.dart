import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class CascadeProbe implements Disposable {
  final xs = ListSignal<int>(const [], name: 'xs');

  final counts = MapSignal<String, int>(const {}, name: 'counts');

  void seed() {
    xs
      ..add(7)
      ..add(8)
      ..sort();
    counts
      ..['x'] = 1
      ..['y'] = 2;
  }

  @override
  void dispose() {
    counts.dispose();
    xs.dispose();
  }
}
