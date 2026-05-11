import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class CounterController implements Disposable {
  final counter = Signal<int>(0, name: 'counter');

  late final doubleCounter = Computed<int>(
    () => counter.value * 2,
    name: 'doubleCounter',
  );

  void increment() => counter.value++;

  void decrement() => counter.value--;

  @override
  void dispose() {
    doubleCounter.dispose();
    counter.dispose();
  }
}
