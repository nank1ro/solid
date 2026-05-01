import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter implements Comparable<Counter>, Disposable {
  final value = Signal<int>(0, name: 'value');

  @override
  int compareTo(Counter other) => value.value - other.value.value;

  @override
  void dispose() {
    value.dispose();
  }
}
