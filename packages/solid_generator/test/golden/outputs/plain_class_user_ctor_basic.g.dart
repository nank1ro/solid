import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  Counter({int init = 0}) {
    value.value = init;
  }

  late final value = Signal<int>.lazy(name: 'value');

  @override
  void dispose() {
    value.dispose();
  }
}
