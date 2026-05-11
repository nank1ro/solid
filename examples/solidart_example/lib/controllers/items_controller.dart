import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:solid_annotations/solid_annotations.dart';

class ItemsController implements Disposable {
  final items = ListSignal<int>(const [1, 2], name: 'items');

  void add(int value) => items.add(value);

  void removeLast() {
    if (items.isNotEmpty) {
      items.removeLast();
    }
  }

  void sort() => items.sort();

  void clear() => items.clear();

  @override
  void dispose() {
    items.dispose();
  }
}

class SetItemsController implements Disposable {
  final items = SetSignal<int>(const {1, 2}, name: 'items');

  void add(int value) => items.add(value);

  void removeLast() {
    if (items.isNotEmpty) {
      items.remove(items.last);
    }
  }

  void clear() => items.clear();

  @override
  void dispose() {
    items.dispose();
  }
}

class MapItemsController implements Disposable {
  final items = MapSignal<String, int>(const {'a': 1, 'b': 2}, name: 'items');

  void add(String key, int value) => items[key] = value;

  void removeLast() {
    if (items.isNotEmpty) {
      items.remove(items.keys.last);
    }
  }

  void clear() => items.clear();

  @override
  void dispose() {
    items.dispose();
  }
}
