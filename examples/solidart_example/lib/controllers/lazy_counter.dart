import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class LazyCounterController implements Disposable {
  late final lazyCounter = Signal<int>.lazy(name: 'lazyCounter');

  void increment() {
    lazyCounter.value = lazyCounter.hasValue ? lazyCounter.value + 1 : 0;
  }

  void decrement() {
    lazyCounter.value = lazyCounter.hasValue ? lazyCounter.value - 1 : 0;
  }

  @override
  void dispose() {
    lazyCounter.dispose();
  }
}
