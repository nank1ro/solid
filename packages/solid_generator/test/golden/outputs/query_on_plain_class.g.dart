import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  Counter() {
    log;
  }

  final value = Signal<int>(0, name: 'value');

  late final log = Effect(() {
    print('value: ${value.value}');
  }, name: 'log');

  late final fetchSnapshot = Resource<int>(
    () async => 0,
    name: 'fetchSnapshot',
  );

  @override
  void dispose() {
    fetchSnapshot.dispose();
    log.dispose();
    value.dispose();
  }
}
