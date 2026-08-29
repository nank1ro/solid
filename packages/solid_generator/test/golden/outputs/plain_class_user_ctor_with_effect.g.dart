import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  Counter({int init = 0}) {
    value.value = init;

    log = Effect(() {
      print('value: ${value.value}');
    }, name: 'log');
  }

  late final value = Signal<int>.lazy(name: 'value');

  late final Effect log;

  @override
  void dispose() {
    log.dispose();
    value.dispose();
  }
}
