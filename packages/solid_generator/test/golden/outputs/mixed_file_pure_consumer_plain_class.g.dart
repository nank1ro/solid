import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  final count = Signal<int>(0, name: 'count');

  @override
  void dispose() {
    count.dispose();
  }
}

class Controller {
  Controller(this._counter);

  final Counter _counter;

  int read() => _counter.count.value;

  void increment() => _counter.count.value = _counter.count.value + 1;
}
