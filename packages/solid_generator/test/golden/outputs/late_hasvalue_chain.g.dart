import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class LazyCounter implements Disposable {
  late final counter = Signal<int>.lazy(name: 'counter');

  void increment() {
    counter.value = counter.hasValue ? counter.value + 1 : 0;
  }

  @override
  void dispose() {
    counter.dispose();
  }
}
