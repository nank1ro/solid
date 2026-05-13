import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class Inventory implements Disposable {
  Inventory() {
    log;
  }

  final items = ListSignal<int>([], name: 'items');

  late final evens = Computed<List<int>>(
    () => items.where((i) => i.isEven).toList(),
    name: 'evens',
  );

  late final count = Computed<int>(() => items.length, name: 'count');

  late final log = Effect(() {
    print('count=${items.length}, first=${items[0]}');
  }, name: 'log');

  @override
  void dispose() {
    log.dispose();
    count.dispose();
    evens.dispose();
    items.dispose();
  }
}
