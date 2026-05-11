import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class ComputedValueController implements Disposable {
  final count = Signal<int>(0, name: 'count');

  late final doubleCount = Computed<int>(
    () => count.value * 2,
    name: 'doubleCount',
  );

  void increment() => count.value++;

  @override
  void dispose() {
    doubleCount.dispose();
    count.dispose();
  }
}
