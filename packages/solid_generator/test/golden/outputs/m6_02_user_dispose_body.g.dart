import 'dart:async';
import 'package:solid_annotations/solid_annotations.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

class Counter implements Disposable {
  final value = Signal<int>(0, name: 'value');

  final StreamSubscription<void> _ticker = Stream<void>.periodic(
    const Duration(seconds: 1),
  ).listen((_) {});

  @override
  void dispose() {
    value.dispose();
    unawaited(_ticker.cancel());
    print('counter cleanup');
  }
}
