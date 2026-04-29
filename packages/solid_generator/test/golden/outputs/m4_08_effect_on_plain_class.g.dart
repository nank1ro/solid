import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter {
  final value = Signal<int>(0, name: 'value');
  late final log = Effect(() {
    print('value: ${value.value}');
  }, name: 'log');

  Counter() {
    log;
  }

  void dispose() {
    log.dispose();
    value.dispose();
  }
}
