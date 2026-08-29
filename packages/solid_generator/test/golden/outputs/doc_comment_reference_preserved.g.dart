import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  final count = Signal<int>(0, name: 'count');

  /// Twice the [count]. Reads [count] then doubles it.
  int get doubled => count.value * 2;

  @override
  void dispose() {
    count.dispose();
  }
}
