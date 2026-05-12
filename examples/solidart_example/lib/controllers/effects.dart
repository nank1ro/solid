import 'package:flutter/foundation.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class EffectsController implements Disposable {
  EffectsController() {
    logCount;
  }

  final count = Signal<int>(0, name: 'count');

  late final logCount = Effect(() {
    debugPrint('The count is now ${count.value}');
  }, name: 'logCount');

  void increment() => count.value++;

  @override
  void dispose() {
    logCount.dispose();
    count.dispose();
  }
}
