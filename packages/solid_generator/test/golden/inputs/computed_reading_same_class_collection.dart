// Same-class collection chain reads inside a `@SolidState` getter body
// must NOT receive `.value` insertion — `ListSignal<T>` / `SetSignal<T>` /
// `MapSignal<K, V>` mix in their respective collection mixins and track
// reads natively. The Computed body's `xs.where(...)` resolves through
// `ListMixin.where` on the signal directly, and the resulting Iterable
// subscribes the Computed via the same mechanism `.value` would.
//
// The Effect body below pins the same rule for `@SolidEffect`: a
// same-class collection chain read inside the body subscribes through
// the mixin without `.value`.

// `print` is the canonical Effect side-effect demonstration.
// ignore_for_file: avoid_print

import 'package:solid_annotations/solid_annotations.dart';

class Inventory {
  @SolidState()
  List<int> items = [];

  @SolidState()
  List<int> get evens => items.where((i) => i.isEven).toList();

  @SolidState()
  int get count => items.length;

  @SolidEffect()
  void log() {
    print('count=${items.length}, first=${items[0]}');
  }
}
