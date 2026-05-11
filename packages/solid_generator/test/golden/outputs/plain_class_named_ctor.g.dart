import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  Counter();

  Counter.seeded(int init) {
    value.value = init;
  }

  late final value = Signal<int>.lazy(name: 'value');

  @override
  void dispose() {
    value.dispose();
  }
}
