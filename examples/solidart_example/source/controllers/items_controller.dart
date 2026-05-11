import 'package:solid_annotations/solid_annotations.dart';

class ItemsController {
  @SolidState()
  List<int> items = const [1, 2];

  void add(int value) => items.add(value);

  void removeLast() {
    if (items.isNotEmpty) {
      items.removeLast();
    }
  }

  void sort() => items.sort();

  void clear() => items.clear();
}

class SetItemsController {
  @SolidState()
  Set<int> items = const {1, 2};

  void add(int value) => items.add(value);

  void removeLast() {
    if (items.isNotEmpty) {
      items.remove(items.last);
    }
  }

  void clear() => items.clear();
}

class MapItemsController {
  @SolidState()
  Map<String, int> items = const {'a': 1, 'b': 2};

  void add(String key, int value) => items[key] = value;

  void removeLast() {
    if (items.isNotEmpty) {
      items.remove(items.keys.last);
    }
  }

  void clear() => items.clear();
}
