import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Counter implements Disposable {
  Counter() {
    first = Effect(() {
      print('first: ${count.value}');
    }, name: 'first');
    second = Effect(() {
      print('second: ${count.value}');
    }, name: 'second');
  }

  final count = Signal<int>(0, name: 'count');

  late final Effect first;

  late final Effect second;

  @override
  void dispose() {
    second.dispose();
    first.dispose();
    count.dispose();
  }
}
