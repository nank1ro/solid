import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class EffectsController implements Disposable {
  final count = Signal<int>(0, name: 'count');

  late final logCount = Effect(() {
    print('The count is now ${count.value}');
  }, name: 'logCount');

  void increment() => count.value++;

  EffectsController() {
    logCount;
  }

  @override
  void dispose() {
    logCount.dispose();
    count.dispose();
  }
}
